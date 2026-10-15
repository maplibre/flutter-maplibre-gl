// Integration test for MapLibreMap.panInertia.
//
// Each platform maps the level onto its own SDK setting (UiSettings fling
// options on Android, decelerationRate on iOS, dragPan options on web), which
// a unit test with a mocked channel never reaches. The glide itself cannot be
// measured reliably from a test, so these tests check what can be: every
// level is accepted at creation and as an update, on every platform, and the
// map keeps working afterwards. On Android, where synthesized touches reach
// the map, a drag still pans it at every level.
import 'dart:developer' show Timeline;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _camera = CameraPosition(target: LatLng(0, 0), zoom: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('panInertia', () {
    for (final inertia in PanInertia.values) {
      testWidgets('the map is created with $inertia', (tester) async {
        final controller = await pumpMap(
          tester,
          builder:
              (onMapCreated, onStyleLoaded) =>
                  _map(onMapCreated, onStyleLoaded, inertia),
        );

        final region = await pumpUntil(
          tester,
          controller.getVisibleRegion(),
          'getVisibleRegion',
        );
        expect(region.northeast.longitude, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every level is applied as an update', (tester) async {
      late MapCreatedCallback created;
      late OnStyleLoadedCallback styleLoaded;
      final controller = await pumpMap(
        tester,
        builder: (onMapCreated, onStyleLoaded) {
          created = onMapCreated;
          styleLoaded = onStyleLoaded;
          return _map(onMapCreated, onStyleLoaded, PanInertia.normal);
        },
      );

      for (final inertia in [
        PanInertia.none,
        PanInertia.short,
        PanInertia.normal,
        PanInertia.none,
      ]) {
        await _update(
          tester,
          controller,
          _map(created, styleLoaded, inertia),
          '$inertia',
        );
      }
      // Turning scroll gestures off and on again resends the inertia with
      // them, which is how web applies it.
      await _update(
        tester,
        controller,
        _map(created, styleLoaded, PanInertia.none, scroll: false),
        'scroll off',
      );
      await _update(
        tester,
        controller,
        _map(created, styleLoaded, PanInertia.short),
        'scroll on',
      );

      await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion',
      );
      expect(tester.takeException(), isNull);
    });

    for (final inertia in PanInertia.values) {
      testWidgets('a drag still pans the map with $inertia', (tester) async {
        // Synthesized touches only reach the map view on Android.
        if (testPlatform != TestPlatform.android) return;
        final controller = await pumpMap(
          tester,
          builder:
              (onMapCreated, onStyleLoaded) =>
                  _map(onMapCreated, onStyleLoaded, inertia),
        );
        final before = await pumpUntil(
          tester,
          controller.getVisibleRegion(),
          'getVisibleRegion before',
        );

        final center = tester.getCenter(find.byType(MapLibreMap));
        final gesture = await tester.createGesture();
        await gesture.down(center, timeStamp: _now);
        await tester.pump(const Duration(milliseconds: 16));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(-8, 0), timeStamp: _now);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up(timeStamp: _now);
        await pumpFor(tester, const Duration(seconds: 1));

        final after = await pumpUntil(
          tester,
          controller.getVisibleRegion(),
          'getVisibleRegion after',
        );
        // Dragging to the left moves the view east.
        expect(
          after.northeast.longitude,
          greaterThan(before.northeast.longitude),
        );
      });
    }
  });
}

/// The monotonic clock Android's MotionEvents use; zero timestamps would make
/// every touch a long press.
Duration get _now => Duration(microseconds: Timeline.now);

MapLibreMap _map(
  MapCreatedCallback onMapCreated,
  OnStyleLoadedCallback onStyleLoaded,
  PanInertia inertia, {
  bool scroll = true,
}) => MapLibreMap(
  styleString: offlineStyle,
  initialCameraPosition: _camera,
  panInertia: inertia,
  scrollGesturesEnabled: scroll,
  onMapCreated: onMapCreated,
  onStyleLoadedCallback: onStyleLoaded,
);

/// Rebuilds the map with [map], in the same tree [pumpMap] built, and waits
/// for the option update to come back from the platform: the controller
/// notifies its listeners once the platform has answered.
Future<void> _update(
  WidgetTester tester,
  MapLibreMapController controller,
  MapLibreMap map,
  String label,
) async {
  var notified = false;
  void listener() => notified = true;
  controller.addListener(listener);
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, height: 300, child: map),
          ),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!notified) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for the $label update');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  } finally {
    controller.removeListener(listener);
  }
  expect(tester.takeException(), isNull, reason: label);
}
