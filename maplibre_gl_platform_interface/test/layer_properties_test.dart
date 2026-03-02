import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Layer Properties', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];

      // Mock the method channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
        (methodCall) async {
          methodCalls.add(methodCall);
          return null;
        },
      );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('addCircleLayer passes properties without double encoding', () async {
      final properties = {
        'circle-radius': 10,
        'circle-color': '#FF0000',
        'circle-stroke-width': 2.5,
        'circle-opacity': 0.8,
      };

      await platform.addCircleLayer(
        'source-id',
        'layer-id',
        properties,
        enableInteraction: true,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'circleLayer#add');

      final args = methodCalls[0].arguments as Map;
      final receivedProperties = args['properties'] as Map;

      // Verify properties are passed as native types, not JSON strings
      expect(receivedProperties['circle-radius'], 10); // Not "10"
      expect(
          receivedProperties['circle-color'], '#FF0000'); // Not "\"#FF0000\""
      expect(receivedProperties['circle-stroke-width'], 2.5); // Not "2.5"
      expect(receivedProperties['circle-opacity'], 0.8); // Not "0.8"
    });

    test('addSymbolLayer passes properties without double encoding', () async {
      final properties = {
        'icon-size': 1.5,
        'text-color': '#000000',
        'text-field': 'Hello',
      };

      await platform.addSymbolLayer(
        'source-id',
        'layer-id',
        properties,
        enableInteraction: false,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'symbolLayer#add');

      final args = methodCalls[0].arguments as Map;
      final receivedProperties = args['properties'] as Map;

      expect(receivedProperties['icon-size'], 1.5);
      expect(receivedProperties['text-color'], '#000000');
      expect(receivedProperties['text-field'], 'Hello');
    });

    test('setLayerProperties passes properties without double encoding',
        () async {
      final properties = {
        'visibility': 'visible',
        'circle-radius': 15,
      };

      await platform.setLayerProperties('layer-id', properties);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'layer#setProperties');

      final args = methodCalls[0].arguments as Map;
      final receivedProperties = args['properties'] as Map;

      expect(receivedProperties['visibility'], 'visible');
      expect(receivedProperties['circle-radius'], 15);
    });

    test('addLineLayer passes array properties correctly', () async {
      final properties = {
        'line-color': '#0000FF',
        'line-width': 3,
        'line-dasharray': [2, 4],
      };

      await platform.addLineLayer(
        'source-id',
        'layer-id',
        properties,
        enableInteraction: true,
      );

      expect(methodCalls.length, 1);
      final args = methodCalls[0].arguments as Map;
      final receivedProperties = args['properties'] as Map;

      expect(receivedProperties['line-color'], '#0000FF');
      expect(receivedProperties['line-width'], 3);
      expect(receivedProperties['line-dasharray'], [2, 4]);
    });
  });
}
