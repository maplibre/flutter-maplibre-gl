// Integration test for dragging a feature on Android.
//
// The drag lives in MapLibreMapController.java, between the MotionEvents the
// view receives and the gesture detectors of the map itself; no unit test can
// see it. The gestures below go through Flutter's platform view, which hands
// the view the same MotionEvents a finger would.
//
// Run on an Android device or emulator:
//   flutter test integration_test/android_feature_drag_test.dart -d <device>
//
// The assertions only run on Android; elsewhere the tests are no-ops so the
// suite stays green everywhere.
import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/finger.dart';
import 'support/map_harness.dart';

const _center = LatLng(0, 0);

bool get _onAndroid => testPlatform == TestPlatform.android;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tap that trembles by a pixel taps the feature, no drag', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final finger = Finger(tester);
    await finger.down(map.circleOnScreen);
    await finger.moveBy(const Offset(1, 0));
    await finger.up();
    await _settle(tester);

    expect(map.drags, isEmpty);
    expect(map.featureTaps, hasLength(1));
  });

  testWidgets('a drag past the touch slop drags the feature, not the map', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);
    final before = await pumpUntil(
      tester,
      map.controller.getVisibleRegion(),
      'getVisibleRegion before',
    );

    final finger = Finger(tester);
    await finger.down(map.circleOnScreen);
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(const Offset(2, 0));
    }
    await finger.up();
    await _settle(tester);

    expect(
      await pumpUntil(
        tester,
        map.controller.getVisibleRegion(),
        'getVisibleRegion after',
      ),
      before,
    );
    final types = map.drags.map((d) => d.type).toList();
    expect(types.first, DragEventType.start);
    expect(types, contains(DragEventType.drag));
    expect(types.last, DragEventType.end);
    expect(map.featureTaps, isEmpty);

    // As on iOS: the drag starts where the finger left the touch slop, with
    // no movement of its own. The drag events after it carry the movement.
    final start = map.drags.first;
    expect(start.delta, const LatLng(0, 0));
    expect(start.origin, start.current);
    final end = map.drags.last;
    expect(end.origin, start.origin);
    expect(end.current.longitude, greaterThan(start.current.longitude));

    // Each drag event replaced the circle in its source, so the source holds
    // the position the circle was dragged to. The query answers once per tile
    // holding the circle; the tolerance covers the tile quantization, well
    // below the distance dragged.
    final dragged = map.controller.circles.single.options.geometry!;
    expect(dragged.longitude, greaterThan(_center.longitude + 0.005));
    await pumpUntilValue(
      tester,
      () => map.controller.querySourceFeatures(
        map.controller.circleManager!.layerIds.single,
        null,
        null,
      ),
      (features) =>
          features.isNotEmpty &&
          features.cast<Map>().every((feature) {
            final coordinates =
                (feature['geometry'] as Map)['coordinates'] as List;
            return ((coordinates[0] as num) - dragged.longitude).abs() <
                    0.001 &&
                ((coordinates[1] as num) - dragged.latitude).abs() < 0.001;
          }),
      'dragged circle moved in the source to $dragged',
    );
  });

  testWidgets('two fingers down on a feature pinch the map, no drag', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final first = Finger(tester);
    await first.down(map.circleOnScreen);
    // Inside the 300x300 map: a finger on its edge never reaches the view.
    final second = Finger(tester);
    await second.down(map.circleOnScreen + const Offset(0, 80));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(0, -5));
      await second.moveBy(const Offset(0, 5));
    }
    await second.up();
    await _expectFingerPansTheMap(tester, map, first);

    expect(map.drags, isEmpty);
  });

  testWidgets('a second finger ends the drag and the map pinches', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final first = Finger(tester);
    await first.down(map.circleOnScreen);
    for (var i = 0; i < 5; i++) {
      await first.moveBy(const Offset(10, 0));
    }
    // Inside the 300x300 map: a finger on its edge never reaches the view,
    // and the first one would just go on dragging.
    final second = Finger(tester);
    await second.down(map.circleOnScreen + const Offset(0, 80));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(0, -5));
      await second.moveBy(const Offset(0, 5));
    }
    await second.up();
    await _expectFingerPansTheMap(tester, map, first);

    // One end, where the single finger last dragged the feature to, and
    // nothing after it, although the finger kept moving.
    final types = map.drags.map((d) => d.type).toList();
    expect(types.first, DragEventType.start);
    expect(types.where((t) => t == DragEventType.end), hasLength(1));
    expect(types.last, DragEventType.end);
    final end = map.drags.last;
    expect(end.delta, const LatLng(0, 0));
    expect(end.current, map.drags[map.drags.length - 2].current);
  });

  testWidgets('a drag longer than a long press does not long-press the map', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final finger = Finger(tester);
    await finger.down(map.circleOnScreen);
    // One second of slow dragging, well past the long-press timeout.
    for (var i = 0; i < 20; i++) {
      await finger.moveBy(const Offset(4, 0), after: 50);
    }
    await finger.up();
    await _settle(tester);

    expect(map.drags.last.type, DragEventType.end);
    expect(map.longClicks, isEmpty);
    expect(map.clicks, isEmpty);
  });
}

/// Lets the platform view answer.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 500));

/// Checks that the gesture [finger] is part of belongs to the map: once the
/// other finger has lifted, moving [finger] to the left pans the map east.
///
/// A pinch would be the natural check, but the two fingers of a test move in
/// turns, one event each, and MapLibre's scale detector rarely reads that as a
/// pinch: the zoom stays put or even goes the wrong way, whoever owns the
/// gesture. A one-finger pan is read the same way every time, so it is what
/// tells whether the map, and not the drag, has the gesture. Real pinches are
/// checked by hand.
Future<void> _expectFingerPansTheMap(
  WidgetTester tester,
  _MapProbe map,
  Finger finger,
) async {
  final before = await pumpUntil(
    tester,
    map.controller.getVisibleRegion(),
    'getVisibleRegion before the pan',
  );
  for (var i = 0; i < 8; i++) {
    await finger.moveBy(const Offset(-10, 0));
  }
  await finger.up();
  await _settle(tester);
  final after = await pumpUntil(
    tester,
    map.controller.getVisibleRegion(),
    'getVisibleRegion after the pan',
  );
  // Dragging to the left moves the view east.
  expect(
    after.northeast.longitude,
    greaterThan(before.northeast.longitude),
    reason: 'the remaining finger pans the map',
  );
}

class _Drag {
  _Drag(this.type, this.origin, this.current, this.delta);

  final DragEventType type;
  final LatLng origin;
  final LatLng current;
  final LatLng delta;
}

class _MapProbe {
  final drags = <_Drag>[];
  final featureTaps = <String>[];
  final clicks = <LatLng>[];
  final longClicks = <LatLng>[];
  late MapLibreMapController controller;
  late Offset circleOnScreen;
}

Future<_MapProbe> _pumpMapWithDraggableCircle(WidgetTester tester) async {
  final probe = _MapProbe();

  final controller =
      probe.controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: _center,
                zoom: 10,
              ),
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
              onMapClick: (_, latLng) => probe.clicks.add(latLng),
              onMapLongClick: (_, latLng) => probe.longClicks.add(latLng),
            ),
      );
  controller.onFeatureDrag.add(
    (point, origin, current, delta, id, annotation, eventType) =>
        probe.drags.add(_Drag(eventType, origin, current, delta)),
  );
  controller.onFeatureTapped.add(
    (point, latLng, id, layerId, annotation) => probe.featureTaps.add(id),
  );
  final circle = await pumpUntil(
    tester,
    controller.addCircle(
      const CircleOptions(
        geometry: _center,
        circleRadius: 30,
        circleColor: '#e53935',
        draggable: true,
      ),
    ),
    'addCircle',
  );

  // The feature query behind a drag only sees what is drawn.
  final screen = await pumpUntil(
    tester,
    controller.toScreenLocation(_center),
    'toScreenLocation',
  );
  final point = Point<double>(screen.x.toDouble(), screen.y.toDouble());
  final layerId = controller.circleManager!.layerIds.first;
  await pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [layerId], null),
    (features) => features.cast<Map>().any(
      (f) => (f['properties'] as Map?)?['id'].toString() == circle.id,
    ),
    'circle rendered',
  );

  probe.circleOnScreen = tester.getCenter(find.byType(MapLibreMap));
  return probe;
}
