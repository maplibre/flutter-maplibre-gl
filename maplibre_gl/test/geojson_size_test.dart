import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/src/geojson_size.dart';

void main() {
  // Where the encode runs changes only how long the main isolate is blocked,
  // so these fix the decision for the typical payloads.
  group('encodesInBackground', () {
    test('many small features are encoded in place', () {
      expect(encodesInBackground(points(1000)), isFalse);
      expect(encodesInBackground(points(5000)), isFalse);
      expect(encodesInBackground(points(20000)), isFalse);
    });

    test('a small payload is encoded in place', () {
      expect(encodesInBackground(points(5)), isFalse);
      expect(encodesInBackground(lines(1, 1000)), isFalse);
      expect(encodesInBackground(geometry('Point', [0.0, 0.0])), isFalse);
    });

    test('a long LineString is encoded in the background', () {
      expect(encodesInBackground(lines(1, 2000)), isTrue);
      expect(encodesInBackground(lines(1, 200000)), isTrue);
    });

    test('a Polygon with one huge ring is encoded in the background', () {
      expect(
        encodesInBackground(
          featureCollection(geometry('Polygon', [ring(50000)])),
        ),
        isTrue,
      );
    });

    test('a MultiPolygon with one huge ring is encoded in the background', () {
      expect(
        encodesInBackground(
          featureCollection(
            geometry('MultiPolygon', [
              [ring(50000)],
            ]),
          ),
        ),
        isTrue,
      );
    });

    test(
      'a MultiLineString whose lines add up is encoded in the background',
      () {
        expect(
          encodesInBackground(
            featureCollection(
              geometry('MultiLineString', [
                for (var i = 0; i < 20; i++) ring(200),
              ]),
            ),
          ),
          isTrue,
        );
      },
    );

    test('a GeometryCollection is measured through its geometries', () {
      expect(
        encodesInBackground(
          featureCollection({
            'type': 'GeometryCollection',
            'geometries': [
              geometry('Polygon', [ring(50000)]),
            ],
          }),
        ),
        isTrue,
      );
    });

    test(
      'features with a few positions each are encoded in the background',
      () {
        expect(encodesInBackground(lines(1000, 10)), isTrue);
        expect(encodesInBackground(lines(100, 100)), isTrue);
      },
    );

    test('points with long properties are encoded in the background', () {
      final names = points(
        1000,
        properties:
            (i) => {
              'name': 'Point of interest number $i',
              'address': '$i Some Street, Some City',
              'opening_hours': 'Mo-Fr 09:00-18:00; Sa 10:00-14:00',
              'website': 'https://example.com/poi/$i',
              'kind': 'restaurant',
              'rating': 4.5,
              'tags': ['food', 'outdoor', 'family'],
            },
      );
      final descriptions = points(
        1000,
        properties: (i) => {'description': 'Lorem ipsum $i. ' * 30},
      );

      expect(encodesInBackground(names), isTrue);
      expect(encodesInBackground(descriptions), isTrue);
    });

    test('from 10,000 features the encode stays in place', () {
      expect(
        encodesInBackground(lines(geoJsonOffloadMaxFeatures - 1, 10)),
        isTrue,
      );
      expect(
        encodesInBackground(lines(geoJsonOffloadMaxFeatures, 10)),
        isFalse,
      );
    });

    test('a lone Feature is measured with its properties', () {
      Map<String, dynamic> feature(Object coordinates, String name) => {
        'type': 'Feature',
        'properties': {'name': name},
        'geometry': geometry('LineString', coordinates),
      };

      expect(encodesInBackground(feature(ring(2000), 'a')), isTrue);
      expect(encodesInBackground(feature(ring(10), 'a')), isFalse);
      expect(encodesInBackground(feature(ring(10), 'a' * 400000)), isTrue);
    });

    test('a bare geometry is measured on its own', () {
      expect(
        encodesInBackground(geometry('Polygon', [ring(50000)])),
        isTrue,
      );
      expect(encodesInBackground(geometry('LineString', ring(10))), isFalse);
    });

    test('it reads a few features however large the collection is', () {
      final features = _CountingList(lines(5000, 10)['features'] as List);

      expect(
        encodesInBackground({
          'type': 'FeatureCollection',
          'features': features,
        }),
        isTrue,
      );
      expect(features.reads, lessThanOrEqualTo(32));
    });

    test('malformed payloads are encoded in place instead of throwing', () {
      expect(encodesInBackground(<String, dynamic>{}), isFalse);
      expect(
        encodesInBackground({
          'type': 'FeatureCollection',
          'features': [null, 'nonsense', <String, dynamic>{}],
        }),
        isFalse,
      );
      expect(
        encodesInBackground({
          'type': 'Polygon',
          'coordinates': 'not a list',
        }),
        isFalse,
      );
      expect(
        encodesInBackground({
          'type': 'Feature',
          'properties': 'not a map',
          'geometry': {'type': 'LineString', 'coordinates': <Object>[]},
        }),
        isFalse,
      );
    });
  });
}

/// A list of [count] distinct positions.
List<List<double>> ring(int count) =>
    List.generate(count, (i) => [i * 0.001, i * 0.002]);

/// A GeoJSON geometry of [type] wrapping [coordinates].
Map<String, dynamic> geometry(String type, Object coordinates) => {
  'type': type,
  'coordinates': coordinates,
};

/// A single-feature FeatureCollection around [geom].
Map<String, dynamic> featureCollection(Map<String, dynamic> geom) => {
  'type': 'FeatureCollection',
  'features': [
    {'type': 'Feature', 'properties': <String, dynamic>{}, 'geometry': geom},
  ],
};

/// A FeatureCollection of [count] points, with an int property or
/// [properties].
Map<String, dynamic> points(
  int count, {
  Map<String, dynamic> Function(int)? properties,
}) => {
  'type': 'FeatureCollection',
  'features': [
    for (var i = 0; i < count; i++)
      {
        'type': 'Feature',
        'id': i,
        'properties': properties?.call(i) ?? {'i': i},
        'geometry': geometry('Point', [i * 0.001, 0.0]),
      },
  ],
};

/// A FeatureCollection of [count] LineStrings of [positions] positions.
Map<String, dynamic> lines(int count, int positions) => {
  'type': 'FeatureCollection',
  'features': [
    for (var i = 0; i < count; i++)
      {
        'type': 'Feature',
        'id': i,
        'properties': {'i': i},
        'geometry': geometry('LineString', ring(positions)),
      },
  ],
};

/// A list that counts the reads of its entries.
class _CountingList extends ListBase<Object?> {
  _CountingList(this._list);

  final List<Object?> _list;
  int reads = 0;

  @override
  int get length => _list.length;

  @override
  set length(int value) => _list.length = value;

  @override
  Object? operator [](int index) {
    reads++;
    return _list[index];
  }

  @override
  void operator []=(int index, Object? value) => _list[index] = value;
}
