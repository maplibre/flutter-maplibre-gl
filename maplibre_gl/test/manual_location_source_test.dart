import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('locationSource serialization', () {
    test('defaults to "platform" token in options', () {
      final options = MapLibreMapOptions.fromWidget(MapLibreMap());
      expect(options.toMap()['locationSource'], 'platform');
    });

    test('ManualLocationSource serializes to "manual" token in options', () {
      final options = MapLibreMapOptions.fromWidget(
        MapLibreMap(
          myLocationEnabled: true,
          locationSource: const ManualLocationSource(),
        ),
      );
      expect(options.toMap()['locationSource'], 'manual');
    });

    testWidgets('ManualLocationSource lands in creation-params options', (
      tester,
    ) async {
      final platform = FakeMapLibrePlatform();
      final previousFactory = MapLibrePlatform.createInstance;
      addTearDown(() => MapLibrePlatform.createInstance = previousFactory);
      MapLibrePlatform.createInstance = () => platform;

      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            myLocationEnabled: true,
            locationSource: const ManualLocationSource(),
          ),
        ),
      );

      final params = platform.lastCreationParams;
      expect(params, isNotNull);
      final options = params!['options'] as Map<String, dynamic>;
      expect(options['locationSource'], 'manual');
    });
  });

  group('controller.updateManualLocation', () {
    late FakeMapLibrePlatform platform;
    late MapLibreMapController controller;

    setUp(() {
      platform = FakeMapLibrePlatform();
      controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );
      platform.reset();
    });

    tearDown(() => controller.dispose());

    test('delegates to platform.setManualLocation with the update', () async {
      final update = ManualLocationUpdate(
        target: const LatLng(37.42, -122.08),
        bearing: 90,
        speed: 4.2,
        horizontalAccuracy: 8,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      await controller.updateManualLocation(update);

      final calls = platform.callsFor('setManualLocation');
      expect(calls.length, 1);
      final passed = calls.first.positionalArgs.first as ManualLocationUpdate;
      expect(passed, same(update));

      // The serialized payload sent across the channel is correct.
      final map = passed.toMap();
      expect(map['position'], [37.42, -122.08]);
      expect(map['bearing'], 90.0);
      expect(map['speed'], 4.2);
      expect(map['horizontalAccuracy'], 8.0);
      expect(map['timestamp'], 1700000000000);
    });
  });
}
