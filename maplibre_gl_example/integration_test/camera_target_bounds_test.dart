// Integration tests for cameraTargetBounds (#793).
//
// The bounds constrain the camera target, the center of the map view, on
// every platform: for gestures and for camera calls, a target outside the
// bounds is brought to the nearest point inside, the map never zooms in to
// fit the bounds, and it can show the area around them.
//
// Covered: the zoom an initial camera inside the bounds keeps, moveCamera and
// animateCamera to a target outside the bounds, zoom, bearing and tilt left
// alone by the clamp, an initial camera outside the bounds, and changing the
// bounds from the widget, including removing them with
// CameraTargetBounds.unbounded.
//
// Run on Android or iOS:
//   flutter test integration_test/camera_target_bounds_test.dart -d <device id>
// Run on web (chromedriver on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/camera_target_bounds_test.dart -d chrome
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

/// Size of the map box the harness pumps, in logical pixels.
const double _mapSize = 300;

/// Tolerance for a target that is clamped, in degrees.
const double _tolerance = 0.05;

/// The contiguous USA. A portrait phone cannot show all of it, which is what
/// made iOS and web zoom in when the bounds limited the visible area.
final LatLngBounds _usa = LatLngBounds(
  southwest: const LatLng(24.396308, -124.848974),
  northeast: const LatLng(49.384358, -66.885444),
);

/// Western Europe, disjoint from [_usa].
final LatLngBounds _europe = LatLngBounds(
  southwest: const LatLng(36, -10),
  northeast: const LatLng(60, 30),
);

/// A point inside [_usa].
const LatLng _insideUsa = LatLng(39, -98);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('cameraTargetBounds', () {
    testWidgets('does not zoom the map in to fit the bounds', (tester) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: _insideUsa, zoom: 2),
      );

      // The bounds bound the target only, so the map can show more than the
      // bounds. iOS and web used to raise the zoom until the visible area fit.
      await pumpFor(tester, const Duration(milliseconds: 500));
      var camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(2, 0.05), reason: 'initial zoom');
      _expectLatLng(camera.target, _insideUsa, _tolerance, 'initial target');

      // There is no minimum zoom either.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.zoomTo(1)),
        'moveCamera zoomTo 1',
      );
      camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(1, 0.05), reason: 'zoomed out');
      expect(_within(camera.target, _usa, _tolerance), isTrue);
    });

    testWidgets('moveCamera to a target outside stops at the nearest point', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: _insideUsa, zoom: 2),
      );

      // Outside on both axes: the corner nearest to it.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(60, -30))),
        'moveCamera outside on both axes',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(49.384358, -66.885444),
        'north east corner',
      );

      // Outside on the longitude only: the latitude stays as requested.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(30, -150))),
        'moveCamera outside on the longitude',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(30, -124.848974),
        'west edge',
      );

      // Outside on the latitude only: the longitude stays as requested.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(10, -100))),
        'moveCamera outside on the latitude',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(24.396308, -100),
        'south edge',
      );

      // A target inside is reached as requested.
      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(35, -90))),
        'moveCamera inside',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(35, -90),
        'inside target',
      );
    });

    testWidgets(
      'animateCamera to a target outside stops at the nearest point',
      (
        tester,
      ) async {
        final controller = await _pumpBoundedMap(
          tester,
          bounds: _usa,
          camera: const CameraPosition(target: _insideUsa, zoom: 2),
        );

        await pumpUntil(
          tester,
          controller.animateCamera(
            CameraUpdate.newLatLng(const LatLng(60, -30)),
            duration: const Duration(milliseconds: 300),
          ),
          'animateCamera outside the bounds',
        );
        await _expectTargetNear(
          tester,
          controller,
          const LatLng(49.384358, -66.885444),
          'north east corner',
        );

        final camera = await _queryCamera(tester, controller);
        expect(
          camera.zoom,
          closeTo(2, 0.05),
          reason: 'zoom after the animation',
        );
      },
    );

    testWidgets('the clamp leaves zoom, bearing and tilt alone', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: _insideUsa, zoom: 2),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: LatLng(60, -30),
              zoom: 3,
              bearing: 40,
              tilt: 30,
            ),
          ),
        ),
        'moveCamera newCameraPosition outside the bounds',
      );

      final camera = await _expectTargetNear(
        tester,
        controller,
        const LatLng(49.384358, -66.885444),
        'north east corner',
      );
      expect(camera.zoom, closeTo(3, 0.05), reason: 'zoom');
      expect(camera.bearing, closeTo(40, 0.5), reason: 'bearing');
      expect(camera.tilt, closeTo(30, 0.5), reason: 'tilt');
    });

    testWidgets('an initial camera outside the bounds starts inside', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: LatLng(0, 0), zoom: 3),
      );

      await _expectTargetNear(
        tester,
        controller,
        const LatLng(24.396308, -66.885444),
        'initial target',
        tolerance: 0.1,
      );
      final camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(3, 0.05), reason: 'initial zoom');
    });

    testWidgets('new bounds from the widget move a target that is outside', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: _insideUsa, zoom: 3),
      );
      _expectLatLng(
        (await _queryCamera(tester, controller)).target,
        _insideUsa,
        _tolerance,
        'target inside the first bounds',
      );

      // The target is outside the new bounds, so it moves to the nearest
      // point inside them: Europe's west edge, at the same latitude.
      await _rebuildWithBounds(tester, CameraTargetBounds(_europe));
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(39, -10),
        'target moved inside the new bounds',
      );
      final camera = await _queryCamera(tester, controller);
      expect(camera.zoom, closeTo(3, 0.05), reason: 'zoom');
    });

    testWidgets('bounds set on a map that had none move the target inside', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: null,
        camera: const CameraPosition(target: LatLng(0, 0), zoom: 3),
      );

      await _rebuildWithBounds(tester, CameraTargetBounds(_usa));
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(24.396308, -66.885444),
        'target moved inside the bounds',
        tolerance: 0.1,
      );
    });

    testWidgets('CameraTargetBounds.unbounded removes the constraint', (
      tester,
    ) async {
      final controller = await _pumpBoundedMap(
        tester,
        bounds: _usa,
        camera: const CameraPosition(target: _insideUsa, zoom: 2),
      );

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(60, -30))),
        'moveCamera outside the bounds',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(49.384358, -66.885444),
        'clamped while bounded',
      );

      await _rebuildWithBounds(tester, CameraTargetBounds.unbounded);
      await pumpFor(tester, const Duration(milliseconds: 300));

      await pumpUntil(
        tester,
        controller.moveCamera(CameraUpdate.newLatLng(const LatLng(60, -30))),
        'moveCamera outside the removed bounds',
      );
      await _expectTargetNear(
        tester,
        controller,
        const LatLng(60, -30),
        'target after the bounds were removed',
      );
    });
  });
}

/// The widget tree [pumpMap] builds, so a later [tester.pumpWidget] with the
/// same shape updates the map instead of recreating it.
Widget _app(MapLibreMap map) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: _mapSize, height: _mapSize, child: map),
    ),
  ),
);

/// Pumps a map with [bounds] (none when null) and the initial [camera].
Future<MapLibreMapController> _pumpBoundedMap(
  WidgetTester tester, {
  required LatLngBounds? bounds,
  required CameraPosition camera,
}) {
  return pumpMap(
    tester,
    builder: (onMapCreated, onStyleLoaded) => MapLibreMap(
      styleString: offlineStyle,
      initialCameraPosition: camera,
      cameraTargetBounds: bounds == null
          ? CameraTargetBounds.unbounded
          : CameraTargetBounds(bounds),
      onMapCreated: onMapCreated,
      onStyleLoadedCallback: onStyleLoaded,
    ),
  );
}

/// Rebuilds the map [_pumpBoundedMap] pumped with other [bounds], as an app
/// does with setState.
Future<void> _rebuildWithBounds(
  WidgetTester tester,
  CameraTargetBounds bounds,
) async {
  await tester.pumpWidget(
    _app(
      MapLibreMap(
        styleString: offlineStyle,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        cameraTargetBounds: bounds,
      ),
    ),
  );
}

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

/// Waits until the camera target is within [tolerance] degrees of [expected]
/// on both axes, then returns that camera. A camera call can finish a frame
/// or two before the position it clamped to is readable, and a change of
/// bounds from the widget applies asynchronously.
Future<CameraPosition> _expectTargetNear(
  WidgetTester tester,
  MapLibreMapController controller,
  LatLng expected,
  String label, {
  double tolerance = _tolerance,
}) async {
  final camera = await pumpUntilValue(
    tester,
    () => _queryCamera(tester, controller),
    (camera) =>
        (camera.target.latitude - expected.latitude).abs() <= tolerance &&
        (camera.target.longitude - expected.longitude).abs() <= tolerance,
    '$label near $expected',
  );
  _expectLatLng(camera.target, expected, tolerance, label);
  return camera;
}

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
