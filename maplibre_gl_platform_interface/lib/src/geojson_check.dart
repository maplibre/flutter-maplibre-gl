part of '../maplibre_gl_platform_interface.dart';

/// The code of the [PlatformException] for data that is not GeoJSON.
const invalidGeoJsonCode = 'INVALID_GEOJSON';

/// Why [data] is not GeoJSON MapLibre can read, or null when it is.
///
/// Every platform runs this check, so the same data gets the same answer. It
/// accepts a FeatureCollection, Feature or geometry with the members RFC 7946
/// requires: `properties` an object or null, an `id` (if present) a string
/// or a number, and positions of at least two finite numbers, nested to the
/// depth of their geometry type.
///
/// It reads the data the way `jsonEncode` writes it: an object such as a
/// geometry or a position class counts as what its `toJson()` returns.
String? geoJsonError(Object? data) {
  final json = jsonValueOf(data);
  if (json is! Map) return 'GeoJSON must be an object.';
  final type = jsonValueOf(json['type']);
  if (type == 'FeatureCollection') {
    final features = jsonValueOf(json['features']);
    if (features is! List) {
      return 'A FeatureCollection must have a "features" array.';
    }
    for (var i = 0; i < features.length; i++) {
      final error = _featureError(features[i]);
      if (error != null) return 'Feature $i: $error';
    }
    return null;
  }
  if (type == 'Feature') return _featureError(json);
  return _geometryError(json);
}

/// Why [text] is not the JSON text of a GeoJSON object MapLibre can read, or
/// null when it is. See [geoJsonError].
String? geoJsonTextError(String text) => decodeGeoJson(text).error;

/// [text] decoded, and why it is not the JSON text of a GeoJSON object
/// MapLibre can read, or a null error when it is. See [geoJsonError].
({Object? data, String? error}) decodeGeoJson(String text) {
  final Object? data;
  try {
    data = jsonDecode(text);
  } on FormatException {
    return (data: null, error: 'Not valid JSON.');
  }
  return (data: data, error: geoJsonError(data));
}

/// Why [data] is not a GeoJSON Feature MapLibre can read, or null when it is.
/// See [geoJsonError].
String? geoJsonFeatureError(Object? data) {
  final json = jsonValueOf(data);
  if (json is! Map) return 'GeoJSON must be an object.';
  final type = jsonValueOf(json['type']);
  if (type != 'Feature') {
    return type is String
        ? 'It is a $type, not a Feature.'
        : 'A Feature must have the type "Feature".';
  }
  return _featureError(json);
}

/// [value] as `jsonEncode` writes it: [value] itself when it is null, a bool,
/// a number, a string, a list or a map, and what its `toJson()` returns
/// otherwise. A value without `toJson()` comes back as it is, and
/// `jsonEncode` would fail on it.
Object? jsonValueOf(Object? value) {
  if (value == null ||
      value is bool ||
      value is num ||
      value is String ||
      value is List ||
      value is Map) {
    return value;
  }
  try {
    return (value as dynamic).toJson();
    // A value without toJson(), which jsonEncode cannot write either.
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    return value;
  }
}

/// The [PlatformException] every platform answers for the data of the GeoJSON
/// source [sourceId] that [geoJsonError] rejects for [reason].
PlatformException invalidGeoJson(String sourceId, String reason) =>
    PlatformException(
      code: invalidGeoJsonCode,
      message: "The data for source '$sourceId' is not GeoJSON: $reason",
      details: reason,
    );

/// The [PlatformException] every platform answers for a feature of the GeoJSON
/// source [sourceId] that [geoJsonFeatureError] rejects for [reason].
PlatformException invalidGeoJsonFeature(String sourceId, String reason) =>
    PlatformException(
      code: invalidGeoJsonCode,
      message:
          "The feature for source '$sourceId' is not a GeoJSON Feature: "
          '$reason',
      details: reason,
    );

String? _featureError(Object? data) {
  final feature = jsonValueOf(data);
  if (feature is! Map) return 'A Feature must be an object.';
  if (jsonValueOf(feature['type']) != 'Feature') {
    return 'A Feature must have the type "Feature".';
  }
  if (!feature.containsKey('geometry')) {
    return 'A Feature must have a "geometry" member.';
  }
  final geometry = jsonValueOf(feature['geometry']);
  if (geometry != null) {
    final error = _geometryError(geometry);
    if (error != null) return error;
  }
  final properties = jsonValueOf(feature['properties']);
  if (properties != null && properties is! Map) {
    return 'The "properties" of a Feature must be an object or null.';
  }
  // MapLibre Native rejects a null id too.
  if (feature.containsKey('id')) {
    final id = jsonValueOf(feature['id']);
    if (id is! String && (id is! num || !id.isFinite)) {
      return 'The "id" of a Feature must be a string or a number.';
    }
  }
  return null;
}

/// How deep the positions of each geometry type are nested in its
/// `coordinates`: a Point is a position, a LineString an array of them, and
/// so on.
const _positionDepth = {
  'Point': 0,
  'MultiPoint': 1,
  'LineString': 1,
  'MultiLineString': 2,
  'Polygon': 2,
  'MultiPolygon': 3,
};

/// What the `coordinates` of each geometry type hold, for the errors.
const _coordinatesShape = {
  'Point': 'a position',
  'MultiPoint': 'an array of positions',
  'LineString': 'an array of positions',
  'MultiLineString': 'an array of arrays of positions',
  'Polygon': 'an array of rings, each an array of positions',
  'MultiPolygon': 'an array of polygons, each an array of rings of positions',
};

String? _geometryError(Object? data) {
  final geometry = jsonValueOf(data);
  if (geometry is! Map) return 'A geometry must be an object.';
  final type = jsonValueOf(geometry['type']);
  if (type == 'GeometryCollection') {
    final geometries = jsonValueOf(geometry['geometries']);
    if (geometries is! List) {
      return 'A GeometryCollection must have a "geometries" array.';
    }
    for (final child in geometries) {
      final error = _geometryError(child);
      if (error != null) return error;
    }
    return null;
  }
  if (type is! String) return 'A GeoJSON object must have a "type".';
  final depth = _positionDepth[type];
  if (depth == null) return '"$type" is not a GeoJSON type.';
  final coordinates = jsonValueOf(geometry['coordinates']);
  if (coordinates is! List || !_hasPositions(coordinates, depth)) {
    return 'The "coordinates" of a $type must be ${_coordinatesShape[type]}, '
        'where a position starts with a longitude and a latitude.';
  }
  return null;
}

/// Whether [coordinates] are arrays nested [depth] deep around positions,
/// each starting with two finite numbers.
bool _hasPositions(List<Object?> coordinates, int depth) {
  if (depth == 0) {
    if (coordinates.length < 2) return false;
    final longitude = _number(coordinates[0]);
    final latitude = _number(coordinates[1]);
    return longitude is num &&
        latitude is num &&
        longitude.isFinite &&
        latitude.isFinite;
  }
  for (final child in coordinates) {
    final list = child is List ? child : jsonValueOf(child);
    if (list is! List || !_hasPositions(list, depth - 1)) return false;
  }
  return true;
}

/// [value] when it is a number, and otherwise what `jsonEncode` writes for it.
Object? _number(Object? value) => value is num ? value : jsonValueOf(value);
