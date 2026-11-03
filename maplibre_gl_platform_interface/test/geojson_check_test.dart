// The GeoJSON check every platform runs before it hands data to MapLibre, so
// the same data gets the same answer on Android, iOS and web.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

Map<String, dynamic> _point([List<Object?> coordinates = const [1, 2]]) => {
  'type': 'Point',
  'coordinates': coordinates,
};

Map<String, dynamic> _feature(Object? geometry, {Object? id = 1}) => {
  'type': 'Feature',
  'id': id,
  'geometry': geometry,
  'properties': <String, dynamic>{},
};

Map<String, dynamic> _collection(List<Object?> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

/// A position class of a GeoJSON library: `jsonEncode` writes it as the list
/// its `toJson()` returns.
class _Position {
  const _Position(this.longitude, this.latitude);

  final num longitude;
  final num latitude;

  List<num> toJson() => [longitude, latitude];
}

/// A geometry class of an app model, written as the map its `toJson()`
/// returns.
class _Geometry {
  const _Geometry(this.type, this.coordinates);

  final String type;
  final Object? coordinates;

  Map<String, Object?> toJson() => {'type': type, 'coordinates': coordinates};
}

/// An object `jsonEncode` cannot write.
class _NotJson {
  const _NotJson();
}

void main() {
  group('geoJsonError accepts', () {
    for (final (name, data) in <(String, Object?)>[
      ('an empty FeatureCollection', _collection([])),
      ('a FeatureCollection', _collection([_feature(_point())])),
      ('a Feature', _feature(_point())),
      ('a geometry', _point()),
      ('a Feature without properties', {'type': 'Feature', 'geometry': null}),
      (
        'a Feature with null properties',
        {'type': 'Feature', 'geometry': _point(), 'properties': null},
      ),
      ('a Feature with a string id', _feature(_point(), id: 'a')),
      ('a Feature without a geometry', _feature(null)),
      ('a position with an altitude', _point([1, 2, 3])),
      (
        'members MapLibre does not read',
        {..._feature(_point()), 'bbox': 'any', 'foreign': true},
      ),
      (
        'every geometry type',
        _collection([
          for (final geometry in [
            _point(),
            {
              'type': 'MultiPoint',
              'coordinates': [
                [1, 2],
              ],
            },
            {
              'type': 'LineString',
              'coordinates': [
                [1, 2],
              ],
            },
            {
              'type': 'MultiLineString',
              'coordinates': [
                [
                  [1, 2],
                ],
              ],
            },
            {
              'type': 'Polygon',
              'coordinates': [
                [
                  [1, 2],
                  [3, 4],
                ],
              ],
            },
            {
              'type': 'MultiPolygon',
              'coordinates': [
                [
                  [
                    [1, 2],
                  ],
                ],
              ],
            },
            {
              'type': 'GeometryCollection',
              'geometries': [_point()],
            },
          ])
            _feature(geometry),
        ]),
      ),
      (
        'empty coordinates',
        {'type': 'LineString', 'coordinates': <Object>[]},
      ),
    ]) {
      test(name, () => expect(geoJsonError(data), isNull));
    }
  });

  group('geoJsonError rejects', () {
    for (final (name, data, reason) in <(String, Object?, String)>[
      ('what is not an object', [1, 2], 'GeoJSON must be an object.'),
      (
        'an object without a type',
        <String, dynamic>{},
        'A GeoJSON object '
            'must have a "type".',
      ),
      (
        'a type that is not a string',
        {'type': 5},
        'A GeoJSON object must '
            'have a "type".',
      ),
      (
        'an unknown type',
        {
          'type': 'Circle',
          'coordinates': [1, 2],
        },
        '"Circle" is not a GeoJSON type.',
      ),
      (
        'a FeatureCollection without features',
        {
          'type': 'FeatureCollection',
        },
        'A FeatureCollection must have a "features" array.',
      ),
      (
        'a feature that is not an object',
        _collection(['feature']),
        'Feature 0: A Feature must be an object.',
      ),
      (
        'a geometry in place of a feature',
        _collection([_feature(_point()), _point()]),
        'Feature 1: A Feature must have the type "Feature".',
      ),
      (
        'a Feature without a geometry member',
        {'type': 'Feature', 'properties': <String, dynamic>{}},
        'A Feature must have a "geometry" member.',
      ),
      (
        'a geometry that is not an object',
        _feature('Point'),
        'A geometry must be an object.',
      ),
      (
        'properties that are not an object',
        {..._feature(_point()), 'properties': 'none'},
        'The "properties" of a Feature must be an object or null.',
      ),
      (
        'an id that is neither a string nor a number',
        _feature(_point(), id: true),
        'The "id" of a Feature must be a string or a number.',
      ),
      (
        'a null id, which MapLibre Native rejects',
        _feature(_point(), id: null),
        'The "id" of a Feature must be a string or a number.',
      ),
      (
        'a geometry without coordinates',
        {'type': 'Point'},
        'The "coordinates" of a Point must be a position, where a position '
            'starts with a longitude and a latitude.',
      ),
      (
        'a position with one number',
        _point([1]),
        'The "coordinates" of a Point must be a position, where a position '
            'starts with a longitude and a latitude.',
      ),
      (
        'a position that is not numbers',
        _point(['1', '2']),
        'The "coordinates" of a Point must be a position, where a position '
            'starts with a longitude and a latitude.',
      ),
      (
        'a position that is not finite',
        _point([double.nan, 2]),
        'The "coordinates" of a Point must be a position, where a position '
            'starts with a longitude and a latitude.',
      ),
      (
        'a short position deep in a line',
        {
          'type': 'LineString',
          'coordinates': [
            [1, 2],
            [3],
          ],
        },
        'The "coordinates" of a LineString must be an array of positions, '
            'where a position starts with a longitude and a latitude.',
      ),
      (
        'positions where rings go',
        {
          'type': 'Polygon',
          'coordinates': [
            [1, 2],
            [3, 4],
          ],
        },
        'The "coordinates" of a Polygon must be an array of rings, each an '
            'array of positions, where a position starts with a longitude '
            'and a latitude.',
      ),
      (
        'a GeometryCollection without geometries',
        {'type': 'GeometryCollection'},
        'A GeometryCollection must have a "geometries" array.',
      ),
      (
        'a GeometryCollection holding something else',
        {
          'type': 'GeometryCollection',
          'geometries': [_point(), null],
        },
        'A geometry must be an object.',
      ),
    ]) {
      test(name, () => expect(geoJsonError(data), reason));
    }
  });

  // jsonEncode writes these objects through toJson(), so Android and iOS send
  // what toJson() returns, and the check reads the same.
  group('objects with toJson()', () {
    final line = {
      'type': 'Feature',
      'id': 1,
      'geometry': const _Geometry('LineString', [
        _Position(1, 2),
        _Position(3, 4),
      ]),
      'properties': <String, dynamic>{},
    };

    test('a geometry and its positions read as what toJson() returns', () {
      expect(geoJsonError(line), isNull);
      expect(geoJsonError(_collection([line])), isNull);
      expect(geoJsonFeatureError(line), isNull);
      expect(
        jsonDecode(jsonEncode(line)),
        _feature({
          'type': 'LineString',
          'coordinates': [
            [1, 2],
            [3, 4],
          ],
        }),
      );
    });

    test('a position object goes where a position does', () {
      expect(
        geoJsonError({
          'type': 'Polygon',
          'coordinates': [
            [const _Position(1, 2), const _Position(3, 4)],
          ],
        }),
        isNull,
      );
      expect(geoJsonError(_point([const _Position(1, 2)])), startsWith('The'));
    });

    test('toJson() data MapLibre cannot read fails like the data itself', () {
      expect(
        geoJsonError(
          _feature(
            const _Geometry('LineString', [_Position(1, double.nan)]),
          ),
        ),
        'The "coordinates" of a LineString must be an array of positions, '
        'where a position starts with a longitude and a latitude.',
      );
      expect(
        geoJsonError(_feature(const _Geometry('Circle', null))),
        '"Circle" is not a GeoJSON type.',
      );
    });

    test('an object jsonEncode cannot write is not GeoJSON', () {
      expect(
        geoJsonError(_feature(const _NotJson())),
        'A geometry must be an object.',
      );
      expect(
        geoJsonError(_point([const _NotJson(), 2])),
        startsWith('The "coordinates" of a Point'),
      );
    });

    test('jsonValueOf reads a value the way jsonEncode writes it', () {
      final map = <String, dynamic>{};
      final list = <Object?>[];
      for (final value in <Object?>[null, true, 1, 1.5, 'a', map, list]) {
        expect(jsonValueOf(value), same(value));
      }
      expect(jsonValueOf(const _Position(1, 2)), [1, 2]);
      const notJson = _NotJson();
      expect(jsonValueOf(notJson), same(notJson));
    });
  });

  group('geoJsonFeatureError', () {
    test('accepts a Feature', () {
      expect(geoJsonFeatureError(_feature(_point())), isNull);
    });

    test('rejects any other GeoJSON object', () {
      expect(geoJsonFeatureError(_point()), 'It is a Point, not a Feature.');
      expect(
        geoJsonFeatureError(_collection([])),
        'It is a FeatureCollection, not a Feature.',
      );
      expect(
        geoJsonFeatureError(<String, dynamic>{}),
        'A Feature must have the type "Feature".',
      );
    });

    test('rejects a Feature MapLibre cannot read', () {
      expect(
        geoJsonFeatureError(_feature(_point([1]))),
        startsWith('The "coordinates" of a Point'),
      );
    });
  });

  group('geoJsonTextError', () {
    test('reads the text first', () {
      expect(geoJsonTextError('{"type":"Point","coordinates":[1,2]}'), isNull);
      expect(geoJsonTextError('not json'), 'Not valid JSON.');
      expect(geoJsonTextError('"text"'), 'GeoJSON must be an object.');
    });

    test('decodeGeoJson keeps the data it checked', () {
      final point = decodeGeoJson('{"type":"Point","coordinates":[1,2]}');
      expect(point.data, _point());
      expect(point.error, isNull);
      expect(decodeGeoJson('not json'), (data: null, error: 'Not valid JSON.'));
      expect(decodeGeoJson('"text"'), (
        data: 'text',
        error: 'GeoJSON must be an object.',
      ));
    });
  });

  group('onFeature', () {
    test('sees each Feature of a collection with its index', () {
      final features = [_feature(_point(), id: 'a'), _feature(_point(), id: 2)];
      final seen = <(int, Object?)>[];

      expect(
        geoJsonError(
          _collection(features),
          onFeature: (index, feature) => seen.add((index, feature['id'])),
        ),
        isNull,
      );

      expect(seen, [(0, 'a'), (1, 2)]);
    });

    test('sees a lone Feature as index 0', () {
      final seen = <int>[];

      geoJsonError(_feature(_point()), onFeature: (i, _) => seen.add(i));
      geoJsonFeatureError(_feature(_point()), onFeature: (i, _) => seen.add(i));

      expect(seen, [0, 0]);
    });

    test('sees no Feature that fails the check, nor a geometry', () {
      final seen = <int>[];

      geoJsonError(
        _collection([
          _feature(_point()),
          _feature(_point([1])),
        ]),
        onFeature: (i, _) => seen.add(i),
      );
      geoJsonError(_point(), onFeature: (i, _) => seen.add(i));
      geoJsonFeatureError(
        _feature(_point([1])),
        onFeature: (i, _) => seen.add(i),
      );

      expect(seen, [0]);
    });
  });

  test('the exceptions name the source and the reason', () {
    expect(
      invalidGeoJson('points', 'Why.'),
      isA<PlatformException>()
          .having((e) => e.code, 'code', 'INVALID_GEOJSON')
          .having(
            (e) => e.message,
            'message',
            "The data for source 'points' is not GeoJSON: Why.",
          )
          .having((e) => e.details, 'details', 'Why.'),
    );
    expect(
      invalidGeoJsonFeature('points', 'Why.'),
      isA<PlatformException>()
          .having((e) => e.code, 'code', 'INVALID_GEOJSON')
          .having(
            (e) => e.message,
            'message',
            "The feature for source 'points' is not a GeoJSON Feature: Why.",
          ),
    );
  });
}
