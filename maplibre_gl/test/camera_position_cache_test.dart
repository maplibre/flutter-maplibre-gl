import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

/// iOS derives the zoom from the map view's size, so a camera event arriving
/// before the view has been laid out can carry a non-finite zoom. The controller
/// used to cache whatever it was handed, which left `cameraPosition` poisoned
/// until the next camera event, and on an untouched map that event never comes
/// (#903).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;
  late MapLibreMapController controller;

  const good = CameraPosition(target: LatLng(48.85, 2.35), zoom: 12);

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

  group('isFiniteCameraPosition', () {
    test('accepts an ordinary camera', () {
      expect(MapLibreMapController.isFiniteCameraPosition(good), isTrue);
    });

    test('rejects null', () {
      expect(MapLibreMapController.isFiniteCameraPosition(null), isFalse);
    });

    test('rejects a NaN zoom', () {
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(0, 0), zoom: double.nan),
        ),
        isFalse,
      );
    });

    test('rejects an infinite zoom', () {
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(0, 0), zoom: double.infinity),
        ),
        isFalse,
      );
    });

    test('rejects a non-finite bearing or tilt', () {
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(0, 0), bearing: double.nan),
        ),
        isFalse,
      );
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(0, 0), tilt: double.nan),
        ),
        isFalse,
      );
    });

    test('rejects a non-finite target', () {
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(double.nan, 2.35)),
        ),
        isFalse,
      );
      expect(
        MapLibreMapController.isFiniteCameraPosition(
          const CameraPosition(target: LatLng(48.85, double.nan)),
        ),
        isFalse,
      );
    });
  });

  group('cameraPosition cache', () {
    test('a camera move updates the cache and notifies', () {
      platform.onCameraMovePlatform(good);

      expect(controller.cameraPosition, good);
    });

    test('a non-finite camera move does not reach the cache', () {
      platform.onCameraMovePlatform(good);
      platform.onCameraMovePlatform(
        const CameraPosition(target: LatLng(0, 0), zoom: double.nan),
      );

      expect(
        controller.cameraPosition,
        good,
        reason: 'the last good reading must survive a poisoned event',
      );
    });

    test('a non-finite camera move is not forwarded to onCameraMove', () {
      final seen = <CameraPosition>[];
      final observed = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onCameraMove: seen.add,
      );
      addTearDown(observed.dispose);

      platform.onCameraMovePlatform(
        const CameraPosition(target: LatLng(0, 0), zoom: double.nan),
      );
      platform.onCameraMovePlatform(good);

      expect(seen, [good]);
    });

    test('a non-finite camera idle does not reach the cache', () {
      platform.onCameraMovePlatform(good);
      platform.onCameraIdlePlatform(
        const CameraPosition(target: LatLng(0, 0), zoom: double.nan),
      );

      expect(controller.cameraPosition, good);
    });

    test('a non-finite camera idle still ends the movement', () {
      platform.onCameraMoveStartedPlatform(null);
      expect(controller.isCameraMoving, isTrue);

      platform.onCameraIdlePlatform(
        const CameraPosition(target: LatLng(0, 0), zoom: double.nan),
      );

      expect(
        controller.isCameraMoving,
        isFalse,
        reason: 'a bad position must not leave the map stuck as moving',
      );
    });
  });
}
