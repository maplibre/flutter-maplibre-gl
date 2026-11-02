part of '../maplibre_gl_platform_interface.dart';

/// A triangle mesh for a [MeshLayer], in metres around its anchor: x points east, y north, z up.
///
/// Every vertex has a position, a unit normal and an sRGB colour; [indices] lists three vertices per
/// triangle. Faces are drawn from both sides, so the winding does not matter.
class MeshLayerMesh {
  MeshLayerMesh({
    required this.positions,
    required this.normals,
    required this.colors,
    required this.indices,
  }) : assert(positions.length % 3 == 0, 'positions: three per vertex'),
       assert(normals.length == positions.length, 'normals: three per vertex'),
       assert(
         colors.length == positions.length ~/ 3 * 4,
         'colors: four per vertex (RGBA)',
       ),
       assert(indices.length % 3 == 0, 'indices: three per triangle');

  /// x, y, z of each vertex, in metres
  final Float32List positions;

  /// The unit normal of each vertex (x, y, z), used for the lighting
  final Float32List normals;

  /// The sRGB colour of each vertex (r, g, b, a in 0…1)
  final Float32List colors;

  /// Three vertex indices per triangle
  final Int32List indices;

  int get vertexCount => positions.length ~/ 3;

  Map<String, Object> toMap() => {
    'positions': positions,
    'normals': normals,
    'colors': colors,
    'indices': indices,
  };
}

/// One placement of a [MeshLayerMesh] on the map.
@immutable
class MeshLayerInstance {
  const MeshLayerInstance({
    required this.mesh,
    required this.position,
    this.altitude = 0,
    this.bearing = 0,
    this.scale = 1,
  });

  /// The index of the mesh in [MeshLayer.meshes]
  final int mesh;

  /// Where the mesh's origin stands
  final LatLng position;

  /// Metres above the ground
  final double altitude;

  /// Degrees clockwise from north that the mesh is turned by
  final double bearing;

  /// Factor on the mesh's size
  final double scale;
}

/// The light of a [MeshLayer], as three.js lights a rough `MeshStandardMaterial`: a hemisphere light
/// between [skyColor] and [groundColor] and a directional [sunColor] light falling from
/// [sunDirection] (towards the light, x east, y north, z up). The defaults are those of MapLibre GL
/// JS's 3D model examples: white sky, a green grey ground, a sun from the upper south west.
@immutable
class MeshLayerLight {
  const MeshLayerLight({
    this.skyColor = const Color(0xFFFFFFFF),
    this.groundColor = const Color(0xFF65715B),
    this.hemisphereIntensity = 2,
    this.sunColor = const Color(0xFFFFFFFF),
    this.sunIntensity = 2,
    this.sunDirection = const (x: -20, y: -30, z: 40),
  });

  final Color skyColor;
  final Color groundColor;
  final double hemisphereIntensity;
  final Color sunColor;
  final double sunIntensity;

  /// Towards the sun; normalised by the renderer
  final ({double x, double y, double z}) sunDirection;

  /// 14 floats: sky rgb, ground rgb, hemisphere intensity, sun rgb, sun intensity, sun direction
  /// xyz (normalised). Colours are linear, as the shaders light in linear colour.
  Float32List toList() {
    double linear(double srgb) =>
        srgb <= 0.04045
            ? srgb / 12.92
            : pow((srgb + 0.055) / 1.055, 2.4).toDouble();
    final (:x, :y, :z) = sunDirection;
    final length = sqrt(x * x + y * y + z * z);
    final d =
        length == 0 ? (0.0, 0.0, 1.0) : (x / length, y / length, z / length);

    return Float32List.fromList([
      linear(skyColor.r),
      linear(skyColor.g),
      linear(skyColor.b),
      linear(groundColor.r),
      linear(groundColor.g),
      linear(groundColor.b),
      hemisphereIntensity,
      linear(sunColor.r),
      linear(sunColor.g),
      linear(sunColor.b),
      sunIntensity,
      d.$1,
      d.$2,
      d.$3,
    ]);
  }
}

/// Lit 3D meshes drawn natively in the map's 3D scene, depth-tested against fill extrusions: trees,
/// furniture or any other model at real coordinates, which fill extrusions cannot shape.
///
/// Each mesh is uploaded to the GPU once and drawn for all its [instances] in one instanced draw
/// call; per frame the renderer only computes one matrix. Positions are kept in metres around the
/// first instance, so they stay precise at any zoom.
class MeshLayer {
  MeshLayer({
    required this.meshes,
    required this.instances,
    this.light = const MeshLayerLight(),
    this.minzoom = 0,
    this.maxzoom = 24,
  }) : assert(
         instances.every((e) => e.mesh >= 0 && e.mesh < meshes.length),
         'every instance needs one of the meshes',
       );

  final List<MeshLayerMesh> meshes;
  final List<MeshLayerInstance> instances;
  final MeshLayerLight light;
  final double minzoom;
  final double maxzoom;

  Map<String, Object> toMap() => {
    'meshes': [for (final mesh in meshes) mesh.toMap()],
    // mesh index, latitude, longitude, altitude, bearing, scale per instance
    'instances': Float64List.fromList([
      for (final e in instances) ...[
        e.mesh.toDouble(),
        e.position.latitude,
        e.position.longitude,
        e.altitude,
        e.bearing,
        e.scale,
      ],
    ]),
    'light': light.toList(),
    'minzoom': minzoom,
    'maxzoom': maxzoom,
  };
}
