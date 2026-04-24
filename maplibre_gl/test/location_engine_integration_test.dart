import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;

  setUp(() {
    platform = FakeMapLibrePlatform();
    final previousFactory = MapLibrePlatform.createInstance;
    addTearDown(() {
      MapLibrePlatform.createInstance = previousFactory;
    });
    MapLibrePlatform.createInstance = () => platform;
  });

  group('LocationEnginePlatforms in creationParams', () {
    testWidgets('default location engine properties are included', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
            ),
          ),
        ),
      );

      final params = platform.lastCreationParams!;
      final options = params['options'] as Map<String, dynamic>;
      expect(options.containsKey('locationEngineProperties'), isTrue);
      expect(options['locationEngineProperties'], isList);
    });

    testWidgets('custom location engine properties are serialized', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
            ),
            locationEnginePlatforms: const LocationEnginePlatforms.android(
              enableHighAccuracy: true,
              interval: 500,
              displacement: 10,
            ),
          ),
        ),
      );

      final params = platform.lastCreationParams!;
      final options = params['options'] as Map<String, dynamic>;
      final props = options['locationEngineProperties'] as List;
      // Verify it's non-empty and different from default
      expect(props, isNotEmpty);
    });

    testWidgets(
      'different enableHighAccuracy produces different serialization',
      (tester) async {
        // First: default (no high accuracy)
        await tester.pumpWidget(
          MaterialApp(
            home: MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
              ),
            ),
          ),
        );

        final defaultParams = platform.lastCreationParams!;
        final defaultOptions = defaultParams['options'] as Map<String, dynamic>;
        final defaultProps = defaultOptions['locationEngineProperties'] as List;

        // Second: high accuracy
        await tester.pumpWidget(
          MaterialApp(
            home: MapLibreMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
              ),
              locationEnginePlatforms: const LocationEnginePlatforms.android(
                enableHighAccuracy: true,
              ),
            ),
          ),
        );

        final highParams = platform.lastCreationParams!;
        final highOptions = highParams['options'] as Map<String, dynamic>;
        final highProps = highOptions['locationEngineProperties'] as List;

        expect(defaultProps, isNot(equals(highProps)));
      },
    );

    testWidgets('myLocationEnabled is included in creation options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
            ),
            myLocationEnabled: true,
          ),
        ),
      );

      final params = platform.lastCreationParams!;
      final options = params['options'] as Map<String, dynamic>;
      expect(options['myLocationEnabled'], isTrue);
    });

    testWidgets('myLocationTrackingMode is included in creation options', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
            ),
            myLocationTrackingMode: MyLocationTrackingMode.tracking,
          ),
        ),
      );

      final params = platform.lastCreationParams!;
      final options = params['options'] as Map<String, dynamic>;
      expect(options['myLocationTrackingMode'], 1);
    });
  });

  group('Tracking mode delegation', () {
    test('updateMyLocationTrackingMode delegates to platform', () async {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );
      platform.reset();

      await controller.updateMyLocationTrackingMode(
        MyLocationTrackingMode.tracking,
      );

      final calls = platform.callsFor('updateMyLocationTrackingMode');
      expect(calls.length, 1);
      expect(
        calls.first.positionalArgs.first,
        MyLocationTrackingMode.tracking,
      );

      controller.dispose();
    });

    test('cycling through all tracking modes', () async {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );
      platform.reset();

      for (final mode in MyLocationTrackingMode.values) {
        await controller.updateMyLocationTrackingMode(mode);
      }

      final calls = platform.callsFor('updateMyLocationTrackingMode');
      expect(calls.length, MyLocationTrackingMode.values.length);
      for (var i = 0; i < MyLocationTrackingMode.values.length; i++) {
        expect(
          calls[i].positionalArgs.first,
          MyLocationTrackingMode.values[i],
        );
      }

      controller.dispose();
    });
  });

  group('User location updates', () {
    test('onUserLocationUpdated fires from platform event', () {
      UserLocation? received;

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onUserLocationUpdated: (location) {
          received = location;
        },
      );

      final location = UserLocation(
        position: const LatLng(37.7749, -122.4194),
        altitude: 10.0,
        bearing: 90.0,
        speed: 1.5,
        horizontalAccuracy: 5.0,
        verticalAccuracy: 3.0,
        heading: null,
        timestamp: DateTime(2026, 3, 20),
      );

      platform.onUserLocationUpdatedPlatform.call(location);

      expect(received, isNotNull);
      expect(received!.position.latitude, 37.7749);
      expect(received!.position.longitude, -122.4194);
      expect(received!.altitude, 10.0);
      expect(received!.speed, 1.5);
      expect(received!.horizontalAccuracy, 5.0);

      controller.dispose();
    });

    test('multiple location updates are all received', () {
      final locations = <UserLocation>[];

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onUserLocationUpdated: locations.add,
      );

      final timestamp = DateTime(2026, 3, 20);
      for (var i = 0; i < 5; i++) {
        platform.onUserLocationUpdatedPlatform.call(
          UserLocation(
            position: LatLng(37.0 + i * 0.001, -122.0 + i * 0.001),
            altitude: null,
            bearing: null,
            speed: null,
            horizontalAccuracy: null,
            verticalAccuracy: null,
            heading: null,
            timestamp: timestamp,
          ),
        );
      }

      expect(locations.length, 5);
      expect(locations.first.position.latitude, closeTo(37.0, 1e-6));
      expect(locations.last.position.latitude, closeTo(37.004, 1e-6));

      controller.dispose();
    });

    test('location update without callback does not crash', () {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      // Should not throw
      platform.onUserLocationUpdatedPlatform.call(
        UserLocation(
          position: const LatLng(37.0, -122.0),
          altitude: null,
          bearing: null,
          speed: null,
          horizontalAccuracy: null,
          verticalAccuracy: null,
          heading: null,
          timestamp: DateTime(2026, 3, 20),
        ),
      );

      controller.dispose();
    });
  });

  group('Camera tracking callbacks', () {
    test('onCameraTrackingDismissed fires from platform event', () {
      var dismissed = false;

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onCameraTrackingDismissed: () {
          dismissed = true;
        },
      );

      platform.onCameraTrackingDismissedPlatform.call(null);

      expect(dismissed, isTrue);

      controller.dispose();
    });

    test('onCameraTrackingChanged reports mode transitions', () {
      final modes = <MyLocationTrackingMode>[];

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onCameraTrackingChanged: modes.add,
      );

      platform.onCameraTrackingChangedPlatform.call(
        MyLocationTrackingMode.tracking,
      );
      platform.onCameraTrackingChangedPlatform.call(
        MyLocationTrackingMode.none,
      );

      expect(modes, [
        MyLocationTrackingMode.tracking,
        MyLocationTrackingMode.none,
      ]);

      controller.dispose();
    });
  });
}
