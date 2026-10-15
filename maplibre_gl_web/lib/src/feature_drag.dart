import 'dart:math' show Point;

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show LatLng;

/// How far, in CSS pixels, the pointer has to move from where it went down
/// before a press on a draggable feature becomes a drag.
///
/// It is maplibre-gl-js's default `clickTolerance`, which the plugin never
/// changes: below it the map reports a click, from it on a drag, so a press
/// is always one or the other.
const double featureDragThreshold = 3;

/// Turns the pointer events of a press on a draggable feature into the
/// `feature#onDrag` payloads, the same sequence Android and iOS send.
///
/// A press that stays within [threshold] of where it went down is a click and
/// reports nothing. Once the pointer moves [threshold] or more away, [move]
/// returns `start`, with origin and current at that point and a zero delta;
/// later moves return `drag` with the movement since the previous event, and
/// [up] returns `end`.
class FeatureDragTracker {
  FeatureDragTracker({this.threshold = featureDragThreshold});

  final double threshold;

  Object? _featureId;
  Point<double>? _downPoint;
  LatLng? _origin;
  LatLng? _previous;
  bool _clickAfterDrag = false;

  /// Whether a press on a draggable feature is in progress, dragging or not.
  bool get isPressed => _featureId != null;

  /// Whether the press has become a drag.
  bool get isDragging => _origin != null;

  /// A press on the draggable feature [featureId] at [point].
  void down(Object featureId, Point<double> point) {
    _reset();
    _featureId = featureId;
    _downPoint = point;
  }

  /// The pointer moved to [point], [latLng] on the map. Returns the payload to
  /// send, or null while the press is still a click or there is no press.
  Map<String, dynamic>? move(Point<double> point, LatLng latLng) {
    final downPoint = _downPoint;
    if (_featureId == null || downPoint == null) return null;
    if (!isDragging) {
      if (point.distanceTo(downPoint) < threshold) return null;
      _origin = _previous = latLng;
      return _payload(point, latLng, 'start');
    }
    return _payload(point, latLng, 'drag');
  }

  /// The pointer went up at [point], [latLng] on the map. Returns the `end`
  /// payload when the press was a drag, otherwise null.
  Map<String, dynamic>? up(Point<double> point, LatLng latLng) {
    final payload = isDragging ? _payload(point, latLng, 'end') : null;
    _reset();
    _clickAfterDrag = payload != null;
    return payload;
  }

  /// Whether a click that follows [up] belongs to the drag that just ended
  /// and should be dropped, as Android and iOS report no tap after a drag.
  /// Reading it clears it.
  bool takeClickAfterDrag() {
    final value = _clickAfterDrag;
    _clickAfterDrag = false;
    return value;
  }

  /// A new press anywhere on the map: a pending click after a drag is stale.
  void pointerDown() => _clickAfterDrag = false;

  Map<String, dynamic> _payload(
    Point<double> point,
    LatLng current,
    String eventType,
  ) {
    final payload = <String, dynamic>{
      'id': _featureId,
      'point': point,
      'origin': _origin,
      'current': current,
      'delta': current - _previous!,
      'eventType': eventType,
    };
    _previous = current;
    return payload;
  }

  void _reset() {
    _featureId = null;
    _downPoint = null;
    _origin = null;
    _previous = null;
    _clickAfterDrag = false;
  }
}
