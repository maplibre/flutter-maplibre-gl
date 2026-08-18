part of '../maplibre_gl_platform_interface.dart';

/// Properties of the style's `sky` root object.
class SkyProperties {
  /// `sky-color`: the base color for the sky.
  ///
  /// Type: color
  ///   default: #88C6FC
  final dynamic skyColor;

  /// `horizon-color`: the base color at the horizon.
  ///
  /// Type: color
  ///   default: #ffffff
  final dynamic horizonColor;

  /// `fog-color`: the base color for the fog. Requires 3D terrain.
  ///
  /// Type: color
  ///   default: #ffffff
  final dynamic fogColor;

  /// `fog-ground-blend`: how to blend the fog over the 3D terrain, where 0 is
  /// the map center and 1 is the horizon.
  ///
  /// Type: number
  ///   default: 0.5
  final dynamic fogGroundBlend;

  /// `horizon-fog-blend`: how to blend the fog color and the horizon color,
  /// where 0 uses the horizon color only and 1 the fog color only.
  ///
  /// Type: number
  ///   default: 0.8
  final dynamic horizonFogBlend;

  /// `sky-horizon-blend`: how to blend the sky color and the horizon color,
  /// where 1 blends the color at the middle of the sky and 0 does not blend
  /// at all and uses the sky color only.
  ///
  /// Type: number
  ///   default: 0.8
  final dynamic skyHorizonBlend;

  /// `atmosphere-blend`: how to blend the atmosphere, where 1 is a visible
  /// atmosphere and 0 a hidden one. Best interpolated by zoom when using the
  /// globe projection.
  ///
  /// Type: number
  ///   default: 0.8
  final dynamic atmosphereBlend;

  const SkyProperties({
    this.skyColor,
    this.horizonColor,
    this.fogColor,
    this.fogGroundBlend,
    this.horizonFogBlend,
    this.skyHorizonBlend,
    this.atmosphereBlend,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value == null) return;
      json[fieldName] = value;
    }

    addIfPresent('sky-color', skyColor);
    addIfPresent('horizon-color', horizonColor);
    addIfPresent('fog-color', fogColor);
    addIfPresent('fog-ground-blend', fogGroundBlend);
    addIfPresent('horizon-fog-blend', horizonFogBlend);
    addIfPresent('sky-horizon-blend', skyHorizonBlend);
    addIfPresent('atmosphere-blend', atmosphereBlend);
    return json;
  }
}

/// Properties of the style's `terrain` root object.
class TerrainProperties {
  /// `source`: the id of the raster dem source holding the terrain data.
  ///
  /// Type: string
  final String source;

  /// `exaggeration`: the exaggeration of the terrain, how high it will look.
  ///
  /// Type: number
  ///   default: 1
  final dynamic exaggeration;

  const TerrainProperties({required this.source, this.exaggeration});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'source': source};
    if (exaggeration != null) {
      json['exaggeration'] = exaggeration;
    }
    return json;
  }
}

/// Properties of the style's `light` root object.
class LightProperties {
  /// `anchor`: whether extruded geometries are lit relative to the map or
  /// viewport. One of "map" or "viewport".
  ///
  /// Type: enum
  ///   default: viewport
  final dynamic anchor;

  /// `position`: position of the light source relative to lit (extruded)
  /// geometries, as `[r radial coordinate, a azimuthal angle, p polar angle]`.
  ///
  /// Type: array
  ///   default: [1.15, 210, 30]
  final dynamic position;

  /// `color`: color tint for lighting extruded geometries.
  ///
  /// Type: color
  ///   default: #ffffff
  final dynamic color;

  /// `intensity`: intensity of lighting, on a scale from 0 to 1. Higher
  /// numbers present as more extreme contrast.
  ///
  /// Type: number
  ///   default: 0.5
  final dynamic intensity;

  const LightProperties({
    this.anchor,
    this.position,
    this.color,
    this.intensity,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};

    void addIfPresent(String fieldName, dynamic value) {
      if (value == null) return;
      json[fieldName] = value;
    }

    addIfPresent('anchor', anchor);
    addIfPresent('position', position);
    addIfPresent('color', color);
    addIfPresent('intensity', intensity);
    return json;
  }
}
