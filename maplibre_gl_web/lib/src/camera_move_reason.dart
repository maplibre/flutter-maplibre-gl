/// What started a camera move of maplibre-gl-js.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:web/web.dart' as web;

/// The reason of [moveStart], a `movestart` event of maplibre-gl-js.
///
/// maplibre-gl-js gives a move the browser's event behind it only for input
/// of the user, a click on the compass included, which Android and iOS do not
/// count as a gesture. The mouse wheel is the exception: its move comes with
/// no event, so [scrollZooming] tells it, from `map.scrollZoom.isActive()`.
CameraMoveReason cameraMoveReason(
  JSObject moveStart, {
  bool scrollZooming = false,
}) {
  final input = moveStart.getProperty<JSAny?>('originalEvent'.toJS);
  if (input == null || !input.isA<web.Event>()) {
    return scrollZooming
        ? CameraMoveReason.gesture
        : CameraMoveReason.programmatic;
  }
  final target = (input as web.Event).target;
  final onControl =
      target.isA<web.Element>() &&
      (target! as web.Element).closest('.maplibregl-ctrl') != null;
  return onControl ? CameraMoveReason.programmatic : CameraMoveReason.gesture;
}
