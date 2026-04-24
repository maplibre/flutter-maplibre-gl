import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

/// Pure-Dart easing math used to back web's [easeCamera] `easing` callback.
///
/// Kept free of `dart:js_interop` so it can be unit-tested from the Dart VM.

/// Returns the easing implementation for the given [interpolation].
double Function(double) easingImplFor(
  CameraAnimationInterpolation interpolation,
) {
  switch (interpolation) {
    case CameraAnimationInterpolation.linear:
      return (t) => t;
    case CameraAnimationInterpolation.easeInOut:
      return (t) => cubicBezier(t, 0.42, 0, 0.58, 1);
    case CameraAnimationInterpolation.easeOut:
      return (t) => cubicBezier(t, 0, 0, 0.58, 1);
    case CameraAnimationInterpolation.fastOutLinearIn:
      return (t) => cubicBezier(t, 0.4, 0, 1, 1);
  }
}

/// CSS-style cubic bezier with fixed endpoints (0,0) and (1,1) and control
/// points (x1,y1) and (x2,y2). Solves X(t)=u via up to 8 Newton iterations
/// (falling back to the current t when the derivative vanishes), then
/// returns Y(t).
double cubicBezier(double u, double x1, double y1, double x2, double y2) {
  if (u <= 0) return 0;
  if (u >= 1) return 1;
  var t = u;
  for (var i = 0; i < 8; i++) {
    final dx = _bezier(t, x1, x2) - u;
    if (dx.abs() < 1e-6) break;
    final d = _bezierDeriv(t, x1, x2);
    if (d.abs() < 1e-6) break;
    t = (t - dx / d).clamp(0.0, 1.0);
  }
  return _bezier(t, y1, y2);
}

double _bezier(double t, double a, double b) {
  final c = 3 * a;
  final d = 3 * (b - a) - c;
  final e = 1 - c - d;
  return ((e * t + d) * t + c) * t;
}

double _bezierDeriv(double t, double a, double b) {
  final c = 3 * a;
  final d = 3 * (b - a) - c;
  final e = 1 - c - d;
  return (3 * e * t + 2 * d) * t + c;
}
