part of '../maplibre_gl_web.dart';

/// Resolves a [CameraAnimationInterpolation] to a JS easing callback usable
/// as the `easing` option of `map.easeTo`. Returns `null` when [interpolation]
/// is `null`, letting MapLibre GL JS apply its built-in default curve.
///
/// The resulting callback is a WASM-compatible [JSFunction] produced via
/// `Function.toJS` on a `double Function(double)` closure.
JSFunction? resolveEasing(CameraAnimationInterpolation? interpolation) {
  if (interpolation == null) return null;
  final impl = easingImplFor(interpolation);
  return ((double t) => impl(t)).toJS;
}
