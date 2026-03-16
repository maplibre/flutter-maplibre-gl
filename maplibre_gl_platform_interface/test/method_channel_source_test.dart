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

    test('addSource sends correct method with serialized properties',
        () async {
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

    test('removeSource sends correct method', () async {
      await platform.removeSource('test-source');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#removeSource');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'test-source');
    });

    test('editGeoJsonSource sends correct method and returns result',
        () async {
      final result =
          await platform.editGeoJsonSource('src-1', '{"type":"Feature"}');

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
  });
}
