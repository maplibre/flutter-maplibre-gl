import 'dart:html';
import 'package:maplibre_gl_web/src/interop/interop.dart';

class TouchZoomRotateHandler
    extends JsObjectWrapper<TouchZoomRotateHandlerJsImpl> {
  /// Creates a new TouchZoomRotateHandler from a [jsObject].
  TouchZoomRotateHandler.fromJsObject(super.jsObject) : super.fromJsObject();

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
  dynamic enable([dynamic options]) => jsObject.enable(options);

  ///  Disables the "pinch to rotate and zoom" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.disable();
  dynamic disable() => jsObject.disable();

  ///  Disables the "pinch to rotate" interaction, leaving the "pinch to zoom"
  ///  interaction enabled.
  ///
  ///  @example
  ///    map.touchZoomRotate.disableRotation();
  dynamic disableRotation() => jsObject.disableRotation();

  ///  Enables the "pinch to rotate" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///    map.touchZoomRotate.enableRotation();
  dynamic enableRotation() => jsObject.enableRotation();

  dynamic onStart(TouchEvent e) => jsObject.onStart(e);
}
