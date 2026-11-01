// A finger for the integration tests that touch the map through the Android
// platform view.
import 'dart:developer' show Timeline;

import 'package:flutter_test/flutter_test.dart';

/// One finger whose events carry real timestamps.
///
/// Android's gesture detectors time long presses from the event's down time;
/// the zero timestamps a plain `TestGesture` sends would make every touch a
/// long press. Timeline.now reads the monotonic clock the MotionEvents use.
class Finger {
  Finger(this.tester);

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
