import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';

/// Dispatches synthetic pointer streams through [GestureBinding], following
/// the same framework path real touches take after the OS-to-engine hop:
/// hit test, gesture arena, and (for the stable engine) the platform-view
/// touch forwarding. Positions are logical pixels in the global coordinate
/// space, like [PointerEvent.position].
class GestureDriver {
  GestureDriver({this.sampleInterval = const Duration(milliseconds: 8)});

  /// Cadence of synthetic move events; 8 ms approximates the 120 Hz touch
  /// sampling of recent devices and is identical across engine variants.
  final Duration sampleInterval;

  final Stopwatch _clock = Stopwatch()..start();
  int _nextPointer = 4200;

  Duration get _now => _clock.elapsed;

  void _dispatch(PointerEvent event) =>
      GestureBinding.instance.handlePointerEvent(event);

  /// Linear single-finger drag from [from] to [to]. A short [duration] over
  /// a long distance ends with high pointer velocity, which the map's
  /// gesture handling turns into a fling.
  Future<void> drag({
    required Offset from,
    required Offset to,
    required Duration duration,
  }) async {
    final pointer = _nextPointer++;
    _dispatch(
      PointerDownEvent(pointer: pointer, position: from, timeStamp: _now),
    );
    final steps = math.max(
      1,
      duration.inMicroseconds ~/ sampleInterval.inMicroseconds,
    );
    var position = from;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(sampleInterval);
      final next = Offset.lerp(from, to, i / steps)!;
      _dispatch(
        PointerMoveEvent(
          pointer: pointer,
          position: next,
          delta: next - position,
          timeStamp: _now,
        ),
      );
      position = next;
    }
    _dispatch(
      PointerUpEvent(pointer: pointer, position: position, timeStamp: _now),
    );
  }

  /// Two-finger gesture around [center]: finger distance goes from
  /// 2x[fromRadius] to 2x[toRadius] (pinch) while both fingers rotate by
  /// [turnRadians] (twist). Combine or zero the two for pure pinch/rotate.
  Future<void> twoFinger({
    required Offset center,
    required double fromRadius,
    required double toRadius,
    double turnRadians = 0,
    double startAngle = 0,
    required Duration duration,
  }) async {
    final first = _nextPointer++;
    final second = _nextPointer++;
    Offset at(double angle, double radius, bool opposite) =>
        center + Offset.fromDirection(angle + (opposite ? math.pi : 0), radius);

    var angle = startAngle;
    var radius = fromRadius;
    var p1 = at(angle, radius, false);
    var p2 = at(angle, radius, true);
    _dispatch(PointerDownEvent(pointer: first, position: p1, timeStamp: _now));
    _dispatch(
      PointerDownEvent(pointer: second, position: p2, timeStamp: _now),
    );
    final steps = math.max(
      1,
      duration.inMicroseconds ~/ sampleInterval.inMicroseconds,
    );
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(sampleInterval);
      final t = i / steps;
      angle = startAngle + turnRadians * t;
      radius = lerpDouble(fromRadius, toRadius, t)!;
      final n1 = at(angle, radius, false);
      final n2 = at(angle, radius, true);
      _dispatch(
        PointerMoveEvent(
          pointer: first,
          position: n1,
          delta: n1 - p1,
          timeStamp: _now,
        ),
      );
      _dispatch(
        PointerMoveEvent(
          pointer: second,
          position: n2,
          delta: n2 - p2,
          timeStamp: _now,
        ),
      );
      p1 = n1;
      p2 = n2;
    }
    _dispatch(PointerUpEvent(pointer: first, position: p1, timeStamp: _now));
    _dispatch(PointerUpEvent(pointer: second, position: p2, timeStamp: _now));
  }
}
