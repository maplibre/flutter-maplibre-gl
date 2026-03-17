import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Camera', () {
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
            case 'map#queryCameraPosition':
              return <String, dynamic>{
                'bearing': 45.0,
                'target': <double>[10.0, 20.0],
                'tilt': 30.0,
                'zoom': 15.0,
              };
            case 'map#update':
              return <String, dynamic>{
                'bearing': 0.0,
                'target': <double>[0.0, 0.0],
                'tilt': 0.0,
                'zoom': 10.0,
              };
            case 'camera#animate':
            case 'camera#move':
              return true;
            case 'camera#ease':
              return true;
            default:
              return null;
          }
        },
      );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('animateCamera sends correct method and arguments', () async {
      final update = CameraUpdate.newLatLng(const LatLng(10.0, 20.0));
      await platform.animateCamera(update);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'camera#animate');
      final args = methodCalls[0].arguments as Map;
      expect(args['cameraUpdate'], update.toJson());
      expect(args['duration'], isNull);
    });

    test('animateCamera with duration', () async {
      final update = CameraUpdate.zoomIn();
      await platform.animateCamera(
        update,
        duration: const Duration(milliseconds: 500),
      );

      final args = methodCalls[0].arguments as Map;
      expect(args['duration'], 500);
    });

    test('moveCamera sends correct method and arguments', () async {
      final update = CameraUpdate.newLatLng(const LatLng(10.0, 20.0));
      await platform.moveCamera(update);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'camera#move');
      final args = methodCalls[0].arguments as Map;
      expect(args['cameraUpdate'], update.toJson());
    });

    test('easeCamera sends correct method and arguments', () async {
      final update = CameraUpdate.zoomTo(12.0);
      await platform.easeCamera(
        update,
        duration: const Duration(seconds: 1),
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'camera#ease');
      final args = methodCalls[0].arguments as Map;
      expect(args['cameraUpdate'], update.toJson());
      expect(args['duration'], 1000);
    });

    test('queryCameraPosition returns deserialized CameraPosition', () async {
      final result = await platform.queryCameraPosition();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#queryCameraPosition');
      expect(result, isNotNull);
      expect(result!.bearing, 45.0);
      expect(result.target, const LatLng(10.0, 20.0));
      expect(result.tilt, 30.0);
      expect(result.zoom, 15.0);
    });

    test(
      'updateMapOptions passes options and returns CameraPosition',
      () async {
        final result = await platform.updateMapOptions({'zoom': 10.0});

        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'map#update');
        final args = methodCalls[0].arguments as Map;
        expect(args['options'], {'zoom': 10.0});
        expect(result, isNotNull);
        expect(result!.zoom, 10.0);
      },
    );
  });
}
