import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

import 'json_convert.dart';

/// Converts a decoded GeoJSON document (FeatureCollection, Feature, or bare
/// geometry map) into the typed [mln.GeoJson] descriptors the bindings use
/// for GeoJSON source updates.
mln.GeoJson geoJsonFromDart(Map<String, dynamic> document) {
  return switch (document['type'] as String?) {
    'FeatureCollection' => mln.FeatureCollectionGeoJson([
      for (final feature in (document['features'] as List? ?? const []))
        _featureFromDart((feature as Map).cast<String, dynamic>()),
    ]),
    'Feature' => _featureFromDart(document),
    _ => mln.GeometryGeoJson(geometryFromDart(document)),
  };
}

mln.FeatureGeoJson _featureFromDart(Map<String, dynamic> feature) {
  final geometry = feature['geometry'] as Map?;
  final properties = feature['properties'] as Map?;
  return mln.FeatureGeoJson(
    geometry: geometry == null
        ? const mln.EmptyGeometry()
        : geometryFromDart(geometry.cast<String, dynamic>()),
    properties: [
      if (properties != null)
        for (final entry in properties.entries)
          mln.JsonMember(
            entry.key as String,
            jsonValueFromDart(entry.value),
          ),
    ],
    identifier: _identifierFromDart(feature['id']),
  );
}

mln.FeatureIdentifier _identifierFromDart(Object? id) {
  return switch (id) {
    null => const mln.NullFeatureIdentifier(),
    final int value => mln.IntFeatureIdentifier(value),
    final double value => mln.DoubleFeatureIdentifier(value),
    final String value => mln.StringFeatureIdentifier(value),
    _ => throw ArgumentError.value(
      id,
      'id',
      'unsupported GeoJSON feature id of type ${id.runtimeType}',
    ),
  };
}

// GeoJSON positions are [lng, lat(, alt)]; the bindings take (lat, lng).
mln.LatLng _position(List position) => mln.LatLng(
  (position[1] as num).toDouble(),
  (position[0] as num).toDouble(),
);

List<mln.LatLng> _line(List coordinates) => [
  for (final position in coordinates) _position(position as List),
];

List<List<mln.LatLng>> _rings(List rings) => [
  for (final ring in rings) _line(ring as List),
];

/// Converts a decoded GeoJSON geometry map into a typed [mln.Geometry].
mln.Geometry geometryFromDart(Map<String, dynamic> geometry) {
  final coordinates = geometry['coordinates'];
  return switch (geometry['type'] as String?) {
    'Point' => mln.PointGeometry(_position(coordinates as List)),
    'LineString' => mln.LineStringGeometry(_line(coordinates as List)),
    'Polygon' => mln.PolygonGeometry(_rings(coordinates as List)),
    'MultiPoint' => mln.MultiPointGeometry(_line(coordinates as List)),
    'MultiLineString' => mln.MultiLineStringGeometry(
      _rings(coordinates as List),
    ),
    'MultiPolygon' => mln.MultiPolygonGeometry([
      for (final polygon in coordinates as List) _rings(polygon as List),
    ]),
    'GeometryCollection' => mln.GeometryCollection([
      for (final child in (geometry['geometries'] as List? ?? const []))
        geometryFromDart((child as Map).cast<String, dynamic>()),
    ]),
    final other => throw ArgumentError.value(
      other,
      'type',
      'unsupported GeoJSON geometry type',
    ),
  };
}

/// Converts a typed [mln.FeatureGeoJson] (e.g. from a feature query) back
/// into a plain GeoJSON feature map.
Map<String, dynamic> featureToDart(mln.FeatureGeoJson feature) {
  return <String, dynamic>{
    'type': 'Feature',
    'id': ?_identifierToDart(feature.identifier),
    'geometry': geometryToDart(feature.geometry),
    'properties': <String, dynamic>{
      for (final member in feature.properties)
        member.key: jsonValueToDart(member.value),
    },
  };
}

Object? _identifierToDart(mln.FeatureIdentifier identifier) {
  return switch (identifier) {
    mln.NullFeatureIdentifier() => null,
    mln.UIntFeatureIdentifier(:final value) => value,
    mln.IntFeatureIdentifier(:final value) => value,
    mln.DoubleFeatureIdentifier(:final value) => value,
    mln.StringFeatureIdentifier(:final value) => value,
  };
}

List<double> _positionToDart(mln.LatLng coordinate) => <double>[
  coordinate.longitude,
  coordinate.latitude,
];

List<List<double>> _lineToDart(List<mln.LatLng> coordinates) => [
  for (final coordinate in coordinates) _positionToDart(coordinate),
];

List<List<List<double>>> _ringsToDart(List<List<mln.LatLng>> rings) => [
  for (final ring in rings) _lineToDart(ring),
];

/// Converts a typed [mln.Geometry] back into a plain GeoJSON geometry map.
Map<String, dynamic>? geometryToDart(mln.Geometry geometry) {
  return switch (geometry) {
    mln.EmptyGeometry() => null,
    mln.PointGeometry(:final coordinate) => <String, dynamic>{
      'type': 'Point',
      'coordinates': _positionToDart(coordinate),
    },
    mln.LineStringGeometry(:final coordinates) => <String, dynamic>{
      'type': 'LineString',
      'coordinates': _lineToDart(coordinates),
    },
    mln.PolygonGeometry(:final rings) => <String, dynamic>{
      'type': 'Polygon',
      'coordinates': _ringsToDart(rings),
    },
    mln.MultiPointGeometry(:final coordinates) => <String, dynamic>{
      'type': 'MultiPoint',
      'coordinates': _lineToDart(coordinates),
    },
    mln.MultiLineStringGeometry(:final lines) => <String, dynamic>{
      'type': 'MultiLineString',
      'coordinates': _ringsToDart(lines),
    },
    mln.MultiPolygonGeometry(:final polygons) => <String, dynamic>{
      'type': 'MultiPolygon',
      'coordinates': [for (final polygon in polygons) _ringsToDart(polygon)],
    },
    mln.GeometryCollection(:final geometries) => <String, dynamic>{
      'type': 'GeometryCollection',
      'geometries': [
        for (final child in geometries) geometryToDart(child),
      ],
    },
  };
}
