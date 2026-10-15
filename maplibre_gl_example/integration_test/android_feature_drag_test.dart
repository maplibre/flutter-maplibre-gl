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
import 'dart:developer' show Timeline;
import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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

    final finger = _Finger(tester);
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

    final finger = _Finger(tester);
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
  });

  testWidgets('two fingers down on a feature pinch the map, no drag', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);
    final before = await pumpUntil(
      tester,
      map.controller.getVisibleRegion(),
      'getVisibleRegion before',
    );

    final first = _Finger(tester);
    await first.down(map.circleOnScreen);
    // Inside the 300x300 map: a finger on its edge never reaches the view,
    // and the first one would just go on dragging.
    final second = _Finger(tester);
    await second.down(map.circleOnScreen + const Offset(0, 80));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(0, -5));
      await second.moveBy(const Offset(0, 5));
    }
    await second.up();
    await first.up();
    await _settle(tester);

    expect(map.drags, isEmpty);
    expect(
      await pumpUntil(
        tester,
        map.controller.getVisibleRegion(),
        'getVisibleRegion after',
      ),
      isNot(before),
    );
  });

  testWidgets('a second finger ends the drag and the map pinches', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final first = _Finger(tester);
    await first.down(map.circleOnScreen);
    for (var i = 0; i < 5; i++) {
      await first.moveBy(const Offset(10, 0));
    }
    final before = await pumpUntil(
      tester,
      map.controller.getVisibleRegion(),
      'getVisibleRegion before',
    );
    // Inside the 300x300 map: a finger on its edge never reaches the view,
    // and the first one would just go on dragging.
    final second = _Finger(tester);
    await second.down(map.circleOnScreen + const Offset(0, 80));
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(0, -5));
      await second.moveBy(const Offset(0, 5));
    }
    await second.up();
    await first.up();
    await _settle(tester);

    // One end, where the single finger last dragged the feature to, and
    // nothing after it.
    final types = map.drags.map((d) => d.type).toList();
    expect(types.first, DragEventType.start);
    expect(types.where((t) => t == DragEventType.end), hasLength(1));
    expect(types.last, DragEventType.end);
    final end = map.drags.last;
    expect(end.delta, const LatLng(0, 0));
    expect(end.current, map.drags[map.drags.length - 2].current);
    // The rest of the gesture is the map's: the fingers spread, it zooms in.
    final after = await pumpUntil(
      tester,
      map.controller.getVisibleRegion(),
      'getVisibleRegion after',
    );
    expect(
      after.northeast.latitude - after.southwest.latitude,
      lessThan(before.northeast.latitude - before.southwest.latitude),
    );
  });

  testWidgets('a drag longer than a long press does not long-press the map', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final finger = _Finger(tester);
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

/// Lets the platform view answer over the method channel.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 500));

/// One finger whose events carry real timestamps.
///
/// Android's gesture detectors time long presses from the event's down time;
/// the zero timestamps a plain `TestGesture` sends would make every touch a
/// long press. Timeline.now reads the monotonic clock the MotionEvents use.
class _Finger {
  _Finger(this.tester);

  final WidgetTester tester;
  late TestGesture _gesture;

  Duration get _now => Duration(microseconds: Timeline.now);

  Future<void> down(Offset at) async {
    _gesture = await tester.createGesture();
    await _gesture.down(at, timeStamp: _now);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> moveBy(Offset by, {int after = 16}) async {
    await _gesture.moveBy(by, timeStamp: _now);
    await tester.pump(Duration(milliseconds: after));
  }

  Future<void> up() async {
    await _gesture.up(timeStamp: _now);
  }
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
