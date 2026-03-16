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
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('addFillLayer sends correct method', () async {
      await platform.addFillLayer(
        'source-id',
        'fill-layer',
        {'fill-color': '#FF0000'},
        enableInteraction: true,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'fillLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'source-id');
      expect(args['layerId'], 'fill-layer');
      expect(args['enableInteraction'], true);
      expect((args['properties'] as Map)['fill-color'], '#FF0000');
    });

    test('addFillExtrusionLayer sends correct method', () async {
      await platform.addFillExtrusionLayer(
        'source-id',
        'extrusion-layer',
        {'fill-extrusion-height': 100},
        enableInteraction: false,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'fillExtrusionLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['layerId'], 'extrusion-layer');
    });

    test('addRasterLayer sends correct method', () async {
      await platform.addRasterLayer(
        'raster-source',
        'raster-layer',
        {'raster-opacity': 0.8},
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'rasterLayer#add');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'raster-source');
      expect(args['layerId'], 'raster-layer');
    });

    test('addHillshadeLayer sends correct method', () async {
      await platform.addHillshadeLayer(
        'dem-source',
        'hillshade-layer',
        {'hillshade-exaggeration': 0.5},
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'hillshadeLayer#add');
    });

    test('addHeatmapLayer sends correct method', () async {
      await platform.addHeatmapLayer(
        'heat-source',
        'heatmap-layer',
        {'heatmap-radius': 30},
      );

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
