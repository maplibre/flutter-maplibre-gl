// Integration tests for the area around a touch where taps and drags look for
// a feature: 8 dp on Android, 8 pt on iOS, the feature nearest the finger
// winning.
//
// The lookup lives in MapLibreMapController.java, behind the MotionEvents the
// view receives; no unit test can see it. The gestures below go through
// Flutter's platform view, which hands the view the same MotionEvents a
// finger would.
//
// Run on an Android device or emulator:
//   flutter test integration_test/feature_hit_tolerance_test.dart -d <device>
//
// The assertions only run on Android. On iOS the map's gesture recognizers do
// not see the pointers Flutter synthesizes, so the same lookup there
// (MapLibreMapController.swift, firstFeatureOnLayers) is checked by hand. On
// web the tests are no-ops: GL JS mouse events hit the exact point.
import 'dart:developer' show Timeline;
import 'dart:math' show Point;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

/// Away from tile edges at zoom 10, so no circle is split across tiles.
const _center = LatLng(0.15, 0.15);

/// Small enough that a finger easily lands next to it.
const _radius = 3.0;

bool get _onAndroid => testPlatform == TestPlatform.android;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tap 5 dp off a small feature taps it', (tester) async {
    if (!_onAndroid) return;
    final map = await _pumpMap(tester);
    final circle = await map.addCircle(Offset.zero);

    await map.tap(const Offset(_radius + 5, 0));

    expect(map.featureTaps, [circle.id]);
  });

  testWidgets('a tap 11 dp off a small feature taps the map', (tester) async {
    if (!_onAndroid) return;
    final map = await _pumpMap(tester);
    await map.addCircle(Offset.zero);

    await map.tap(const Offset(_radius + 11, 0));

    expect(map.featureTaps, isEmpty);
    expect(map.clicks, hasLength(1));
  });

  testWidgets('of two features in reach, the nearest one is tapped', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMap(tester);
    final near = await map.addCircle(const Offset(_radius + 4, 0));
    // Added last, so drawn on top: a lookup that took the top-most feature in
    // reach would pick it.
    await map.addCircle(const Offset(-_radius - 6, 0));

    await map.tap(Offset.zero);

    expect(map.featureTaps, [near.id]);
  });

  testWidgets('a drag starting 5 dp off a small feature drags it', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMap(tester);
    final circle = await map.addCircle(Offset.zero, draggable: true);

    final finger = _Finger(tester);
    await finger.down(map.onScreen(const Offset(_radius + 5, 0)));
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(const Offset(4, 0));
    }
    await finger.up();
    await _settle(tester);

    expect(map.drags, isNotEmpty);
    expect(map.drags.first.type, DragEventType.start);
    expect(map.drags.last.type, DragEventType.end);
    expect(map.drags.map((d) => d.id).toSet(), {circle.id});
  });

  testWidgets('a closer feature that cannot be dragged does not hide one '
      'that can', (tester) async {
    if (!_onAndroid) return;
    final map = await _pumpMap(tester);
    final draggable = await map.addCircle(
      const Offset(-_radius - 6, 0),
      draggable: true,
    );
    await map.addCircle(const Offset(_radius + 3, 0));

    final finger = _Finger(tester);
    await finger.down(map.onScreen(Offset.zero));
    for (var i = 0; i < 10; i++) {
      await finger.moveBy(const Offset(0, 4));
    }
    await finger.up();
    await _settle(tester);

    expect(map.drags, isNotEmpty);
    expect(map.drags.map((d) => d.id).toSet(), {draggable.id});
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

  Future<void> moveBy(Offset by) async {
    await _gesture.moveBy(by, timeStamp: _now);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> up() async {
    await _gesture.up(timeStamp: _now);
  }
}

class _Drag {
  _Drag(this.type, this.id);

  final DragEventType type;
  final String id;
}

class _MapProbe {
  _MapProbe(this.tester);

  final WidgetTester tester;
  final drags = <_Drag>[];
  final featureTaps = <String>[];
  final clicks = <LatLng>[];
  late MapLibreMapController controller;

  /// Center of the map in global logical coordinates.
  late Offset center;

  Offset onScreen(Offset fromCenter) => center + fromCenter;

  /// Adds a circle of [_radius] centered [fromCenter] logical pixels from the
  /// center of the map, and waits until it is drawn: the lookup behind taps
  /// and drags only sees what is drawn.
  Future<Circle> addCircle(Offset fromCenter, {bool draggable = false}) async {
    final topLeft = tester.getTopLeft(find.byType(MapLibreMap));
    // toLatLng and queryRenderedFeatures use physical pixels on Android.
    final scale = _onAndroid ? tester.view.devicePixelRatio : 1.0;
    final local = onScreen(fromCenter) - topLeft;
    final latLng = await pumpUntil(
      tester,
      controller.toLatLng(Point(local.dx * scale, local.dy * scale)),
      'toLatLng',
    );
    final circle = await pumpUntil(
      tester,
      controller.addCircle(
        CircleOptions(
          geometry: latLng,
          circleRadius: _radius,
          circleColor: '#e53935',
          draggable: draggable,
        ),
      ),
      'addCircle',
    );
    final layerId = controller.circleManager!.layerIds.first;
    await pumpUntilValue(
      tester,
      () => controller.queryRenderedFeatures(
        Point(local.dx * scale, local.dy * scale),
        [layerId],
        null,
      ),
      (features) => features.cast<Map>().any(
        (f) => (f['properties'] as Map?)?['id'].toString() == circle.id,
      ),
      'circle rendered',
    );
    return circle;
  }

  Future<void> tap(Offset fromCenter) async {
    final finger = _Finger(tester);
    await finger.down(onScreen(fromCenter));
    await finger.up();
    await _settle(tester);
  }
}

Future<_MapProbe> _pumpMap(WidgetTester tester) async {
  final probe = _MapProbe(tester);

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
            ),
      );
  controller.onFeatureDrag.add(
    (point, origin, current, delta, id, annotation, eventType) =>
        probe.drags.add(_Drag(eventType, id)),
  );
  controller.onFeatureTapped.add(
    (point, latLng, id, layerId, annotation) => probe.featureTaps.add(id),
  );
  probe.center = tester.getCenter(find.byType(MapLibreMap));
  return probe;
}
