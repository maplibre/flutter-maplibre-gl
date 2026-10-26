/// Whether GeoJSON is cheaper to encode on a background isolate.
///
/// Android and iOS take GeoJSON as JSON text, and encoding a large geometry
/// on the main isolate froze the UI (#366). `compute` moves the encode to
/// another isolate, but copies the data there first, on the main isolate.
/// The copy is cheap for coordinates and free for strings, which isolates
/// share, but costs about as much as the encode for each feature, and several
/// times more once it outgrows the young heap. So the encode moves only when
/// the copy is estimated at under half of it: for long geometries and long
/// properties, not for many small features.
///
/// Measured on a desktop machine, AOT: 20,000 points blocked the main isolate
/// for 14 ms inline and 21 to 24 ms with `compute`. A 100,000-position line
/// blocked it for 31 ms inline and 17 to 19 ms with `compute`, while the
/// whole write grew to 53 ms.
library;

import 'dart:math' show min;

/// The estimated cost of encoding on the main isolate, from which the encode
/// may move to a background isolate: about 2,000 positions.
const int geoJsonOffloadMinCost = 2000 * _encodePosition;

/// The number of features from which encoding stays on the main isolate:
/// copying that many outgrows the young heap.
const geoJsonOffloadMaxFeatures = 10000;

/// Whether encoding [geojson] on a background isolate blocks the main
/// isolate clearly less than encoding it there.
///
/// It reads up to [_samples] features, spread over a collection, so it costs
/// the same however large [geojson] is. Malformed parts count as empty.
bool encodesInBackground(Map<dynamic, dynamic> geojson) {
  final cost = _Cost();
  final features = geojson['features'];
  if (features is List) {
    final count = features.length;
    if (count >= geoJsonOffloadMaxFeatures) return false;
    final step = count <= _samples ? 1 : count / _samples;
    final read = min(count, _samples);
    for (var i = 0; i < read; i++) {
      cost.feature(features[(i * step).floor()]);
    }
    if (read > 0) cost.scale(count / read);
  } else if (geojson['type'] == 'Feature') {
    cost.feature(geojson);
  } else {
    cost.geometry(geojson, 0);
  }
  return cost.encode >= geoJsonOffloadMinCost && cost.copy * 2 <= cost.encode;
}

/// The features [encodesInBackground] reads.
const _samples = 32;

// What each part costs on the main isolate, in nanoseconds on a desktop
// machine: encoded in place, or copied to another isolate. Only the ratios
// matter.
const _encodeFeature = 300;
const _encodePosition = 300;
const _encodeValue = 30;
const _encodeChar = 2;
const _copyFeature = 300;
const _copyPosition = 65;
const _copyValue = 10;

/// The deepest nesting of `coordinates` or `geometries` [_Cost] reads.
const _maxDepth = 6;

/// The property values of a feature [_Cost] reads.
const _maxValues = 64;

/// The estimated cost of encoding and of copying GeoJSON.
class _Cost {
  double encode = 0;
  double copy = 0;

  void scale(double factor) {
    encode *= factor;
    copy *= factor;
  }

  void feature(Object? feature) {
    if (feature is! Map) return;
    encode += _encodeFeature;
    copy += _copyFeature;
    geometry(feature['geometry'], 0);
    values(feature['properties']);
  }

  void geometry(Object? geometry, int depth) {
    if (geometry is! Map || depth > _maxDepth) return;
    final geometries = geometry['geometries'];
    if (geometries is List) {
      for (final child in geometries) {
        this.geometry(child, depth + 1);
      }
      return;
    }
    final positions = _positions(geometry['coordinates'], 0);
    encode += positions * _encodePosition;
    copy += positions * _copyPosition;
  }

  /// The entries of [properties]: a key or a string by its length, a list
  /// or map by its length, without reading further.
  void values(Object? properties) {
    if (properties is! Map || properties.isEmpty) return;
    var read = 0;
    var encodeValues = 0;
    var copyValues = 0;
    for (final MapEntry(:key, :value) in properties.entries) {
      if (read++ == _maxValues) break;
      final length = switch (value) {
        List() => value.length,
        Map() => value.length,
        _ => 1,
      };
      encodeValues += length * _encodeValue;
      copyValues += length * _copyValue;
      if (key is String) encodeValues += key.length * _encodeChar;
      if (value is String) encodeValues += value.length * _encodeChar;
    }
    final factor = properties.length / min(properties.length, _maxValues);
    encode += encodeValues * factor;
    copy += copyValues * factor;
  }
}

/// The positions in [coordinates]: a list whose first entry is a number is
/// one, and a list whose first entry is one counts by its length.
int _positions(Object? coordinates, int depth) {
  if (coordinates is! List || coordinates.isEmpty || depth > _maxDepth) {
    return 0;
  }
  final first = coordinates.first;
  if (first is num) return 1;
  if (first is List && first.isNotEmpty && first.first is num) {
    return coordinates.length;
  }
  var positions = 0;
  for (final child in coordinates) {
    positions += _positions(child, depth + 1);
  }
  return positions;
}
