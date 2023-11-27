@JS('maplibregl')
library maplibre.interop.ui.handler.touch_zoom_rotate;

import 'dart:html';

import 'package:js/js.dart';

@JS()
@anonymous
abstract class TouchZoomRotateHandlerJsImpl {
  ///  Returns a Boolean indicating whether the "pinch to rotate and zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "pinch to rotate and zoom" interaction is enabled.
  external bool isEnabled();

  ///  Enables the "pinch to rotate and zoom" interaction.
  ///
  ///  @param {Object} [options]
  ///  @param {string} `options.around` If "center" is passed, map will zoom around the center
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///  @example
  ///    map.touchZoomRotate.enable({ around: 'center' });
  external enable(dynamic options);

  ///  Disables the "pinch to rotate and zoom" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.disable();
  external disable();

  ///  Disables the "pinch to rotate" interaction, leaving the "pinch to zoom"
  ///  interaction enabled.
  ///
  ///  @example
  ///    map.touchZoomRotate.disableRotation();
  external disableRotation();

  ///  Enables the "pinch to rotate" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///    map.touchZoomRotate.enableRotation();
  external enableRotation();

  external onStart(TouchEvent e);
}
