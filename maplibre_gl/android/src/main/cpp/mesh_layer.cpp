// A MapLibre Native custom layer that draws lit 3D meshes (MeshLayer in the Dart API) with
// OpenGL ES 3.
//
// Performance: every mesh goes to the GPU once (one interleaved vertex buffer, one index buffer and
// one instance buffer, bound in a vertex array object), and each frame draws it for all of its
// instances with one glDrawElementsInstanced. The only per-frame work on the CPU is one matrix,
// computed in double precision: vertices and instance offsets are meters around the layer's
// origin (its first instance), so the large world coordinates of high zoom levels never reach
// the GPU's 32-bit floats. Lighting runs per vertex.
//
// Depth: MapLibre Native draws its fill extrusions into [0, depthRangeSize] of the depth buffer, a
// size it derives from its number of layer groups and does not hand to custom layers, and its 2D
// layers just behind that. A custom layer can't match the extrusions' depth exactly, and with the
// full range it ends up behind every 2D layer. So the layer draws its own 3D scene on top: it
// clears the depth, writes its occluders (the shapes of the map's own 3D content) into it, then
// draws its meshes against them.
//
// Backend: the renderer needs OpenGL ES. Under MapLibre's Vulkan backend (maplibre_gl.renderer set
// to vulkan, or auto on a device with Vulkan) there is no GL context, and the layer draws nothing.

#include "custom_layer_host.hpp"

#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include <android/log.h>
#include <jni.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <vector>

namespace {

constexpr const char* kTag = "MapLibreMeshLayer";
constexpr double kEarthCircumference = 2.0 * M_PI * 6378137.0;

// Per vertex: position (3), normal (3), sRGB color (4)
constexpr int kVertexFloats = 10;
// Per instance: offset east, north, up in meters (3), cos and sin of the bearing (2), scale (1)
constexpr int kInstanceFloats = 6;

const char* kVertexShader = R"(#version 300 es
precision highp float;
uniform mat4 u_matrix;
uniform vec3 u_sky;
uniform vec3 u_ground;
uniform float u_hemisphere;
uniform vec3 u_sun_color;
uniform float u_sun;
uniform vec3 u_sun_direction;
layout(location = 0) in vec3 a_position;
layout(location = 1) in vec3 a_normal;
layout(location = 2) in vec4 a_color;
layout(location = 3) in vec3 a_offset;
layout(location = 4) in vec2 a_rotation;
layout(location = 5) in float a_scale;
out vec4 v_color;

vec3 toLinear(vec3 c) {
  return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 toSrgb(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec2 turn(vec2 v) {
  // Clockwise by the bearing: east turns towards south
  return vec2(v.x * a_rotation.x + v.y * a_rotation.y, -v.x * a_rotation.y + v.y * a_rotation.x);
}

void main() {
  vec3 p = a_position * a_scale;
  vec3 world = vec3(turn(p.xy), p.z) + a_offset;
  gl_Position = u_matrix * vec4(world, 1.0);

  // three.js's rough MeshStandardMaterial: a hemisphere light plus a directional sun, Lambert's
  // diffuse term (albedo / pi), all in linear color
  vec3 n = normalize(vec3(turn(a_normal.xy), a_normal.z));
  vec3 irradiance = mix(u_ground, u_sky, 0.5 * n.z + 0.5) * u_hemisphere
      + u_sun_color * u_sun * max(dot(n, u_sun_direction), 0.0);
  v_color = vec4(toSrgb(toLinear(a_color.rgb) * irradiance / 3.14159265), a_color.a);
}
)";

const char* kFragmentShader = R"(#version 300 es
precision mediump float;
in vec4 v_color;
out vec4 fragColor;
void main() {
  fragColor = vec4(v_color.rgb * v_color.a, v_color.a);
}
)";

struct Mesh {
    std::vector<float> vertices;
    std::vector<uint32_t> indices;
    std::vector<float> instances;
    bool occluder = false;
    GLuint vertexArray = 0;
    GLuint buffers[3] = {0, 0, 0};
    GLenum indexType = GL_UNSIGNED_INT;
};

double mercatorX(double longitude) { return (180.0 + longitude) / 360.0; }

double mercatorY(double latitude) {
    return (180.0 - (180.0 / M_PI) * std::log(std::tan(M_PI / 4.0 + latitude * M_PI / 360.0))) / 360.0;
}

GLuint compile(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);
    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        __android_log_print(ANDROID_LOG_ERROR, kTag, "Shader: %s", log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

class MeshLayerHost final : public mln::style::CustomLayerHost {
public:
    MeshLayerHost(std::vector<Mesh> meshes,
                  double originX,
                  double originY,
                  double originLatitude,
                  const float* light,
                  double minZoom,
                  double maxZoom)
        : meshes_(std::move(meshes)),
          originX_(originX),
          originY_(originY),
          metersPerUnit_(kEarthCircumference * std::cos(originLatitude * M_PI / 180.0)),
          minZoom_(minZoom),
          maxZoom_(maxZoom) {
        std::copy(light, light + 14, light_);
    }

    void initialize(const mln::style::CustomLayerInitParameters&) override {
        if (eglGetCurrentContext() == EGL_NO_CONTEXT) {
            __android_log_print(ANDROID_LOG_WARN, kTag,
                                "No OpenGL ES context: mesh layers need MapLibre's OpenGL ES backend");
            return;
        }
        GLuint vertex = compile(GL_VERTEX_SHADER, kVertexShader);
        GLuint fragment = compile(GL_FRAGMENT_SHADER, kFragmentShader);
        if (!vertex || !fragment) {
            return;
        }
        program_ = glCreateProgram();
        glAttachShader(program_, vertex);
        glAttachShader(program_, fragment);
        glLinkProgram(program_);
        glDeleteShader(vertex);
        glDeleteShader(fragment);
        GLint ok = 0;
        glGetProgramiv(program_, GL_LINK_STATUS, &ok);
        if (!ok) {
            __android_log_print(ANDROID_LOG_ERROR, kTag, "Program did not link");
            glDeleteProgram(program_);
            program_ = 0;
            return;
        }
        uMatrix_ = glGetUniformLocation(program_, "u_matrix");
        uSky_ = glGetUniformLocation(program_, "u_sky");
        uGround_ = glGetUniformLocation(program_, "u_ground");
        uHemisphere_ = glGetUniformLocation(program_, "u_hemisphere");
        uSunColor_ = glGetUniformLocation(program_, "u_sun_color");
        uSun_ = glGetUniformLocation(program_, "u_sun");
        uSunDirection_ = glGetUniformLocation(program_, "u_sun_direction");

        for (Mesh& mesh : meshes_) {
            upload(mesh);
        }
    }

    void render(const mln::style::CustomLayerRenderParameters& parameters) override {
        if (!program_ || parameters.zoom < minZoom_ || parameters.zoom >= maxZoom_) {
            return;
        }

        // Meters around the origin to clip space: P · translate(origin in world pixels) · scale(world
        // pixels per meter, north is -y). The projection keeps heights in meters already.
        const double worldSize = 512.0 * std::pow(2.0, parameters.zoom);
        const double k = worldSize / metersPerUnit_;
        const double ox = originX_ * worldSize;
        const double oy = originY_ * worldSize;
        const auto& p = parameters.projectionMatrix;
        float matrix[16];
        for (int row = 0; row < 4; row++) {
            matrix[0 + row] = static_cast<float>(p[0 + row] * k);
            matrix[4 + row] = static_cast<float>(-p[4 + row] * k);
            matrix[8 + row] = static_cast<float>(p[8 + row]);
            matrix[12 + row] = static_cast<float>(p[0 + row] * ox + p[4 + row] * oy + p[12 + row]);
        }

        glUseProgram(program_);
        glUniformMatrix4fv(uMatrix_, 1, GL_FALSE, matrix);
        glUniform3fv(uSky_, 1, light_);
        glUniform3fv(uGround_, 1, light_ + 3);
        glUniform1f(uHemisphere_, light_[6]);
        glUniform3fv(uSunColor_, 1, light_ + 7);
        glUniform1f(uSun_, light_[10]);
        glUniform3fv(uSunDirection_, 1, light_ + 11);

        // The layer's own 3D scene (see the top of the file): a clear depth in the full range, the
        // occluders written into it unseen, then the meshes against them, both sides of every face
        glDisable(GL_SCISSOR_TEST);
        glDepthMask(GL_TRUE);
        glDepthRangef(0.0f, 1.0f);
        glClearDepthf(1.0f);
        glClear(GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);
        glDisable(GL_STENCIL_TEST);
        glDisable(GL_CULL_FACE);
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

        for (const bool occluders : {true, false}) {
            glColorMask(!occluders, !occluders, !occluders, !occluders);
            for (const Mesh& mesh : meshes_) {
                const auto count = static_cast<GLsizei>(mesh.instances.size() / kInstanceFloats);
                if (mesh.occluder != occluders || !mesh.vertexArray || count == 0) {
                    continue;
                }
                glBindVertexArray(mesh.vertexArray);
                glDrawElementsInstanced(GL_TRIANGLES, static_cast<GLsizei>(mesh.indices.size()), mesh.indexType,
                                        nullptr, count);
            }
        }
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glBindVertexArray(0);
    }

    void contextLost() override {
        // The context took its objects with it: forget them, initialize() makes new ones
        program_ = 0;
        for (Mesh& mesh : meshes_) {
            mesh.vertexArray = 0;
            mesh.buffers[0] = mesh.buffers[1] = mesh.buffers[2] = 0;
        }
    }

    void deinitialize() override {
        for (Mesh& mesh : meshes_) {
            if (mesh.vertexArray) {
                glDeleteVertexArrays(1, &mesh.vertexArray);
                glDeleteBuffers(3, mesh.buffers);
            }
        }
        contextLost();
        if (program_) {
            glDeleteProgram(program_);
            program_ = 0;
        }
    }

private:
    static void upload(Mesh& mesh) {
        if (mesh.vertices.empty() || mesh.indices.empty() || mesh.instances.empty()) {
            return;
        }
        glGenVertexArrays(1, &mesh.vertexArray);
        glBindVertexArray(mesh.vertexArray);
        glGenBuffers(3, mesh.buffers);

        glBindBuffer(GL_ARRAY_BUFFER, mesh.buffers[0]);
        glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(mesh.vertices.size() * sizeof(float)),
                     mesh.vertices.data(), GL_STATIC_DRAW);
        const GLsizei vertexStride = kVertexFloats * sizeof(float);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vertexStride, reinterpret_cast<void*>(0));
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, vertexStride, reinterpret_cast<void*>(3 * sizeof(float)));
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, vertexStride, reinterpret_cast<void*>(6 * sizeof(float)));

        glBindBuffer(GL_ARRAY_BUFFER, mesh.buffers[2]);
        glBufferData(GL_ARRAY_BUFFER, static_cast<GLsizeiptr>(mesh.instances.size() * sizeof(float)),
                     mesh.instances.data(), GL_STATIC_DRAW);
        const GLsizei instanceStride = kInstanceFloats * sizeof(float);
        glEnableVertexAttribArray(3);
        glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, instanceStride, reinterpret_cast<void*>(0));
        glVertexAttribDivisor(3, 1);
        glEnableVertexAttribArray(4);
        glVertexAttribPointer(4, 2, GL_FLOAT, GL_FALSE, instanceStride, reinterpret_cast<void*>(3 * sizeof(float)));
        glVertexAttribDivisor(4, 1);
        glEnableVertexAttribArray(5);
        glVertexAttribPointer(5, 1, GL_FLOAT, GL_FALSE, instanceStride, reinterpret_cast<void*>(5 * sizeof(float)));
        glVertexAttribDivisor(5, 1);

        // 16-bit indices where they fit: half the index memory and bandwidth
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.buffers[1]);
        if (mesh.vertices.size() / kVertexFloats <= 0xFFFF) {
            std::vector<uint16_t> shortIndices(mesh.indices.begin(), mesh.indices.end());
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(shortIndices.size() * sizeof(uint16_t)),
                         shortIndices.data(), GL_STATIC_DRAW);
            mesh.indexType = GL_UNSIGNED_SHORT;
        } else {
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(mesh.indices.size() * sizeof(uint32_t)),
                         mesh.indices.data(), GL_STATIC_DRAW);
            mesh.indexType = GL_UNSIGNED_INT;
        }
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

    std::vector<Mesh> meshes_;
    double originX_;
    double originY_;
    double metersPerUnit_;
    double minZoom_;
    double maxZoom_;
    float light_[14];
    GLuint program_ = 0;
    GLint uMatrix_ = -1, uSky_ = -1, uGround_ = -1, uHemisphere_ = -1, uSunColor_ = -1, uSun_ = -1,
          uSunDirection_ = -1;
};

std::vector<float> floats(JNIEnv* env, jfloatArray array) {
    std::vector<float> values(array ? env->GetArrayLength(array) : 0);
    if (!values.empty()) {
        env->GetFloatArrayRegion(array, 0, static_cast<jsize>(values.size()), values.data());
    }
    return values;
}

} // namespace

// MeshLayerHost.nativeCreate: the host for a CustomLayer, which owns and deletes it. positions,
// normals and colors hold one float array per mesh, indices one int array, occluders one flag;
// instances is six doubles per instance (mesh, latitude, longitude, altitude, bearing, scale).
extern "C" JNIEXPORT jlong JNICALL Java_org_maplibre_maplibregl_MeshLayerHost_nativeCreate(JNIEnv* env,
                                                                                          jclass,
                                                                                          jobjectArray positions,
                                                                                          jobjectArray normals,
                                                                                          jobjectArray colors,
                                                                                          jobjectArray indices,
                                                                                          jbooleanArray occluders,
                                                                                          jdoubleArray instances,
                                                                                          jfloatArray light,
                                                                                          jdouble minZoom,
                                                                                          jdouble maxZoom) {
    const jsize meshCount = env->GetArrayLength(positions);
    std::vector<Mesh> meshes(static_cast<size_t>(meshCount));
    std::vector<jboolean> occluderFlags(static_cast<size_t>(meshCount), JNI_FALSE);
    if (occluders && env->GetArrayLength(occluders) == meshCount) {
        env->GetBooleanArrayRegion(occluders, 0, meshCount, occluderFlags.data());
    }
    for (jsize m = 0; m < meshCount; m++) {
        auto meshPositions = floats(env, static_cast<jfloatArray>(env->GetObjectArrayElement(positions, m)));
        auto meshNormals = floats(env, static_cast<jfloatArray>(env->GetObjectArrayElement(normals, m)));
        auto meshColors = floats(env, static_cast<jfloatArray>(env->GetObjectArrayElement(colors, m)));
        const size_t vertexCount = meshPositions.size() / 3;
        if (meshNormals.size() != vertexCount * 3 || meshColors.size() != vertexCount * 4) {
            __android_log_print(ANDROID_LOG_ERROR, kTag, "Mesh %d: normals or colors do not match", m);
            continue;
        }
        Mesh& mesh = meshes[static_cast<size_t>(m)];
        mesh.occluder = occluderFlags[static_cast<size_t>(m)] == JNI_TRUE;
        mesh.vertices.resize(vertexCount * kVertexFloats);
        for (size_t v = 0; v < vertexCount; v++) {
            float* out = &mesh.vertices[v * kVertexFloats];
            std::copy_n(&meshPositions[v * 3], 3, out);
            std::copy_n(&meshNormals[v * 3], 3, out + 3);
            std::copy_n(&meshColors[v * 4], 4, out + 6);
        }
        auto indexArray = static_cast<jintArray>(env->GetObjectArrayElement(indices, m));
        const jsize indexCount = env->GetArrayLength(indexArray);
        std::vector<jint> raw(static_cast<size_t>(indexCount));
        env->GetIntArrayRegion(indexArray, 0, indexCount, raw.data());
        mesh.indices.reserve(raw.size());
        for (jint index : raw) {
            if (index < 0 || static_cast<size_t>(index) >= vertexCount) {
                __android_log_print(ANDROID_LOG_ERROR, kTag, "Mesh %d: index %d out of range", m, index);
                mesh.indices.clear();
                break;
            }
            mesh.indices.push_back(static_cast<uint32_t>(index));
        }
    }

    const jsize instanceValues = env->GetArrayLength(instances);
    std::vector<double> placements(static_cast<size_t>(instanceValues));
    env->GetDoubleArrayRegion(instances, 0, instanceValues, placements.data());
    // The origin is the first instance: every offset stays a few hundred meters at most
    double originX = 0, originY = 0, originLatitude = 0;
    if (placements.size() >= 6) {
        originLatitude = placements[1];
        originX = mercatorX(placements[2]);
        originY = mercatorY(placements[1]);
    }
    const double metersPerUnit = kEarthCircumference * std::cos(originLatitude * M_PI / 180.0);
    for (size_t i = 0; i + 6 <= placements.size(); i += 6) {
        const auto m = static_cast<size_t>(placements[i]);
        if (m >= meshes.size()) {
            continue;
        }
        const double latitude = placements[i + 1];
        const double bearing = placements[i + 4] * M_PI / 180.0;
        // A meter is shorter in mercator units further north: as the web layer, keep the model's
        // real size where it stands
        const double scale = placements[i + 5] * std::cos(originLatitude * M_PI / 180.0) /
                             std::cos(latitude * M_PI / 180.0);
        auto& out = meshes[m].instances;
        out.push_back(static_cast<float>((mercatorX(placements[i + 2]) - originX) * metersPerUnit));
        out.push_back(static_cast<float>(-(mercatorY(latitude) - originY) * metersPerUnit));
        out.push_back(static_cast<float>(placements[i + 3]));
        out.push_back(static_cast<float>(std::cos(bearing)));
        out.push_back(static_cast<float>(std::sin(bearing)));
        out.push_back(static_cast<float>(scale));
    }

    float lightValues[14] = {1, 1, 1, 0.13f, 0.17f, 0.11f, 2, 1, 1, 1, 2, -0.37f, -0.56f, 0.74f};
    if (light && env->GetArrayLength(light) >= 14) {
        env->GetFloatArrayRegion(light, 0, 14, lightValues);
    }

    auto* host = new MeshLayerHost(std::move(meshes), originX, originY, originLatitude, lightValues, minZoom, maxZoom);
    return reinterpret_cast<jlong>(static_cast<mln::style::CustomLayerHost*>(host));
}
