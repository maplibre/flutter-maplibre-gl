library mapboxgl.ui.handler.touch_zoom_rotate;

import 'dart:html';
import 'package:maplibre_gl_web/src/interop/interop.dart';

class TouchZoomRotateHandler
    extends JsObjectWrapper<TouchZoomRotateHandlerJsImpl> {
  ///  Returns a Boolean indicating whether the "pinch to rotate and zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "pinch to rotate and zoom" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Enables the "pinch to rotate and zoom" interaction.
  ///
  ///  @param {Object} [options]
  ///  @param {string} `options.around` If "center" is passed, map will zoom around the center
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///  @example
  ///    map.touchZoomRotate.enable({ around: 'center' });
  enable([dynamic options]) => jsObject.enable(options);

  ///  Disables the "pinch to rotate and zoom" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.disable();
  disable() => jsObject.disable();

  ///  Disables the "pinch to rotate" interaction, leaving the "pinch to zoom"
  ///  interaction enabled.
  ///
  ///  @example
  ///    map.touchZoomRotate.disableRotation();
  disableRotation() => jsObject.disableRotation();

  ///  Enables the "pinch to rotate" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///    map.touchZoomRotate.enableRotation();
  enableRotation() => jsObject.enableRotation();

  onStart(TouchEvent e) => jsObject.onStart(e);

  /// Creates a new TouchZoomRotateHandler from a [jsObject].
  TouchZoomRotateHandler.fromJsObject(TouchZoomRotateHandlerJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
