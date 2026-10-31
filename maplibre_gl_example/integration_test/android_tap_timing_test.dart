// Integration test for when Android reports a tap.
//
// MapLibre Android confirms a single tap only after the double-tap timeout,
// about 300 ms. While double-tap zoom is off, MapLibreMapController.java
// reports the tap itself when the finger lifts instead, as iOS does, and
// ignores MapLibre's late confirmation. The tap recognition sits between the
// MotionEvents the view receives and the map's own gesture detector, so no
// unit test can see it; the gestures below go through Flutter's platform view,
// which hands the view the same MotionEvents a finger would.
//
// Run on an Android device or emulator:
//   flutter test integration_test/android_tap_timing_test.dart -d <device>
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

/// Well inside the double-tap timeout (300 ms on Android), with room for the
/// platform view to deliver the event.
const _beforeDoubleTapTimeout = Duration(milliseconds: 120);

bool get _onAndroid => testPlatform == TestPlatform.android;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'with double-tap zoom off, a tap on a feature is reported when the finger lifts',
    (tester) async {
      if (!_onAndroid) return;
      final map = await _pumpMapWithCircle(
        tester,
        doubleClickZoomEnabled: false,
      );

      final finger = _Finger(tester);
      await finger.down(map.circleCentre);
      await finger.up();
      await pumpFor(tester, _beforeDoubleTapTimeout);

      expect(map.featureTaps, [
        map.circleId,
      ], reason: 'reported before the double-tap timeout');

      // MapLibre's own confirmation of the same tap arrives later and must
      // not report it a second time.
      await _settle(tester);
      expect(map.featureTaps, [map.circleId]);
      expect(map.clicks, isEmpty, reason: 'a feature tap is not a map click');
    },
  );

  testWidgets('with double-tap zoom off, a tap on the map is one click', (
    tester,
  ) async {
    if (!_onAndroid) return;
    final map = await _pumpMapWithCircle(tester, doubleClickZoomEnabled: false);

    final finger = _Finger(tester);
    // Away from the circle: 100 px at zoom 10 is far outside its 30 px radius.
    await finger.down(map.circleCentre + const Offset(100, 100));
    await finger.up();
    await pumpFor(tester, _beforeDoubleTapTimeout);

    expect(
      map.clicks,
      hasLength(1),
      reason: 'reported before the double-tap timeout',
    );
    expect(map.featureTaps, isEmpty);

    await _settle(tester);
    expect(
      map.clicks,
      hasLength(1),
      reason: 'not reported again by the late confirmation',
    );
  });

  testWidgets(
    'with double-tap zoom on, a tap waits for the double-tap timeout, and is reported once',
    (
      tester,
    ) async {
      if (!_onAndroid) return;
      final map = await _pumpMapWithCircle(
        tester,
        doubleClickZoomEnabled: true,
      );

      final finger = _Finger(tester);
      await finger.down(map.circleCentre);
      await finger.up();
      await pumpFor(tester, _beforeDoubleTapTimeout);

      // A second tap could still be coming, so the map has not reported yet.
      expect(map.featureTaps, isEmpty);

      await _settle(tester);
      expect(map.featureTaps, [map.circleId]);
      expect(map.clicks, isEmpty);
    },
  );
}

/// Lets the platform view and the double-tap timeout run out.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 700));

/// One finger whose events carry real timestamps. Android times long presses
/// from the event's down time; `TestGesture`'s default zero timestamps make
/// every touch a long press. Timeline.now reads the same clock as MotionEvents.
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

  Future<void> up() async {
    await _gesture.up(timeStamp: _now);
  }
}

class _MapProbe {
  final featureTaps = <String>[];
  final clicks = <LatLng>[];
  late MapLibreMapController controller;
  late String circleId;

  /// Where to put the finger to hit the circle: the middle of the map widget,
  /// since the camera is centred on the circle.
  late Offset circleCentre;
}

Future<_MapProbe> _pumpMapWithCircle(
  WidgetTester tester, {
  required bool doubleClickZoomEnabled,
}) async {
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
              doubleClickZoomEnabled: doubleClickZoomEnabled,
              onMapClick: (_, latLng) => probe.clicks.add(latLng),
            ),
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
      ),
    ),
    'addCircle',
  );
  probe.circleId = circle.id;

  // The feature query behind a tap only sees what is drawn.
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

  probe.circleCentre = tester.getCenter(find.byType(MapLibreMap));
  return probe;
}
