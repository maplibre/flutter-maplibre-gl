/// Feature ids as they are in the data of a GeoJSON source.
///
/// maplibre-gl-js keeps only integer feature ids: `"2"` and `2.5` become `2`
/// and other text is lost. So each feature of a GeoJSON source the plugin
/// writes carries its id in [featureIdProperty] too, and the source takes its
/// ids from there with `promoteId`. The functions here keep that property out
/// of what the app reads, and make `['id']` in an expression read it, since
/// expressions see the integer ids even with `promoteId`.
library;

/// The property holding the id a feature has in the data, and the `promoteId`
/// of the GeoJSON sources whose ids the plugin keeps.
const featureIdProperty = 'maplibre_gl:id';

/// What `['id']` becomes in an expression: the id in the data, or the one
/// maplibre-gl-js holds for a feature that came without [featureIdProperty],
/// such as one loaded from a URL.
List<Object?> _idExpression() => [
  'coalesce',
  ['get', featureIdProperty],
  ['id'],
];

/// [value], an expression or a map of them such as layer properties, with
/// every `['id']` reading the id in the data. Returns [value] itself when it
/// holds no `['id']`.
Object? withFeatureIds(Object? value) {
  if (value is List) {
    if (_isId(value)) return _idExpression();
    if (value.isNotEmpty && value.first == 'literal') return value;
    return _mapList(value, withFeatureIds);
  }
  if (value is Map) return _mapValues(value, withFeatureIds);
  return value;
}

/// [value] read back from maplibre-gl-js, with [withFeatureIds] undone.
Object? withoutFeatureIds(Object? value) {
  if (value is List) {
    if (_isIdExpression(value)) return ['id'];
    return _mapList(value, withoutFeatureIds);
  }
  if (value is Map) return _mapValues(value, withoutFeatureIds);
  return value;
}

/// The id of a feature maplibre-gl-js reports with [id] and [properties],
/// taking [featureIdProperty] out of [properties]: the id in the data when
/// the feature carries it, [id] otherwise.
Object? takeFeatureId(Object? id, Map<dynamic, dynamic>? properties) {
  if (properties != null && properties.containsKey(featureIdProperty)) {
    return plainFeatureId(properties.remove(featureIdProperty));
  }
  return plainFeatureId(id);
}

/// [id] as a Dart value: a whole number is an [int]. Under dart2wasm every
/// JS number arrives as a [double], which would turn the id 2 into `"2.0"`.
Object? plainFeatureId(Object? id) {
  if (id is double &&
      id.isFinite &&
      id == id.truncateToDouble() &&
      id.abs() <= 9007199254740991) {
    return id.toInt();
  }
  return id;
}

/// [source], a source as maplibre-gl-js serializes it, without the
/// `promoteId` and the [featureIdProperty] the plugin added.
Map<String, dynamic> withoutFeatureIdsInSource(Map<String, dynamic> source) {
  if (source['type'] != 'geojson') return source;
  if (source['promoteId'] == featureIdProperty) source.remove('promoteId');
  final data = source['data'];
  if (data is Map) {
    final features = data['features'];
    if (features is List) {
      features.forEach(_removeFeatureIdProperty);
    } else {
      _removeFeatureIdProperty(data);
    }
  }
  return source;
}

void _removeFeatureIdProperty(Object? feature) {
  if (feature is! Map) return;
  final properties = feature['properties'];
  if (properties is Map) properties.remove(featureIdProperty);
}

bool _isId(List<Object?> value) => value.length == 1 && value.first == 'id';

bool _isIdExpression(List<Object?> value) =>
    value.length == 3 &&
    value[0] == 'coalesce' &&
    value[1] is List &&
    (value[1]! as List).length == 2 &&
    (value[1]! as List)[0] == 'get' &&
    (value[1]! as List)[1] == featureIdProperty &&
    value[2] is List &&
    _isId(value[2]! as List);

/// [list] with [convert] applied to each item, or [list] itself when that
/// changes nothing.
List<Object?> _mapList(List<Object?> list, Object? Function(Object?) convert) {
  List<Object?>? copy;
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    final converted = convert(item);
    if (!identical(converted, item)) {
      (copy ??= List<Object?>.of(list))[i] = converted;
    }
  }
  return copy ?? list;
}

/// [map] with [convert] applied to each value, or [map] itself when that
/// changes nothing.
Map<dynamic, dynamic> _mapValues(
  Map<dynamic, dynamic> map,
  Object? Function(Object?) convert,
) {
  Map<dynamic, dynamic>? copy;
  for (final entry in map.entries) {
    final converted = convert(entry.value);
    if (!identical(converted, entry.value)) {
      (copy ??=
              map is Map<String, dynamic>
                  ? Map<String, dynamic>.of(map)
                  : Map<dynamic, dynamic>.of(map))[entry.key] =
          converted;
    }
  }
  return copy ?? map;
}
