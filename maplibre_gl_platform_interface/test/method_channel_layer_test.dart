import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Layer', () {
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
                case 'style#getLayerIds':
                  return <dynamic, dynamic>{
                    'layers': ['layer-1', 'layer-2', 'layer-3'],
                  };
                case 'style#getSourceIds':
                  return <dynamic, dynamic>{
                    'sources': ['source-1', 'source-2'],
                  };
                case 'layer#getVisibility':
                  return true;
                case 'style#getLayerProperties':
                  if (methodCall.arguments['layerId'] == 'missing') {
                    return <dynamic, dynamic>{};
                  }
                  return <dynamic, dynamic>{
                    'properties':
                        '{"id":"my-layer","type":"circle","source":"src",'
                        '"paint":{"circle-color":"#ff0000","circle-radius":5}}',
                  };
                case 'style#getSourceProperties':
                  return <dynamic, dynamic>{
                    'properties':
                        '{"type":"geojson","data":'
                        '{"type":"FeatureCollection","features":[]}}',
                  };
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('addFillLayer sends correct method', () async {
      await platform.addFillLayer('source-id', 'fill-layer', {
        'fill-color': '#FF0000',
      }, enableInteraction: true);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'fillLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'source-id');
      expect(args['layerId'], 'fill-layer');
      expect(args['enableInteraction'], true);
      expect((args['properties'] as Map)['fill-color'], '#FF0000');
    });

    test('addFillExtrusionLayer sends correct method', () async {
      await platform.addFillExtrusionLayer('source-id', 'extrusion-layer', {
        'fill-extrusion-height': 100,
      }, enableInteraction: false);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'fillExtrusionLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['layerId'], 'extrusion-layer');
    });

    test('addRasterLayer sends correct method', () async {
      await platform.addRasterLayer('raster-source', 'raster-layer', {
        'raster-opacity': 0.8,
      });

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'rasterLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'raster-source');
      expect(args['layerId'], 'raster-layer');
    });

    test('addHillshadeLayer sends correct method', () async {
      await platform.addHillshadeLayer('dem-source', 'hillshade-layer', {
        'hillshade-exaggeration': 0.5,
      });

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'hillshadeLayer#add');
    });

    test('addColorReliefLayer sends correct method', () async {
      await platform.addColorReliefLayer('dem-source', 'color-relief-layer', {
        'color-relief-opacity': 0.7,
      });

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'colorReliefLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'dem-source');
      expect(args['layerId'], 'color-relief-layer');
    });

    test('addBackgroundLayer sends correct method', () async {
      await platform.addBackgroundLayer('background-layer', {
        'background-color': '#ff0000',
      }, belowLayerId: 'below-this');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'backgroundLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['layerId'], 'background-layer');
      expect(args['belowLayerId'], 'below-this');
      expect(args.containsKey('sourceId'), false);
      expect((args['properties'] as Map)['background-color'], '#ff0000');
    });

    test('setLight sends correct method', () async {
      await platform.setLight(
        const LightProperties(
          anchor: 'map',
          position: [1.5, 90, 80],
          color: '#ffffff',
          intensity: 0.4,
        ),
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#setLight');
      final light = (methodCalls[0].arguments as Map)['light'] as Map;
      expect(light['anchor'], 'map');
      expect(light['position'], [1.5, 90, 80]);
      expect(light['color'], '#ffffff');
      expect(light['intensity'], 0.4);
    });

    test('setSky throws and sends nothing', () async {
      await expectLater(
        platform.setSky(const SkyProperties(skyColor: '#88C6FC')),
        throwsUnsupportedError,
      );
      expect(methodCalls, isEmpty);
    });

    test('setTerrain throws and sends nothing', () async {
      await expectLater(
        platform.setTerrain(const TerrainProperties(source: 'dem')),
        throwsUnsupportedError,
      );
      expect(methodCalls, isEmpty);
    });

    test('setProjection throws and sends nothing', () async {
      await expectLater(
        platform.setProjection('globe'),
        throwsUnsupportedError,
      );
      expect(methodCalls, isEmpty);
    });

    test('setGlobalStateProperty throws and sends nothing', () async {
      await expectLater(
        platform.setGlobalStateProperty('theme', 'dark'),
        throwsUnsupportedError,
      );
      expect(methodCalls, isEmpty);
    });

    test('addHeatmapLayer sends correct method', () async {
      await platform.addHeatmapLayer('heat-source', 'heatmap-layer', {
        'heatmap-radius': 30,
      });

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'heatmapLayer#add');
    });

    test('addLayer sends correct method', () async {
      await platform.addLayer('image-layer', 'image-source', 5, 15);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#addLayer');
      final args = methodCalls[0].arguments as Map;
      expect(args['imageLayerId'], 'image-layer');
      expect(args['imageSourceId'], 'image-source');
      expect(args['minzoom'], 5.0);
      expect(args['maxzoom'], 15.0);
    });

    test('addLayerBelow sends correct method', () async {
      await platform.addLayerBelow(
        'image-layer',
        'image-source',
        'below-this',
        null,
        null,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#addLayerBelow');
      final args = methodCalls[0].arguments as Map;
      expect(args['belowLayerId'], 'below-this');
    });

    test('removeLayer sends correct method', () async {
      await platform.removeLayer('layer-to-remove');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#removeLayer');
      final args = methodCalls[0].arguments as Map;
      expect(args['layerId'], 'layer-to-remove');
    });

    test('setLayerVisibility sends correct method', () async {
      await platform.setLayerVisibility('my-layer', false);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'layer#setVisibility');
      final args = methodCalls[0].arguments as Map;
      expect(args['layerId'], 'my-layer');
      expect(args['visible'], false);
    });

    test('getLayerVisibility returns result', () async {
      final result = await platform.getLayerVisibility('my-layer');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'layer#getVisibility');
      expect(result, true);
    });

    test('getLayerIds returns list of string ids', () async {
      final result = await platform.getLayerIds();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#getLayerIds');
      expect(result, ['layer-1', 'layer-2', 'layer-3']);
    });

    test('getSourceIds returns list of string ids', () async {
      final result = await platform.getSourceIds();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#getSourceIds');
      expect(result, ['source-1', 'source-2']);
    });

    test('getLayerProperties decodes the style-spec map', () async {
      final result = await platform.getLayerProperties('my-layer');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#getLayerProperties');
      expect(methodCalls[0].arguments['layerId'], 'my-layer');
      expect(result?['id'], 'my-layer');
      expect(result?['type'], 'circle');
      expect(result?['source'], 'src');
      expect((result?['paint'] as Map)['circle-color'], '#ff0000');
      expect((result?['paint'] as Map)['circle-radius'], 5);
    });

    test('getLayerProperties returns null for a missing layer', () async {
      final result = await platform.getLayerProperties('missing');

      expect(methodCalls[0].method, 'style#getLayerProperties');
      expect(result, isNull);
    });

    test('getSourceProperties decodes the style-spec map', () async {
      final result = await platform.getSourceProperties('src');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'style#getSourceProperties');
      expect(methodCalls[0].arguments['sourceId'], 'src');
      expect(result?['type'], 'geojson');
      expect((result?['data'] as Map)['type'], 'FeatureCollection');
    });

    test('addLayer with belowLayerId and zoom bounds', () async {
      await platform.addFillLayer(
        'source-id',
        'fill-layer',
        {'fill-color': '#FF0000'},
        belowLayerId: 'existing-layer',
        sourceLayer: 'my-source-layer',
        minzoom: 5,
        maxzoom: 15,
        enableInteraction: true,
      );

      final args = methodCalls[0].arguments as Map;
      expect(args['belowLayerId'], 'existing-layer');
      expect(args['sourceLayer'], 'my-source-layer');
      expect(args['minzoom'], 5.0);
      expect(args['maxzoom'], 15.0);
    });
  });
}
