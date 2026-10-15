// Integration tests for the camera and the screen projection.
//
// Covered: moveCamera with every CameraUpdate kind, the values moveCamera,
// animateCamera and easeCamera complete with, animated moves landing on their
// target, getVisibleRegion, toScreenLocation / toScreenLocationBatch /
// toLatLng, getMetersPerPixelAtLatitude, setCameraBounds, the
// minMaxZoomPreference and cameraTargetBounds widget options, the
// controller's cached cameraPosition and the onCameraMove / onCameraIdle
// callbacks.
//
// Each platform turns a CameraUpdate into its own SDK camera and does its own
// projection math (density conversion on Android, altitude-based zoom on iOS,
// maplibre-gl-js on web), so the only way to check they agree is to drive a
// real map and read the camera back.
//
// Run on Android or iOS:
//   flutter test integration_test/camera_test.dart -d <device id>
// Run on web (chromedriver on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/camera_test.dart -d chrome
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

/// Size of the map box the harness pumps, in logical pixels.
const double _mapSize = 300;

/// Equatorial circumference used by both native SDKs and maplibre-gl-js.
const double _earthCircumference = 40075016.686;

/// Logical pixels spanned by the whole world at [zoom]. All three platforms
/// use 512 px tiles.
double _worldSize(double zoom) => 512 * pow(2, zoom).toDouble();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('moveCamera', () {
    testWidgets('newLatLng moves the target and keeps zoom', (tester) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(10, 20))),
        'moveCamera newLatLng',
      );

      // moveCamera is instantaneous, so the change is visible as soon as the
      // call completes, without waiting for an idle event.
      final camera = await _queryCamera(tester, controller);
      _expectLatLng(camera.target, const LatLng(10, 20), 0.01, 'target');
      expect(camera.zoom, closeTo(3, 0.05));
    });

    testWidgets('newLatLngZoom moves the target and sets zoom', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.moveCamera(
          CameraUpdate.newLatLngZoom(const LatLng(-15, 30), 6),
        ),
        'moveCamera newLatLngZoom',
      );

      final camera = await _queryCamera(tester, controller);
      _expectLatLng(camera.target, const LatLng(-15, 30), 0.01, 'target');
      expect(camera.zoom, closeTo(6, 0.05));
    });

    testWidgets('newCameraPosition sets every component', (tester) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.moveCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: LatLng(10, 20),
              zoom: 5,
              bearing: 30,
              tilt: 20,
            ),
          ),
        ),
        'moveCamera newCameraPosition',
      );

      final camera = await _queryCamera(tester, controller);
      _expectLatLng(camera.target, const LatLng(10, 20), 0.01, 'target');
      expect(camera.zoom, closeTo(5, 0.05));
      expect(camera.bearing, closeTo(30, 0.5));
      expect(camera.tilt, closeTo(20, 0.5));
    });

    testWidgets('newLatLngBounds fits the bounds inside the padding', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      final bounds = LatLngBounds(
        southwest: const LatLng(-10, -10),
        northeast: const LatLng(10, 10),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLngBounds(bounds)),
        'moveCamera newLatLngBounds without padding',
      );
      final unpadded = await _queryCamera(tester, controller);
      _expectLatLng(unpadded.target, const LatLng(0, 0), 0.05, 'target');

      // 50 logical pixels on each side leaves 200 of the 300 for the bounds,
      // so the fitted zoom drops by log2(300 / 200).
      await pumpUntil(
        tester,
        controller.moveCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: 50,
            top: 50,
            right: 50,
            bottom: 50,
          ),
        ),
        'moveCamera newLatLngBounds with padding',
      );
      final padded = await _queryCamera(tester, controller);
      _expectLatLng(padded.target, const LatLng(0, 0), 0.05, 'target');
      expect(
        unpadded.zoom - padded.zoom,
        closeTo(log(_mapSize / (_mapSize - 100)) / ln2, 0.1),
        reason:
            'padding is in logical pixels '
            '(unpadded ${unpadded.zoom}, padded ${padded.zoom})',
      );

      final region = await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion',
      );
      expect(region.contains(bounds.southwest), isTrue, reason: '$region');
      expect(region.contains(bounds.northeast), isTrue, reason: '$region');
    });

    testWidgets('zoomTo, zoomIn, zoomOut and zoomBy change only the zoom', (
      tester,
    ) async {
      final controller = await pumpMap(
        tester,
        initialCameraPosition: const CameraPosition(
          target: LatLng(5, 5),
          zoom: 3,
        ),
      );

      Future<void> expectZoom(CameraUpdate update, double zoom) async {
        await pumpUntil(tester, controller.moveCamera(update), '$update');
        final camera = await _queryCamera(tester, controller);
        expect(camera.zoom, closeTo(zoom, 0.05), reason: '$update');
        _expectLatLng(camera.target, const LatLng(5, 5), 0.01, '$update');
      }

      await expectZoom(CameraUpdate.zoomTo(6), 6);
      await expectZoom(CameraUpdate.zoomIn(), 7);
      await expectZoom(CameraUpdate.zoomOut(), 6);
      await expectZoom(CameraUpdate.zoomBy(1.5), 7.5);
      await expectZoom(CameraUpdate.zoomBy(-2.5), 5);
    });

    testWidgets('zoomBy with a focus keeps the focus point in place', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      final scale = _screenScale(tester);
      const focus = Offset(300, 120);

      final anchor = await pumpUntil(
        tester,
        controller.toLatLng(Point(focus.dx * scale, focus.dy * scale)),
        'toLatLng focus',
      );
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomBy(1, focus)),
        'moveCamera zoomBy focus',
      );

      final camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(4, 0.05));
      // The documented contract: the geographic point under the focus stays
      // under it. Recentring on the focus would move it to the view center.
      final after = await pumpUntil(
        tester,
        controller.toScreenLocation(anchor),
        'toScreenLocation anchor',
      );
      expect(after.x / scale, closeTo(focus.dx, 3), reason: 'x of $after');
      expect(after.y / scale, closeTo(focus.dy, 3), reason: 'y of $after');
    });

    testWidgets('scrollBy pans by logical pixels', (tester) async {
      final controller = await pumpMap(tester);

      final result = await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.scrollBy(100, 0)),
        'moveCamera scrollBy',
      );

      final camera = await _queryCamera(tester, controller);
      // 100 logical pixels east at zoom 3, on the equator.
      final expectedLng = 100 / _worldSize(3) * 360;
      _expectLatLng(camera.target, LatLng(0, expectedLng), 0.3, 'target');
      expect(camera.zoom, closeTo(3, 0.05));

      // A scroll that moved the camera is a success like any other update.
      _expectMoveResult(result, 'scrollBy');
    });

    testWidgets('bearingTo and tiltTo rotate and pitch in place', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.bearingTo(45)),
        'moveCamera bearingTo',
      );
      var camera = await _queryCamera(tester, controller);
      expect(camera.bearing, closeTo(45, 0.5));
      expect(camera.zoom, closeTo(3, 0.05));
      _expectLatLng(camera.target, const LatLng(0, 0), 0.01, 'after bearing');

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.tiltTo(30)),
        'moveCamera tiltTo',
      );
      camera = await _queryCamera(tester, controller);
      expect(camera.tilt, closeTo(30, 0.5));
      // Tilting must not undo the earlier rotation.
      expect(camera.bearing, closeTo(45, 0.5));
      _expectLatLng(camera.target, const LatLng(0, 0), 0.01, 'after tilt');
    });

    testWidgets('reports success for each update kind', (tester) async {
      final controller = await pumpMap(tester);
      final updates = <String, CameraUpdate>{
        'newLatLng': CameraUpdate.newLatLng(const LatLng(1, 1)),
        'newLatLngZoom': CameraUpdate.newLatLngZoom(const LatLng(2, 2), 4),
        'newCameraPosition': CameraUpdate.newCameraPosition(
          const CameraPosition(target: LatLng(3, 3), zoom: 4),
        ),
        'newLatLngBounds': CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: const LatLng(-5, -5),
            northeast: const LatLng(5, 5),
          ),
          left: 10,
          top: 10,
          right: 10,
          bottom: 10,
        ),
        'zoomTo': CameraUpdate.zoomTo(5),
        'zoomIn': CameraUpdate.zoomIn(),
        'zoomOut': CameraUpdate.zoomOut(),
        'zoomBy': CameraUpdate.zoomBy(0.5),
        'bearingTo': CameraUpdate.bearingTo(10),
        'tiltTo': CameraUpdate.tiltTo(10),
      };
      for (final entry in updates.entries) {
        final result = await pumpUntil(
          tester,
          controller.moveCamera(entry.value),
          'moveCamera ${entry.key}',
        );
        _expectMoveResult(result, entry.key);
      }
    });
  });

  group('animated moves', () {
    testWidgets('animateCamera lands on the target', (tester) async {
      final controller = await pumpMap(tester);
      const target = CameraPosition(
        target: LatLng(20, -30),
        zoom: 5,
        bearing: 20,
        tilt: 15,
      );

      final result = await pumpUntil(
        tester,
        controller.animateCamera(
          CameraUpdate.newCameraPosition(target),
          duration: const Duration(milliseconds: 600),
        ),
        'animateCamera',
      );
      _expectMoveResult(result, 'animateCamera');

      // animateCamera only promises the animation has started, so poll.
      final camera = await pumpUntilValue(
        tester,
        () => _queryCamera(tester, controller),
        (camera) => _isNear(camera, target),
        'camera at animateCamera target',
      );
      expect(camera.bearing, closeTo(20, 0.5));
      expect(camera.tilt, closeTo(15, 0.5));
    });

    testWidgets('easeCamera completes once the camera is on target', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      const target = CameraPosition(target: LatLng(-20, 40), zoom: 6);

      final result = await pumpUntil(
        tester,
        controller.easeCamera(
          CameraUpdate.newCameraPosition(target),
          duration: const Duration(milliseconds: 600),
        ),
        'easeCamera',
      );
      expect(result, isTrue);

      // The documented contract is that true means the animation finished,
      // so the camera is already there when the future completes.
      final camera = await _queryCamera(tester, controller);
      _expectLatLng(camera.target, target.target, 0.05, 'eased target');
      expect(camera.zoom, closeTo(6, 0.05));
    });

    testWidgets('easeCamera with a zoom update lands on the zoom', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.easeCamera(
          CameraUpdate.zoomTo(7),
          duration: const Duration(milliseconds: 400),
          interpolation: CameraAnimationInterpolation.linear,
        ),
        'easeCamera zoomTo',
      );

      await pumpUntilValue(
        tester,
        () => _queryCamera(tester, controller),
        (camera) => (camera.zoom - 7).abs() < 0.05,
        'zoom 7 after easeCamera',
      );
    });
  });

  group('tracked camera and callbacks', () {
    testWidgets('cameraPosition follows moves with trackCameraPosition', (
      tester,
    ) async {
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 3,
              ),
              trackCameraPosition: true,
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
            ),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(
          CameraUpdate.newLatLngZoom(const LatLng(12, 34), 5),
        ),
        'moveCamera',
      );

      // The cached position arrives through the platform's camera events, so
      // it can lag the move by a frame or two.
      final cached = await pumpUntilValue(
        tester,
        () async => controller.cameraPosition,
        (camera) =>
            camera != null &&
            _isNear(
              camera,
              const CameraPosition(target: LatLng(12, 34), zoom: 5),
            ),
        'cached cameraPosition',
      );
      final queried = await _queryCamera(tester, controller);
      _expectLatLng(cached!.target, queried.target, 0.01, 'cached vs query');
      expect(cached.zoom, closeTo(queried.zoom, 0.05));

      await pumpUntilValue(
        tester,
        () async => controller.isCameraMoving,
        (moving) => !moving,
        'isCameraMoving false after the move',
      );
    });

    testWidgets('onCameraMove and onCameraIdle fire for an animation', (
      tester,
    ) async {
      final moves = <CameraPosition>[];
      var idles = 0;
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 3,
              ),
              trackCameraPosition: true,
              onCameraMove: moves.add,
              onCameraIdle: () => idles++,
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
            ),
      );

      // Let any startup camera events drain before counting.
      await pumpFor(tester, const Duration(milliseconds: 500));
      moves.clear();
      idles = 0;

      await pumpUntil(
        tester,
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(const LatLng(10, 10), 5),
          duration: const Duration(milliseconds: 800),
        ),
        'animateCamera',
      );
      await pumpUntilValue(
        tester,
        () async => idles,
        (count) => count > 0,
        'onCameraIdle',
      );

      expect(moves, isNotEmpty, reason: 'onCameraMove during the animation');
      // Every reported position is finite; the controller drops the rest.
      for (final position in moves) {
        expect(position.zoom.isFinite, isTrue, reason: '$position');
      }
      // The last idle leaves the camera on the target.
      await pumpUntilValue(
        tester,
        () => _queryCamera(tester, controller),
        (camera) => _isNear(
          camera,
          const CameraPosition(target: LatLng(10, 10), zoom: 5),
        ),
        'camera at target after idle',
      );
    });
  });

  group('projection', () {
    testWidgets('getVisibleRegion matches the camera and the map size', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      final region = await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion',
      );

      // The map's logical width at zoom 3 spans width / 4096 of the world. The region
      // is geographic, so pixel density does not enter here.
      final expectedSpan = _mapSize / _worldSize(3) * 360;
      final lngSpan = region.northeast.longitude - region.southwest.longitude;
      final latSpan = region.northeast.latitude - region.southwest.latitude;
      expect(lngSpan, closeTo(expectedSpan, expectedSpan * 0.1));
      // Near the equator Mercator barely stretches latitude.
      expect(latSpan, closeTo(expectedSpan, expectedSpan * 0.15));
      final center = LatLng(
        (region.northeast.latitude + region.southwest.latitude) / 2,
        (region.northeast.longitude + region.southwest.longitude) / 2,
      );
      _expectLatLng(center, const LatLng(0, 0), 0.5, 'region center');

      // One zoom level in halves the span.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomIn()),
        'moveCamera zoomIn',
      );
      final zoomed = await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion zoomed',
      );
      final zoomedSpan =
          zoomed.northeast.longitude - zoomed.southwest.longitude;
      expect(zoomedSpan, closeTo(lngSpan / 2, lngSpan * 0.05));
    });

    testWidgets('the camera target maps to the view center', (tester) async {
      final controller = await pumpMap(
        tester,
        initialCameraPosition: const CameraPosition(
          target: LatLng(15, 25),
          zoom: 4,
        ),
      );
      final scale = _screenScale(tester);

      final point = await pumpUntil(
        tester,
        controller.toScreenLocation(const LatLng(15, 25)),
        'toScreenLocation',
      );
      expect(point.x / scale, closeTo(_mapSize / 2, 2), reason: '$point');
      expect(point.y / scale, closeTo(_mapSize / 2, 2), reason: '$point');

      final center = await pumpUntil(
        tester,
        controller.toLatLng(
          Point(_mapSize / 2 * scale, _mapSize / 2 * scale),
        ),
        'toLatLng',
      );
      _expectLatLng(center, const LatLng(15, 25), 0.05, 'view center');
    });

    testWidgets('a point east of the center is right of the view center', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      final scale = _screenScale(tester);

      // 50 logical pixels at zoom 3 on the equator.
      final dLng = 50 / _worldSize(3) * 360;
      final point = await pumpUntil(
        tester,
        controller.toScreenLocation(LatLng(0, dLng)),
        'toScreenLocation',
      );
      expect(point.x / scale, closeTo(_mapSize / 2 + 50, 2), reason: '$point');
      expect(point.y / scale, closeTo(_mapSize / 2, 2), reason: '$point');
    });

    testWidgets('toScreenLocation and toLatLng round trip', (tester) async {
      final controller = await pumpMap(tester);
      const coordinates = [
        LatLng(0, 0),
        LatLng(5, 5),
        LatLng(-8, 12),
        LatLng(10, -15),
      ];

      for (final latLng in coordinates) {
        final point = await pumpUntil(
          tester,
          controller.toScreenLocation(latLng),
          'toScreenLocation $latLng',
        );
        final back = await pumpUntil(
          tester,
          controller.toLatLng(point),
          'toLatLng $point',
        );
        // Web rounds to whole pixels, about 0.09 degrees at zoom 3.
        _expectLatLng(back, latLng, 0.2, 'round trip of $latLng');
      }
    });

    testWidgets('toScreenLocationBatch agrees with toScreenLocation', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      const coordinates = [
        LatLng(0, 0),
        LatLng(5, 5),
        LatLng(-8, 12),
        LatLng(10, -15),
      ];

      final batch = await pumpUntil(
        tester,
        controller.toScreenLocationBatch(coordinates),
        'toScreenLocationBatch',
      );
      expect(batch, hasLength(coordinates.length));
      for (var i = 0; i < coordinates.length; i++) {
        final single = await pumpUntil(
          tester,
          controller.toScreenLocation(coordinates[i]),
          'toScreenLocation ${coordinates[i]}',
        );
        expect(batch[i].x, closeTo(single.x, 1), reason: '${coordinates[i]}');
        expect(batch[i].y, closeTo(single.y, 1), reason: '${coordinates[i]}');
      }
    });

    testWidgets('getMetersPerPixelAtLatitude follows web mercator', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      Future<double> metersPerPixel(double latitude) => pumpUntil(
        tester,
        controller.getMetersPerPixelAtLatitude(latitude),
        'getMetersPerPixelAtLatitude $latitude',
      );

      final equator = await metersPerPixel(0);
      // Per logical pixel on every platform, unlike toScreenLocation.
      final expected = _earthCircumference / _worldSize(3);
      expect(equator, closeTo(expected, expected * 0.02));

      // cos(60) = 0.5.
      final sixty = await metersPerPixel(60);
      expect(sixty, closeTo(equator / 2, equator * 0.02));

      // Two zoom levels in, a pixel covers a quarter of the ground.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomTo(5)),
        'moveCamera zoomTo',
      );
      final zoomed = await metersPerPixel(0);
      expect(zoomed, lessThan(equator));
      expect(zoomed, closeTo(equator / 4, equator * 0.01));
    });
  });

  group('camera limits', () {
    testWidgets('setCameraBounds fits the bounds', (tester) async {
      final controller = await pumpMap(
        tester,
        initialCameraPosition: const CameraPosition(
          target: LatLng(40, 60),
          zoom: 2,
        ),
      );

      // Like every other controller call, the future must complete.
      await pumpUntil(
        tester,
        controller.setCameraBounds(
          west: -10,
          north: 10,
          south: -10,
          east: 10,
          padding: 20,
        ),
        'setCameraBounds',
      );

      // The fit is animated on every platform, so poll for it.
      final camera = await pumpUntilValue(
        tester,
        () => _queryCamera(tester, controller),
        (camera) =>
            camera.target.latitude.abs() < 0.1 &&
            camera.target.longitude.abs() < 0.1,
        'camera centered on the bounds',
      );
      final region = await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion',
      );
      expect(
        region.contains(const LatLng(-10, -10)),
        isTrue,
        reason: '$region',
      );
      expect(region.contains(const LatLng(10, 10)), isTrue, reason: '$region');
      // Fitted, not merely contained: 20 degrees in the map minus 20 logical
      // pixels of padding on each side.
      final fitZoom = log((_mapSize - 40) * 360 / (20 * 512)) / ln2;
      expect(camera.zoom, closeTo(fitZoom, 0.4));
    });

    testWidgets('minMaxZoomPreference clamps camera moves', (tester) async {
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 3,
              ),
              minMaxZoomPreference: const MinMaxZoomPreference(2, 6),
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
            ),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomTo(10)),
        'moveCamera zoomTo 10',
      );
      var camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(6, 0.05), reason: 'clamped to max');

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomTo(0)),
        'moveCamera zoomTo 0',
      );
      camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(2, 0.05), reason: 'clamped to min');
    });

    testWidgets('cameraTargetBounds keeps the target inside the bounds', (
      tester,
    ) async {
      final bounds = LatLngBounds(
        southwest: const LatLng(-10, -10),
        northeast: const LatLng(10, 10),
      );
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0, 0),
                zoom: 5,
              ),
              cameraTargetBounds: CameraTargetBounds(bounds),
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
            ),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(40, 40))),
        'moveCamera outside the bounds',
      );

      // Android bounds the target, iOS and web bound the visible area (which
      // is stricter); either way the target ends up inside.
      final camera = await pumpUntilValue(
        tester,
        () => _queryCamera(tester, controller),
        (camera) => _within(camera.target, bounds, 0.1),
        'camera target inside the bounds',
      );
      // It did move toward the requested target rather than stay put.
      expect(
        camera.target.latitude,
        greaterThan(1),
        reason: '${camera.target}',
      );
      expect(
        camera.target.longitude,
        greaterThan(1),
        reason: '${camera.target}',
      );
    });
  });
}

/// Reads the live camera, failing if the platform has none.
Future<CameraPosition> _queryCamera(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final camera = await pumpUntil(
    tester,
    controller.queryCameraPosition(),
    'queryCameraPosition',
  );
  expect(camera, isNotNull, reason: 'queryCameraPosition');
  return camera!;
}

/// Device pixels per logical pixel in the coordinates toScreenLocation and
/// toLatLng use. Android answers in physical pixels straight from its
/// Projection, iOS in points and web in CSS pixels; the example app's custom
/// marker page compensates the same way, so this is existing behavior rather
/// than something these tests define.
double _screenScale(WidgetTester tester) =>
    testPlatform == TestPlatform.android ? tester.view.devicePixelRatio : 1.0;

/// moveCamera and animateCamera complete with true on success; on iOS they
/// are documented to always complete with null.
void _expectMoveResult(bool? result, String label) {
  if (testPlatform == TestPlatform.ios) {
    expect(result, isNull, reason: label);
  } else {
    expect(result, isTrue, reason: label);
  }
}

bool _isNear(CameraPosition camera, CameraPosition target) =>
    (camera.target.latitude - target.target.latitude).abs() < 0.05 &&
    (camera.target.longitude - target.target.longitude).abs() < 0.05 &&
    (camera.zoom - target.zoom).abs() < 0.05;

bool _within(LatLng point, LatLngBounds bounds, double tolerance) =>
    point.latitude >= bounds.southwest.latitude - tolerance &&
    point.latitude <= bounds.northeast.latitude + tolerance &&
    point.longitude >= bounds.southwest.longitude - tolerance &&
    point.longitude <= bounds.northeast.longitude + tolerance;

void _expectLatLng(
  LatLng actual,
  LatLng expected,
  double tolerance,
  String label,
) {
  expect(
    actual.latitude,
    closeTo(expected.latitude, tolerance),
    reason: '$label latitude ($actual)',
  );
  expect(
    actual.longitude,
    closeTo(expected.longitude, tolerance),
    reason: '$label longitude ($actual)',
  );
}
