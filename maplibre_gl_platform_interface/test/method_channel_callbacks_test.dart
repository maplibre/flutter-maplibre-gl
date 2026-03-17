import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Callbacks', () {
    late MapLibreMethodChannel platform;

    setUp(() async {
      platform = MapLibreMethodChannel();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
        (methodCall) async => null,
      );

      await platform.initPlatform(0);
    });

    Future<void> simulateNativeCallback(
      String method,
      Map<String, dynamic> arguments,
    ) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'plugins.flutter.io/maplibre_gl_0',
        data,
        (_) {},
      );
    }

    test('camera#onMove fires onCameraMovePlatform', () async {
      CameraPosition? received;
      platform.onCameraMovePlatform.add((pos) => received = pos);

      await simulateNativeCallback('camera#onMove', {
        'position': {
          'bearing': 45.0,
          'target': <double>[10.0, 20.0],
          'tilt': 30.0,
          'zoom': 15.0,
        },
      });

      expect(received, isNotNull);
      expect(received!.bearing, 45.0);
      expect(received!.target, const LatLng(10.0, 20.0));
      expect(received!.tilt, 30.0);
      expect(received!.zoom, 15.0);
    });

    test('camera#onIdle fires onCameraIdlePlatform', () async {
      CameraPosition? received;
      platform.onCameraIdlePlatform.add((pos) => received = pos);

      await simulateNativeCallback('camera#onIdle', {
        'position': {
          'bearing': 0.0,
          'target': <double>[0.0, 0.0],
          'tilt': 0.0,
          'zoom': 5.0,
        },
      });

      expect(received, isNotNull);
      expect(received!.zoom, 5.0);
    });

    test('camera#onMoveStarted fires onCameraMoveStartedPlatform', () async {
      var called = false;
      platform.onCameraMoveStartedPlatform.add((_) => called = true);

      await simulateNativeCallback('camera#onMoveStarted', {});

      expect(called, isTrue);
    });

    test(
      'map#onMapClick fires onMapClickPlatform with Point and LatLng',
      () async {
        Map<String, dynamic>? received;
        platform.onMapClickPlatform.add((data) => received = data);

        await simulateNativeCallback('map#onMapClick', {
          'x': 100.0,
          'y': 200.0,
          'lng': 20.0,
          'lat': 10.0,
        });

        expect(received, isNotNull);
        final point = received!['point'] as Point<double>;
        expect(point.x, 100.0);
        expect(point.y, 200.0);
        final latLng = received!['latLng'] as LatLng;
        expect(latLng.latitude, 10.0);
        expect(latLng.longitude, 20.0);
      },
    );

    test('map#onMapLongClick fires onMapLongClickPlatform', () async {
      Map<String, dynamic>? received;
      platform.onMapLongClickPlatform.add((data) => received = data);

      await simulateNativeCallback('map#onMapLongClick', {
        'x': 150.0,
        'y': 250.0,
        'lng': 30.0,
        'lat': 20.0,
      });

      expect(received, isNotNull);
      final latLng = received!['latLng'] as LatLng;
      expect(latLng.latitude, 20.0);
      expect(latLng.longitude, 30.0);
    });

    test('feature#onTap fires onFeatureTappedPlatform', () async {
      Map<String, dynamic>? received;
      platform.onFeatureTappedPlatform.add((data) => received = data);

      await simulateNativeCallback('feature#onTap', {
        'id': 'feature-1',
        'x': 100.0,
        'y': 200.0,
        'lng': 20.0,
        'lat': 10.0,
        'layerId': 'my-layer',
      });

      expect(received, isNotNull);
      expect(received!['id'], 'feature-1');
      expect(received!['layerId'], 'my-layer');
      expect(received!['point'], isA<Point<double>>());
      expect(received!['latLng'], isA<LatLng>());
    });

    test('feature#onDrag fires onFeatureDraggedPlatform', () async {
      Map<String, dynamic>? received;
      platform.onFeatureDraggedPlatform.add((data) => received = data);

      await simulateNativeCallback('feature#onDrag', {
        'id': 'feature-1',
        'x': 100.0,
        'y': 200.0,
        'originLat': 10.0,
        'originLng': 20.0,
        'currentLat': 11.0,
        'currentLng': 21.0,
        'deltaLat': 1.0,
        'deltaLng': 1.0,
        'eventType': 'start',
      });

      expect(received, isNotNull);
      expect(received!['id'], 'feature-1');
      expect(received!['eventType'], 'start');
      final origin = received!['origin'] as LatLng;
      expect(origin.latitude, 10.0);
      final current = received!['current'] as LatLng;
      expect(current.latitude, 11.0);
    });

    test('map#onStyleLoaded fires onMapStyleLoadedPlatform', () async {
      var called = false;
      platform.onMapStyleLoadedPlatform.add((_) => called = true);

      await simulateNativeCallback('map#onStyleLoaded', {});

      expect(called, isTrue);
    });

    test('map#onCameraTrackingChanged fires with correct mode', () async {
      MyLocationTrackingMode? received;
      platform.onCameraTrackingChangedPlatform.add((mode) => received = mode);

      await simulateNativeCallback('map#onCameraTrackingChanged', {
        'mode': MyLocationTrackingMode.tracking.index,
      });

      expect(received, MyLocationTrackingMode.tracking);
    });

    test('map#onUserLocationUpdated fires with correct UserLocation', () async {
      UserLocation? received;
      platform.onUserLocationUpdatedPlatform.add((loc) => received = loc);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await simulateNativeCallback('map#onUserLocationUpdated', {
        'userLocation': {
          'position': <double>[45.0, 90.0],
          'altitude': 100.0,
          'bearing': 180.0,
          'speed': 5.0,
          'horizontalAccuracy': 10.0,
          'verticalAccuracy': 15.0,
          'timestamp': timestamp,
        },
        'heading': {
          'magneticHeading': 90.0,
          'trueHeading': 92.0,
          'headingAccuracy': 5.0,
          'x': 1.0,
          'y': 2.0,
          'z': 3.0,
          'timestamp': timestamp,
        },
      });

      expect(received, isNotNull);
      expect(received!.position, const LatLng(45.0, 90.0));
      expect(received!.altitude, 100.0);
      expect(received!.bearing, 180.0);
      expect(received!.speed, 5.0);
      expect(received!.heading, isNotNull);
      expect(received!.heading!.magneticHeading, 90.0);
      expect(received!.heading!.x, 1.0);
      expect(received!.heading!.y, 2.0);
      expect(received!.heading!.z, 3.0);
    });

    test('map#onUserLocationUpdated with null heading', () async {
      UserLocation? received;
      platform.onUserLocationUpdatedPlatform.add((loc) => received = loc);

      await simulateNativeCallback('map#onUserLocationUpdated', {
        'userLocation': {
          'position': <double>[45.0, 90.0],
          'altitude': 100.0,
          'bearing': 180.0,
          'speed': 5.0,
          'horizontalAccuracy': 10.0,
          'verticalAccuracy': 15.0,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        'heading': null,
      });

      expect(received, isNotNull);
      expect(received!.heading, isNull);
    });

    test('infoWindow#onTap fires onInfoWindowTappedPlatform', () async {
      String? received;
      platform.onInfoWindowTappedPlatform.add((id) => received = id);

      await simulateNativeCallback('infoWindow#onTap', {
        'symbol': 'sym-1',
      });

      expect(received, 'sym-1');
    });
  });
}
