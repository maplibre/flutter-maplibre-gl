/// Camera moves, gestures and constraints.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

/// Instant camera move; null [CameraSpec] fields stay unchanged.
class JumpToCommand extends SessionCommand {
  const JumpToCommand(
    super.sessionId,
    this.camera, {
    this.anchorX,
    this.anchorY,
  });

  final CameraSpec camera;
  final double? anchorX;
  final double? anchorY;
}

/// Animated camera move. [easing] is a cubic bezier as [x1, y1, x2, y2].
class EaseToCommand extends SessionCommand {
  const EaseToCommand(
    super.sessionId,
    this.camera, {
    required this.durationMs,
    this.easing,
  });

  final CameraSpec camera;
  final double durationMs;
  final List<double>? easing;
}

/// Pans by a screen-space delta in logical pixels.
class MoveByCommand extends SessionCommand {
  const MoveByCommand(super.sessionId, this.dx, this.dy, {this.durationMs});

  final double dx;
  final double dy;
  final double? durationMs;
}

/// Multiplies the map scale around an optional screen-space anchor.
class ScaleByCommand extends SessionCommand {
  const ScaleByCommand(
    super.sessionId,
    this.factor, {
    this.anchorX,
    this.anchorY,
    this.durationMs,
  });

  final double factor;
  final double? anchorX;
  final double? anchorY;
  final double? durationMs;
}

/// Rotates by a bearing delta in degrees around a screen-space anchor.
/// The engine reads the current bearing, so gesture streams never need a
/// camera round-trip.
class RotateByCommand extends SessionCommand {
  const RotateByCommand(
    super.sessionId,
    this.deltaDegrees, {
    required this.anchorX,
    required this.anchorY,
  });

  final double deltaDegrees;
  final double anchorX;
  final double anchorY;
}

/// Changes the pitch by a delta in degrees, clamped to [minPitch, maxPitch].
class PitchByCommand extends SessionCommand {
  const PitchByCommand(
    super.sessionId,
    this.deltaDegrees, {
    this.minPitch = 0,
    this.maxPitch = 60,
  });

  final double deltaDegrees;
  final double minPitch;
  final double maxPitch;
}

/// Moves the camera so the given bounds fit the viewport with padding.
class FitBoundsCommand extends SessionCommand {
  const FitBoundsCommand(
    super.sessionId,
    this.bounds, {
    required this.paddingLeft,
    required this.paddingTop,
    required this.paddingRight,
    required this.paddingBottom,
    this.durationMs,
    this.easing,
  });

  final BoundsSpec bounds;
  final double paddingLeft;
  final double paddingTop;
  final double paddingRight;
  final double paddingBottom;
  final double? durationMs;
  final List<double>? easing;
}

/// Cancels any in-flight camera transition (gesture start).
class CancelTransitionsCommand extends SessionCommand {
  const CancelTransitionsCommand(super.sessionId);
}

/// Brackets a live touch gesture (platform SDK parity: set on touch down,
/// cleared on touch up) so the core treats the camera writes as one gesture.
class SetGestureInProgressCommand extends SessionCommand {
  const SetGestureInProgressCommand(
    super.sessionId, {
    required this.inProgress,
  });

  final bool inProgress;
}

/// Constrains the camera. Null fields are left unchanged; see
/// [BoundsConstraintSpec] for how to remove a bounds constraint.
class SetBoundsCommand extends SessionCommand {
  const SetBoundsCommand(
    super.sessionId, {
    this.bounds,
    this.minZoom,
    this.maxZoom,
    this.minPitch,
    this.maxPitch,
  });

  final BoundsConstraintSpec? bounds;
  final double? minZoom;
  final double? maxZoom;
  final double? minPitch;
  final double? maxPitch;
}

/// Sets the camera viewport padding (content insets) in logical pixels.
class SetPaddingCommand extends SessionCommand {
  const SetPaddingCommand(
    super.sessionId, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.durationMs,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? durationMs;
}
