import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;

  setUp(() {
    platform = FakeMapLibrePlatform();
    MapLibrePlatform.createInstance = () => platform;
  });

  group('initialCameraPosition', () {
    testWidgets('is included in creationParams when set', (tester) async {
      const camera = CameraPosition(
        target: LatLng(37.7749, -122.4194),
        zoom: 12,
        bearing: 45,
        tilt: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(initialCameraPosition: camera),
        ),
      );

      final params = platform.lastCreationParams;
      expect(params, isNotNull);
      expect(params!.containsKey('initialCameraPosition'), isTrue);

      final cameraMap =
          params['initialCameraPosition'] as Map<String, dynamic>;
      expect(cameraMap['bearing'], 45.0);
      expect(cameraMap['zoom'], 12.0);
      expect(cameraMap['tilt'], 30.0);
      final target = cameraMap['target'] as List;
      expect(target[0], 37.7749); // lat
      expect(target[1], -122.4194); // lng
    });

    testWidgets('is omitted from creationParams when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap()),
      );

      final params = platform.lastCreationParams;
      expect(params, isNotNull);
      expect(params!.containsKey('initialCameraPosition'), isFalse);
    });

    testWidgets(
        'no initialCameraPosition and style without camera settings '
        'falls back to platform default', (tester) async {
      // Style has no center/zoom/bearing/pitch — platform must fall back
      // to its own defaults (typically center [0,0], zoom 0).
      const noCameraStyle =
          '{"version":8,"sources":{},"layers":[{"id":"bg","type":"background","paint":{"background-color":"#fff"}}]}';

      platform.triggerPlatformViewCreated = true;
      MapLibreMapController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            styleString: noCameraStyle,
            onMapCreated: (c) => controller = c,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // creationParams should have no camera
      final params = platform.lastCreationParams!;
      expect(params.containsKey('initialCameraPosition'), isFalse);
      expect(params['styleString'], noCameraStyle);

      // Controller starts with no camera knowledge
      expect(controller, isNotNull);
      expect(controller!.cameraPosition, isNull);

      // Platform settles on default [0,0] zoom 0 (no style camera either)
      const platformDefault = CameraPosition(target: LatLng(0, 0));
      platform.onCameraIdlePlatform.call(platformDefault);

      expect(controller!.cameraPosition, isNotNull);
      expect(controller!.cameraPosition!.target, const LatLng(0, 0));
      expect(controller!.cameraPosition!.zoom, 0);
    });

    testWidgets('camera with default values is still sent to platform', (
      tester,
    ) async {
      // User explicitly sets center [0,0] — this IS an intentional
      // camera position and must be forwarded to the platform.
      const camera = CameraPosition(target: LatLng(0, 0));

      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(initialCameraPosition: camera),
        ),
      );

      final params = platform.lastCreationParams!;
      expect(params.containsKey('initialCameraPosition'), isTrue);
      final cameraMap =
          params['initialCameraPosition'] as Map<String, dynamic>;
      expect(cameraMap['zoom'], 0.0);
      expect(cameraMap['bearing'], 0.0);
      expect(cameraMap['tilt'], 0.0);
      final target = cameraMap['target'] as List;
      expect(target[0], 0.0);
      expect(target[1], 0.0);
    });
  });

  group('Controller initialCameraPosition', () {
    test('cameraPosition is null when initialCameraPosition is null', () {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, isNull);
      controller.dispose();
    });

    test('cameraPosition matches provided initialCameraPosition', () {
      const camera = CameraPosition(
        target: LatLng(10, 20),
        zoom: 5,
      );

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: camera,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, camera);
      controller.dispose();
    });

    test(
        'null camera with no style camera — '
        'platform reports default position on idle', () {
      // Neither initialCameraPosition nor style camera is set.
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      // Before any platform event, controller has no camera knowledge.
      expect(controller.cameraPosition, isNull);

      // The platform settles on its default (center [0,0], zoom 0).
      const platformDefault = CameraPosition(target: LatLng(0, 0));
      platform.onCameraIdlePlatform.call(platformDefault);

      expect(controller.cameraPosition, isNotNull);
      expect(controller.cameraPosition!.target, const LatLng(0, 0));
      expect(controller.cameraPosition!.zoom, 0);

      controller.dispose();
    });

    test(
        'null camera with style camera — '
        'platform reports style position on idle', () {
      // initialCameraPosition is null; style has center/zoom.
      // The platform should use the style camera and report it back.
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, isNull);

      // Simulate the platform applying the style's camera.
      const styleCamera = CameraPosition(
        target: LatLng(17.654, 32.954),
        zoom: 0.86,
      );
      platform.onCameraIdlePlatform.call(styleCamera);

      expect(controller.cameraPosition, isNotNull);
      expect(
        controller.cameraPosition!.target.latitude,
        closeTo(17.654, 1e-6),
      );
      expect(
        controller.cameraPosition!.target.longitude,
        closeTo(32.954, 1e-6),
      );
      expect(controller.cameraPosition!.zoom, closeTo(0.86, 1e-6));

      controller.dispose();
    });
  });
}
