/// When GeoJSON is large enough to encode on a background isolate.
///
/// Android and iOS only accept GeoJSON as a JSON string, and `jsonEncode` on
/// the main isolate froze the UI on large geometries (#366). Above these
/// thresholds the encode goes through `compute`; below them it stays
/// synchronous, since spawning an isolate would make the common case slower
/// for nothing.
///
/// This buys a responsive UI, not speed: handing the payload over copies it.
/// On a desktop machine a 100k-point line blocked the main isolate for about
/// 46 ms inline and 30 ms offloaded, while the whole write grew from 45 ms to
/// 72 ms. A long-lived worker isolate was measured and rejected: spawning
/// costs about 0.1 ms, and a shared worker queues a small write behind a
/// large one.
library;

/// The number of features in a collection from which it is large.
const geoJsonOffloadFeatureCount = 100;

/// The number of coordinate positions, anywhere in the payload, from which it
/// is large.
const geoJsonOffloadPositionCount = 2000;

/// Whether [geojson] is large enough that encoding it should move off the
/// main isolate.
///
/// Counting stops at the threshold, so this costs at most
/// [geoJsonOffloadPositionCount] steps however large the payload is. It
/// counts positions rather than the length of `coordinates`, which is what
/// makes it right for areas: a `Polygon` with a single ring of 50k points has
/// a `coordinates` length of 1. Malformed parts count as empty.
bool isLargeGeoJson(Map<dynamic, dynamic> geojson) {
  const limit = geoJsonOffloadPositionCount;
  final features = geojson['features'];
  if (features is List) {
    if (features.length >= geoJsonOffloadFeatureCount) return true;
    var positions = 0;
    for (final feature in features) {
      if (feature is! Map) continue;
      positions += _countGeometryPositions(
        feature['geometry'],
        limit - positions,
      );
      if (positions >= limit) return true;
    }
    return false;
  }
  return _countGeometryPositions(geojson['geometry'] ?? geojson, limit) >=
      limit;
}

/// Counts the coordinate positions of a single geometry, giving up once
/// [limit] is reached. The result is capped at [limit].
int _countGeometryPositions(Object? geometry, int limit) {
  if (limit <= 0 || geometry is! Map) return 0;
  if (geometry['type'] == 'GeometryCollection') {
    final geometries = geometry['geometries'];
    if (geometries is! List) return 0;
    var positions = 0;
    for (final child in geometries) {
      positions += _countGeometryPositions(child, limit - positions);
      if (positions >= limit) return positions;
    }
    return positions;
  }
  return _countPositions(geometry['coordinates'], limit);
}

/// Counts positions inside a `coordinates` value of any nesting depth, giving
/// up once [limit] is reached. A list whose first entry is a number is one
/// position.
int _countPositions(Object? coordinates, int limit) {
  if (limit <= 0 || coordinates is! List || coordinates.isEmpty) return 0;
  if (coordinates.first is num) return 1;
  var positions = 0;
  for (final child in coordinates) {
    positions += _countPositions(child, limit - positions);
    if (positions >= limit) return positions;
  }
  return positions;
}
