import Flutter
import MapLibre
import Metal
import MetalKit

/// A MapLibre custom style layer that draws lit 3D meshes (MeshLayer in the Dart API) with Metal.
///
/// Performance: every mesh goes to the GPU once (an interleaved vertex buffer, an index buffer and
/// an instance buffer), and each frame draws it for all of its instances with one instanced draw
/// call. The only per-frame work on the CPU is one matrix, computed in double precision: vertices
/// and instance offsets are metres around the layer's origin (its first instance), so the large
/// world coordinates of high zoom levels never reach the GPU's 32-bit floats. Lighting runs per
/// vertex. The same renderer as Android's src/main/cpp/mesh_layer.cpp.
///
/// Depth: MapLibre Native draws its fill extrusions into [0, depthRangeSize] of the depth buffer, a
/// size it derives from its number of layer groups and does not hand to custom layers, and its 2D
/// layers just behind that. A custom layer can't match the extrusions' depth exactly, and with the
/// full range it ends up behind every 2D layer. So the layer draws its own 3D scene on top: it
/// clears the depth, writes its occluders (the shapes of the map's own 3D content) into it, then
/// draws its meshes against them.
final class MeshStyleLayer: MLNCustomStyleLayer {
    private struct Mesh {
        var vertices: [Float] // position (3), normal (3), sRGB colour (4) per vertex
        var indices: [UInt32]
        var instances: [Float]
        var occluder = false // offset east, north, up (3), cos and sin of the bearing (2), scale (1)
        var vertexBuffer: MTLBuffer?
        var indexBuffer: MTLBuffer?
        var instanceBuffer: MTLBuffer?
        var indexType: MTLIndexType = .uint32
        var indexCount = 0
        var instanceCount: Int { instances.count / 6 }
    }

    /// The uniforms' memory layout in the shader
    private struct Uniforms {
        var matrix: simd_float4x4
        var sky: SIMD4<Float>
        var ground: SIMD4<Float>
        var sunColor: SIMD4<Float>
        var sunDirection: SIMD4<Float>
        var intensities: SIMD4<Float> // hemisphere, sun
    }

    private static let earthCircumference = 2.0 * Double.pi * 6_378_137.0

    private var meshes: [Mesh]
    private let originX: Double
    private let originY: Double
    private let metresPerUnit: Double
    private let light: [Float]
    private let minZoom: Double
    private let maxZoom: Double
    private var pipeline: MTLRenderPipelineState?
    private var occluderPipeline: MTLRenderPipelineState?
    private var clearPipeline: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    private var clearDepthState: MTLDepthStencilState?
    private weak var mapView: MLNMapView?

    /// The layer for the "meshLayer#add" arguments: meshes, instances, light, minzoom, maxzoom
    init?(identifier: String, arguments: [String: Any]) {
        func floats(_ value: Any?) -> [Float]? {
            guard let data = value as? FlutterStandardTypedData, data.type == .float32 else { return nil }
            return data.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        }
        guard let meshArguments = arguments["meshes"] as? [[String: Any]],
              let instanceData = arguments["instances"] as? FlutterStandardTypedData, instanceData.type == .float64
        else { return nil }
        let placements: [Double] = instanceData.data.withUnsafeBytes { Array($0.bindMemory(to: Double.self)) }

        var meshes: [Mesh] = []
        for mesh in meshArguments {
            guard let positions = floats(mesh["positions"]), let normals = floats(mesh["normals"]),
                  let colors = floats(mesh["colors"]),
                  let indexData = mesh["indices"] as? FlutterStandardTypedData, indexData.type == .int32
            else { return nil }
            let vertexCount = positions.count / 3
            guard normals.count == vertexCount * 3, colors.count == vertexCount * 4 else { return nil }
            var vertices = [Float](repeating: 0, count: vertexCount * 10)
            for v in 0 ..< vertexCount {
                for i in 0 ..< 3 {
                    vertices[v * 10 + i] = positions[v * 3 + i]
                    vertices[v * 10 + 3 + i] = normals[v * 3 + i]
                }
                for i in 0 ..< 4 {
                    vertices[v * 10 + 6 + i] = colors[v * 4 + i]
                }
            }
            let rawIndices: [Int32] = indexData.data.withUnsafeBytes { Array($0.bindMemory(to: Int32.self)) }
            guard rawIndices.allSatisfy({ $0 >= 0 && Int($0) < vertexCount }) else { return nil }
            meshes.append(Mesh(
                vertices: vertices, indices: rawIndices.map { UInt32($0) }, instances: [],
                occluder: mesh["occluder"] as? Bool ?? false
            ))
        }

        // The origin is the first instance: every offset stays a few hundred metres at most
        let originLatitude = placements.count >= 6 ? placements[1] : 0
        originX = placements.count >= 6 ? Self.mercatorX(placements[2]) : 0
        originY = placements.count >= 6 ? Self.mercatorY(placements[1]) : 0
        metresPerUnit = Self.earthCircumference * cos(originLatitude * .pi / 180)
        var i = 0
        while i + 6 <= placements.count {
            let m = Int(placements[i])
            if m >= 0, m < meshes.count {
                let latitude = placements[i + 1]
                let bearing = placements[i + 4] * .pi / 180
                // A metre is shorter in mercator units further north: as the web layer, keep the
                // model's real size where it stands
                let scale = placements[i + 5] * cos(originLatitude * .pi / 180) / cos(latitude * .pi / 180)
                meshes[m].instances += [
                    Float((Self.mercatorX(placements[i + 2]) - originX) * metresPerUnit),
                    Float(-(Self.mercatorY(latitude) - originY) * metresPerUnit),
                    Float(placements[i + 3]),
                    Float(cos(bearing)),
                    Float(sin(bearing)),
                    Float(scale),
                ]
            }
            i += 6
        }
        self.meshes = meshes
        let defaultLight: [Float] = [1, 1, 1, 0.13, 0.17, 0.11, 2, 1, 1, 1, 2, -0.37, -0.56, 0.74]
        let given = floats(arguments["light"]) ?? []
        light = given.count >= 14 ? Array(given.prefix(14)) : defaultLight
        minZoom = arguments["minzoom"] as? Double ?? 0
        maxZoom = arguments["maxzoom"] as? Double ?? 24
        super.init(identifier: identifier)
    }

    override func didMove(to mapView: MLNMapView) {
        let resource = mapView.backendResource()
        let device: MTLDevice? = resource.device
        guard let device else { return }
        do {
            let library = try device.makeLibrary(source: Self.shaderSource, options: nil)
            let vertexDescriptor = MTLVertexDescriptor()
            let floatSize = MemoryLayout<Float>.stride
            for (index, format, offset) in [
                (0, MTLVertexFormat.float3, 0), (1, .float3, 3), (2, .float4, 6),
            ] {
                vertexDescriptor.attributes[index].format = format
                vertexDescriptor.attributes[index].offset = offset * floatSize
                vertexDescriptor.attributes[index].bufferIndex = 0
            }
            for (index, format, offset) in [
                (3, MTLVertexFormat.float3, 0), (4, .float2, 3), (5, .float, 5),
            ] {
                vertexDescriptor.attributes[index].format = format
                vertexDescriptor.attributes[index].offset = offset * floatSize
                vertexDescriptor.attributes[index].bufferIndex = 1
            }
            vertexDescriptor.layouts[0].stride = 10 * floatSize
            vertexDescriptor.layouts[1].stride = 6 * floatSize
            vertexDescriptor.layouts[1].stepFunction = .perInstance

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "MeshStyleLayer"
            descriptor.vertexFunction = library.makeFunction(name: "meshVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "meshFragment")
            descriptor.vertexDescriptor = vertexDescriptor
            descriptor.rasterSampleCount = resource.mtkView.sampleCount
            let color = descriptor.colorAttachments[0]!
            color.pixelFormat = resource.mtkView.colorPixelFormat
            color.isBlendingEnabled = true
            color.sourceRGBBlendFactor = .one
            color.sourceAlphaBlendFactor = .one
            color.destinationRGBBlendFactor = .oneMinusSourceAlpha
            color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            // The map's render pass: MapLibre Native's Metal backend renders into depth32Float_stencil8
            descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
            descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)

            // The occluders: the same vertices, only their depth
            descriptor.label = "MeshStyleLayer occluders"
            color.writeMask = []
            occluderPipeline = try device.makeRenderPipelineState(descriptor: descriptor)

            // Clears the depth: a triangle over the whole screen at the far plane
            let clear = MTLRenderPipelineDescriptor()
            clear.label = "MeshStyleLayer depth clear"
            clear.vertexFunction = library.makeFunction(name: "clearVertex")
            clear.rasterSampleCount = resource.mtkView.sampleCount
            clear.colorAttachments[0].pixelFormat = resource.mtkView.colorPixelFormat
            clear.colorAttachments[0].writeMask = []
            clear.depthAttachmentPixelFormat = .depth32Float_stencil8
            clear.stencilAttachmentPixelFormat = .depth32Float_stencil8
            clearPipeline = try device.makeRenderPipelineState(descriptor: clear)
        } catch {
            NSLog("MeshStyleLayer: \(error)")
            return
        }

        // The layer's own 3D scene (see the top of the file)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depth)
        let clearDepth = MTLDepthStencilDescriptor()
        clearDepth.depthCompareFunction = .always
        clearDepth.isDepthWriteEnabled = true
        clearDepthState = device.makeDepthStencilState(descriptor: clearDepth)
        self.mapView = mapView

        for m in meshes.indices where !meshes[m].vertices.isEmpty && !meshes[m].instances.isEmpty {
            meshes[m].vertexBuffer = device.makeBuffer(
                bytes: meshes[m].vertices, length: meshes[m].vertices.count * MemoryLayout<Float>.stride
            )
            meshes[m].instanceBuffer = device.makeBuffer(
                bytes: meshes[m].instances, length: meshes[m].instances.count * MemoryLayout<Float>.stride
            )
            // 16-bit indices where they fit: half the index memory and bandwidth
            if meshes[m].vertices.count / 10 <= Int(UInt16.max) {
                let short = meshes[m].indices.map { UInt16($0) }
                meshes[m].indexBuffer = device.makeBuffer(bytes: short, length: short.count * 2)
                meshes[m].indexType = .uint16
            } else {
                meshes[m].indexBuffer = device.makeBuffer(
                    bytes: meshes[m].indices, length: meshes[m].indices.count * 4
                )
                meshes[m].indexType = .uint32
            }
            meshes[m].indexCount = meshes[m].indices.count
        }
    }

    override func willMove(from _: MLNMapView) {
        pipeline = nil
        occluderPipeline = nil
        clearPipeline = nil
        depthState = nil
        clearDepthState = nil
        for m in meshes.indices {
            meshes[m].vertexBuffer = nil
            meshes[m].indexBuffer = nil
            meshes[m].instanceBuffer = nil
        }
    }

    override func draw(in _: MLNMapView, with context: MLNStyleLayerDrawingContext) {
        guard let encoder = renderEncoder, let pipeline, let occluderPipeline, let clearPipeline, let depthState,
              let clearDepthState, let mapView,
              context.zoomLevel >= minZoom, context.zoomLevel < maxZoom
        else { return }

        // Metres around the origin to clip space: P · translate(origin in world pixels) · scale(world
        // pixels per metre, north is -y). The projection keeps heights in metres already.
        let worldSize = 512.0 * pow(2.0, context.zoomLevel)
        let k = worldSize / metresPerUnit
        let ox = originX * worldSize
        let oy = originY * worldSize
        let p = context.projectionMatrix
        let c0 = SIMD4<Double>(p.m00, p.m01, p.m02, p.m03)
        let c1 = SIMD4<Double>(p.m10, p.m11, p.m12, p.m13)
        let c2 = SIMD4<Double>(p.m20, p.m21, p.m22, p.m23)
        let c3 = SIMD4<Double>(p.m30, p.m31, p.m32, p.m33)
        var uniforms = Uniforms(
            matrix: simd_float4x4(
                SIMD4<Float>(c0 * k), SIMD4<Float>(c1 * -k), SIMD4<Float>(c2), SIMD4<Float>(c0 * ox + c1 * oy + c3)
            ),
            sky: SIMD4(light[0], light[1], light[2], 0),
            ground: SIMD4(light[3], light[4], light[5], 0),
            sunColor: SIMD4(light[7], light[8], light[9], 0),
            sunDirection: SIMD4(light[11], light[12], light[13], 0),
            intensities: SIMD4(light[6], light[10], 0, 0)
        )

        // The full depth range: MapLibre leaves this layer's 2D slot, a single depth, on the encoder
        let size = mapView.backendResource().mtkView.drawableSize
        encoder.setViewport(MTLViewport(
            originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1
        ))
        encoder.setCullMode(.none)

        // The layer's own 3D scene: a clear depth, the occluders written into it unseen, then the
        // meshes against them
        encoder.setRenderPipelineState(clearPipeline)
        encoder.setDepthStencilState(clearDepthState)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        encoder.setDepthStencilState(depthState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        for (occluders, state) in [(true, occluderPipeline), (false, pipeline)] {
            encoder.setRenderPipelineState(state)
            for mesh in meshes where mesh.occluder == occluders {
                guard let vertices = mesh.vertexBuffer, let indices = mesh.indexBuffer,
                      let instances = mesh.instanceBuffer, mesh.instanceCount > 0
                else { continue }
                encoder.setVertexBuffer(vertices, offset: 0, index: 0)
                encoder.setVertexBuffer(instances, offset: 0, index: 1)
                encoder.drawIndexedPrimitives(
                    type: .triangle, indexCount: mesh.indexCount, indexType: mesh.indexType,
                    indexBuffer: indices, indexBufferOffset: 0, instanceCount: mesh.instanceCount
                )
            }
        }
    }

    private static func mercatorX(_ longitude: Double) -> Double { (180 + longitude) / 360 }

    private static func mercatorY(_ latitude: Double) -> Double {
        (180 - (180 / .pi) * log(tan(.pi / 4 + latitude * .pi / 360))) / 360
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float3 position [[attribute(0)]];
        float3 normal [[attribute(1)]];
        float4 color [[attribute(2)]];
        float3 offset [[attribute(3)]];
        float2 rotation [[attribute(4)]];
        float scale [[attribute(5)]];
    };

    struct Uniforms {
        float4x4 matrix;
        float4 sky;
        float4 ground;
        float4 sunColor;
        float4 sunDirection;
        float4 intensities;
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    static float3 toLinear(float3 c) {
        return select(pow((c + 0.055) / 1.055, float3(2.4)), c / 12.92, c <= 0.04045);
    }

    static float3 toSrgb(float3 c) {
        c = clamp(c, 0.0, 1.0);
        return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c * 12.92, c <= 0.0031308);
    }

    // Clockwise by the bearing: east turns towards south
    static float2 turn(float2 v, float2 r) {
        return float2(v.x * r.x + v.y * r.y, -v.x * r.y + v.y * r.x);
    }

    vertex VertexOut meshVertex(VertexIn in [[stage_in]], constant Uniforms &u [[buffer(2)]]) {
        float3 p = in.position * in.scale;
        float3 world = float3(turn(p.xy, in.rotation), p.z) + in.offset;
        VertexOut out;
        out.position = u.matrix * float4(world, 1.0);

        // three.js's rough MeshStandardMaterial: a hemisphere light plus a directional sun,
        // Lambert's diffuse term (albedo / pi), all in linear colour
        float3 n = normalize(float3(turn(in.normal.xy, in.rotation), in.normal.z));
        float3 irradiance = mix(u.ground.rgb, u.sky.rgb, 0.5 * n.z + 0.5) * u.intensities.x
            + u.sunColor.rgb * u.intensities.y * max(dot(n, u.sunDirection.xyz), 0.0);
        out.color = float4(toSrgb(toLinear(in.color.rgb) * irradiance / M_PI_F), in.color.a);
        return out;
    }

    // A triangle covering the screen at the far plane, to clear the depth
    vertex float4 clearVertex(uint id [[vertex_id]]) {
        float2 p = float2(float((id << 1) & 2), float(id & 2));
        return float4(p * 2.0 - 1.0, 1.0, 1.0);
    }

    fragment float4 meshFragment(VertexOut in [[stage_in]]) {
        return float4(in.color.rgb * in.color.a, in.color.a);
    }
    """
}
