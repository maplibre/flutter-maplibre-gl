import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/src/geojson_size.dart';

void main() {
  // The heuristic deciding whether to offload is where correctness lives: an
  // area with a huge single ring must be treated as large even though its
  // top-level `coordinates` array holds one entry (#366).
  group('isLargeGeoJson', () {
    test('large starts at the thresholds', () {
      Map<String, dynamic> points(int count) => {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < count; i++)
            {
              'type': 'Feature',
              'geometry': geometry('Point', [0.0, 0.0]),
            },
        ],
      };
      Map<String, dynamic> line(int count) =>
          featureCollection(geometry('LineString', ring(count)));

      expect(isLargeGeoJson(points(geoJsonOffloadFeatureCount - 1)), isFalse);
      expect(isLargeGeoJson(points(geoJsonOffloadFeatureCount)), isTrue);
      expect(isLargeGeoJson(line(geoJsonOffloadPositionCount - 1)), isFalse);
      expect(isLargeGeoJson(line(geoJsonOffloadPositionCount)), isTrue);
    });

    test('a long LineString is large', () {
      expect(
        isLargeGeoJson(
          featureCollection(geometry('LineString', ring(2000))),
        ),
        isTrue,
      );
    });

    test('a short LineString is not large', () {
      expect(
        isLargeGeoJson(
          featureCollection(geometry('LineString', ring(10))),
        ),
        isFalse,
      );
    });

    test('a Polygon with one huge ring is large', () {
      expect(
        isLargeGeoJson(
          featureCollection(geometry('Polygon', [ring(50000)])),
        ),
        isTrue,
      );
    });

    test('a MultiPolygon with one huge ring is large', () {
      expect(
        isLargeGeoJson(
          featureCollection(
            geometry('MultiPolygon', [
              [ring(50000)],
            ]),
          ),
        ),
        isTrue,
      );
    });

    test('a MultiLineString whose lines add up is large', () {
      expect(
        isLargeGeoJson(
          featureCollection(
            geometry('MultiLineString', [
              for (var i = 0; i < 20; i++) ring(200),
            ]),
          ),
        ),
        isTrue,
      );
    });

    test('a GeometryCollection is measured through its geometries', () {
      expect(
        isLargeGeoJson(
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

    test('many small features add up to large', () {
      expect(
        isLargeGeoJson({
          'type': 'FeatureCollection',
          'features': [
            for (var i = 0; i < 30; i++)
              {
                'type': 'Feature',
                'properties': <String, dynamic>{},
                'geometry': geometry('LineString', ring(100)),
              },
          ],
        }),
        isTrue,
      );
    });

    test('a small collection is not large', () {
      expect(
        isLargeGeoJson({
          'type': 'FeatureCollection',
          'features': [
            for (var i = 0; i < 5; i++)
              {
                'type': 'Feature',
                'properties': <String, dynamic>{},
                'geometry': geometry('Point', [i * 1.0, i * 1.0]),
              },
          ],
        }),
        isFalse,
      );
    });

    test('a bare geometry is measured on its own', () {
      expect(
        isLargeGeoJson(
          geometry('Polygon', [ring(50000)]),
        ),
        isTrue,
      );
      expect(
        isLargeGeoJson(geometry('Point', [0.0, 0.0])),
        isFalse,
      );
    });

    test('malformed payloads are treated as small instead of throwing', () {
      expect(
        isLargeGeoJson(<String, dynamic>{}),
        isFalse,
      );
      expect(
        isLargeGeoJson({
          'type': 'FeatureCollection',
          'features': [null, 'nonsense', <String, dynamic>{}],
        }),
        isFalse,
      );
      expect(
        isLargeGeoJson({
          'type': 'Polygon',
          'coordinates': 'not a list',
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
