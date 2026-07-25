import 'dart:math';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

import '../../protocol/protocol.dart';

/// Default camera animation duration, matching the Android SDK's
/// `MapLibreConstants.ANIMATION_DURATION`.
const defaultCameraAnimationDuration = Duration(milliseconds: 300);

/// Cubic bezier control points of the maplibre_gl easing curves, as
/// [x1, y1, x2, y2].
const _easingCurves = <CameraAnimationInterpolation, List<double>>{
  CameraAnimationInterpolation.linear: [0, 0, 1, 1],
  CameraAnimationInterpolation.easeInOut: [0.42, 0, 0.58, 1],
  CameraAnimationInterpolation.easeOut: [0, 0, 0.58, 1],
  CameraAnimationInterpolation.fastOutLinearIn: [0.4, 0, 1, 1],
};

/// The bezier for [interpolation], defaulting to ease-in-out like the
/// reference backends.
List<double>? easingCurve(CameraAnimationInterpolation? interpolation) =>
    _easingCurves[interpolation ?? CameraAnimationInterpolation.easeInOut];

/// Translates a maplibre_gl [CameraUpdate] into the engine command that
/// performs it.
///
/// `CameraUpdate` has no public accessors: its `toJson()` is a positional
/// list tagged with the update kind, so decoding that shape is all this does.
/// A null [durationMs] means an instant move.
EngineCommand cameraUpdateCommand(
  CameraUpdate update, {
  required int sessionId,
  required double? durationMs,
  required List<double>? easing,
}) {
  final json = update.toJson() as List<dynamic>;
  final kind = json[0] as String;

  EngineCommand goTo(CameraSpec camera) => durationMs == null
      ? JumpToCommand(sessionId, camera)
      : EaseToCommand(
          sessionId,
          camera,
          durationMs: durationMs,
          easing: easing,
        );

  switch (kind) {
    case 'newCameraPosition':
      final position = json[1] as Map;
      final target = position['target'] as List;
      return goTo(
        CameraSpec(
          latitude: (target[0] as num).toDouble(),
          longitude: (target[1] as num).toDouble(),
          zoom: (position['zoom'] as num?)?.toDouble(),
          bearing: (position['bearing'] as num?)?.toDouble(),
          pitch: (position['tilt'] as num?)?.toDouble(),
        ),
      );
    case 'newLatLng':
      final target = json[1] as List;
      return goTo(
        CameraSpec(
          latitude: (target[0] as num).toDouble(),
          longitude: (target[1] as num).toDouble(),
        ),
      );
    case 'newLatLngZoom':
      final target = json[1] as List;
      return goTo(
        CameraSpec(
          latitude: (target[0] as num).toDouble(),
          longitude: (target[1] as num).toDouble(),
          zoom: (json[2] as num).toDouble(),
        ),
      );
    case 'newLatLngBounds':
      final bounds = json[1] as List;
      final southwest = bounds[0] as List;
      final northeast = bounds[1] as List;
      return FitBoundsCommand(
        sessionId,
        BoundsSpec(
          south: (southwest[0] as num).toDouble(),
          west: (southwest[1] as num).toDouble(),
          north: (northeast[0] as num).toDouble(),
          east: (northeast[1] as num).toDouble(),
        ),
        paddingLeft: (json[2] as num).toDouble(),
        paddingTop: (json[3] as num).toDouble(),
        paddingRight: (json[4] as num).toDouble(),
        paddingBottom: (json[5] as num).toDouble(),
        durationMs: durationMs,
        easing: easing,
      );
    case 'scrollBy':
      // A scroll moves the map content the other way round.
      return MoveByCommand(
        sessionId,
        -(json[1] as num).toDouble(),
        -(json[2] as num).toDouble(),
        durationMs: durationMs,
      );
    case 'zoomBy':
      final anchor = json.length > 2 ? (json[2] as List) : null;
      return ScaleByCommand(
        sessionId,
        // One zoom level is a doubling of the scale.
        pow(2.0, (json[1] as num).toDouble()).toDouble(),
        anchorX: anchor == null ? null : (anchor[0] as num).toDouble(),
        anchorY: anchor == null ? null : (anchor[1] as num).toDouble(),
        durationMs: durationMs,
      );
    case 'zoomIn':
      return ScaleByCommand(sessionId, 2, durationMs: durationMs);
    case 'zoomOut':
      return ScaleByCommand(sessionId, 0.5, durationMs: durationMs);
    case 'zoomTo':
      return goTo(CameraSpec(zoom: (json[1] as num).toDouble()));
    case 'bearingTo':
      return goTo(CameraSpec(bearing: (json[1] as num).toDouble()));
    case 'tiltTo':
      return goTo(CameraSpec(pitch: (json[1] as num).toDouble()));
    default:
      throw UnimplementedError('CameraUpdate "$kind" is not supported yet');
  }
}
