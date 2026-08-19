import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Source', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'map#editGeoJsonSource':
                case 'map#editGeoJsonUrl':
                  return <Object?, Object?>{'result': true};
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('addGeoJsonSource sends correct method and arguments', () async {
      final geojson = {'type': 'FeatureCollection', 'features': <dynamic>[]};
      await platform.addGeoJsonSource('test-source', geojson);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#addGeoJson');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'test-source');
      expect(args['geojson'], jsonEncode(geojson));
    });

    test('setGeoJsonSource sends correct method and arguments', () async {
      final geojson = {'type': 'FeatureCollection', 'features': <dynamic>[]};
      await platform.setGeoJsonSource('test-source', geojson);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#setGeoJson');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'test-source');
      expect(args['geojson'], jsonEncode(geojson));
    });

    test('addSource sends correct method with serialized properties', () async {
      const props = VectorSourceProperties(
        url: 'https://example.com/tiles.json',
      );
      await platform.addSource('vec-source', props);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#addSource');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'vec-source');
      final properties = args['properties'] as Map;
      expect(properties['type'], 'vector');
      expect(properties['url'], 'https://example.com/tiles.json');
    });

    // The native converters read these two keys by name, so a rename on the
    // Dart side has to fail here rather than silently stop working on device.
    test('addSource forwards volatile and clusterMinPoints', () async {
      await platform.addSource(
        'vec-source',
        const VectorSourceProperties(
          url: 'https://example.com/tiles.json',
          volatile: true,
        ),
      );
      await platform.addSource(
        'points',
        const GeojsonSourceProperties(cluster: true, clusterMinPoints: 5),
      );

      final vector = (methodCalls[0].arguments as Map)['properties'] as Map;
      expect(vector['volatile'], true);
      final geojson = (methodCalls[1].arguments as Map)['properties'] as Map;
      expect(geojson['clusterMinPoints'], 5);
    });

    // MapLibre Native decodes only mapbox and terrarium, and would read custom
    // tiles as mapbox-encoded: plausible map, wrong elevations. The message has
    // to say that only addSource() is checked, because the same encoding inside
    // MapLibreMap.styleString still falls back to mapbox silently.
    test('addSource rejects the custom raster-dem encoding', () async {
      expect(
        () => platform.addSource(
          'dem',
          const RasterDemSourceProperties(
            tiles: ['https://example.com/{z}/{x}/{y}.png'],
            encoding: 'custom',
            redFactor: 256,
            baseShift: -32768,
          ),
        ),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('styleString'),
          ),
        ),
      );
      expect(methodCalls, isEmpty);
    });

    // The factors are read only on a custom encoding, so next to mapbox or
    // terrarium they are the no-op Android and iOS have always made of them.
    // One properties object shared by all three platforms, or a style copied
    // from JSON carrying the spec defaults, must keep working.
    test('addSource accepts the factors on a known encoding', () async {
      await platform.addSource(
        'dem-mapbox',
        const RasterDemSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          // Spelling out the encoding is the case under test: a style copied
          // from JSON carries it, default or not.
          // ignore: avoid_redundant_argument_values
          encoding: 'mapbox',
          redFactor: 1.0,
          baseShift: 0.0,
        ),
      );
      await platform.addSource(
        'dem-terrarium',
        const RasterDemSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          encoding: 'terrarium',
          greenFactor: 2.0,
        ),
      );

      expect(methodCalls.length, 2);
      final mapbox = (methodCalls[0].arguments as Map)['properties'] as Map;
      expect(mapbox['encoding'], 'mapbox');
      expect(mapbox['redFactor'], 1.0);
      final terrarium = (methodCalls[1].arguments as Map)['properties'] as Map;
      expect(terrarium['encoding'], 'terrarium');
      expect(terrarium['greenFactor'], 2.0);
    });

    test(
      'addSource passes the mapbox and terrarium encodings through',
      () async {
        await platform.addSource(
          'dem',
          const RasterDemSourceProperties(
            tiles: ['https://example.com/{z}/{x}/{y}.png'],
            encoding: 'terrarium',
          ),
        );

        expect(methodCalls.length, 1);
        final properties =
            (methodCalls[0].arguments as Map)['properties'] as Map;
        expect(properties['encoding'], 'terrarium');
      },
    );

    test('removeSource sends correct method', () async {
      await platform.removeSource('test-source');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#removeSource');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'test-source');
    });

    test('editGeoJsonSource sends correct method and returns result', () async {
      final result = await platform.editGeoJsonSource(
        'src-1',
        '{"type":"Feature"}',
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#editGeoJsonSource');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 'src-1');
      expect(args['data'], '{"type":"Feature"}');
      expect(result, true);
    });

    test('editGeoJsonUrl sends correct method and returns result', () async {
      final result = await platform.editGeoJsonUrl(
        'src-1',
        'https://example.com/data.geojson',
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#editGeoJsonUrl');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 'src-1');
      expect(args['url'], 'https://example.com/data.geojson');
      expect(result, true);
    });

    test('setFeatureForGeoJsonSource sends correct method', () async {
      final feature = {'type': 'Feature', 'properties': <String, dynamic>{}};
      await platform.setFeatureForGeoJsonSource('src-1', feature);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#setFeature');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'src-1');
      expect(args['geojsonFeature'], jsonEncode(feature));
    });

    // The encode for large payloads is moved off the main isolate (#366). The
    // offloaded result must be byte-identical to a synchronous jsonEncode.
    test(
      'addGeoJsonSource offloads a single large geometry correctly',
      () async {
        final geojson = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': List.generate(
                  40000,
                  (i) => [i * 0.001, i * 0.002],
                ),
              },
            },
          ],
        };

        await platform.addGeoJsonSource('big-line', geojson);

        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'source#addGeoJson');
        final args = methodCalls[0].arguments as Map;
        expect(args['geojson'], jsonEncode(geojson));
      },
    );

    test(
      'setGeoJsonSource offloads a many-feature collection correctly',
      () async {
        final geojson = {
          'type': 'FeatureCollection',
          'features': List.generate(
            500,
            (i) => {
              'type': 'Feature',
              'properties': {'id': i},
              'geometry': {
                'type': 'Point',
                'coordinates': [i * 0.01, i * 0.02],
              },
            },
          ),
        };

        await platform.setGeoJsonSource('many-points', geojson);

        expect(methodCalls.length, 1);
        final args = methodCalls[0].arguments as Map;
        expect(args['geojson'], jsonEncode(geojson));
      },
    );

    // Writes to one source must reach the platform in call order even when an
    // earlier, larger payload takes longer to encode than a later, small one.
    test('GeoJSON writes to the same source keep their order', () async {
      final big = featureCollection(geometry('LineString', ring(40000)));
      final small = featureCollection(geometry('Point', [0.0, 0.0]));

      final first = platform.setGeoJsonSource('same-source', big);
      final second = platform.setGeoJsonSource('same-source', small);
      await Future.wait([first, second]);

      expect(methodCalls.length, 2);
      expect(
        (methodCalls[0].arguments as Map)['geojson'],
        jsonEncode(big),
        reason: 'the large payload was queued first and must be sent first',
      );
      expect((methodCalls[1].arguments as Map)['geojson'], jsonEncode(small));
    });

    test(
      'a failed write does not block the next write to the same source',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
              (methodCall) async {
                methodCalls.add(methodCall);
                if (methodCalls.length == 1) {
                  throw PlatformException(code: 'boom');
                }
                return null;
              },
            );

        final small = featureCollection(geometry('Point', [0.0, 0.0]));
        await expectLater(
          platform.setGeoJsonSource('same-source', small),
          throwsA(isA<PlatformException>()),
        );
        await platform.setGeoJsonSource('same-source', small);

        expect(methodCalls.length, 2);
      },
    );
  });

  // The heuristic deciding whether to offload is where correctness lives: an
  // area with a huge single ring must be treated as large even though its
  // top-level `coordinates` array holds one entry (#366).
  group('MapLibreMethodChannel.isLargeGeoJson', () {
    test('a long LineString is large', () {
      expect(
        MapLibreMethodChannel.isLargeGeoJson(
          featureCollection(geometry('LineString', ring(2000))),
        ),
        isTrue,
      );
    });

    test('a short LineString is not large', () {
      expect(
        MapLibreMethodChannel.isLargeGeoJson(
          featureCollection(geometry('LineString', ring(10))),
        ),
        isFalse,
      );
    });

    test('a Polygon with one huge ring is large', () {
      expect(
        MapLibreMethodChannel.isLargeGeoJson(
          featureCollection(geometry('Polygon', [ring(50000)])),
        ),
        isTrue,
      );
    });

    test('a MultiPolygon with one huge ring is large', () {
      expect(
        MapLibreMethodChannel.isLargeGeoJson(
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
        MapLibreMethodChannel.isLargeGeoJson(
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
        MapLibreMethodChannel.isLargeGeoJson(
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
        MapLibreMethodChannel.isLargeGeoJson({
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
        MapLibreMethodChannel.isLargeGeoJson({
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
        MapLibreMethodChannel.isLargeGeoJson(
          geometry('Polygon', [ring(50000)]),
        ),
        isTrue,
      );
      expect(
        MapLibreMethodChannel.isLargeGeoJson(geometry('Point', [0.0, 0.0])),
        isFalse,
      );
    });

    test('malformed payloads are treated as small instead of throwing', () {
      expect(
        MapLibreMethodChannel.isLargeGeoJson(<String, dynamic>{}),
        isFalse,
      );
      expect(
        MapLibreMethodChannel.isLargeGeoJson({
          'type': 'FeatureCollection',
          'features': [null, 'nonsense', <String, dynamic>{}],
        }),
        isFalse,
      );
      expect(
        MapLibreMethodChannel.isLargeGeoJson({
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
