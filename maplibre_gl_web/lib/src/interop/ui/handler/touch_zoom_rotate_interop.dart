@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@staticInterop
abstract class TouchZoomRotateHandlerJsImpl {
  factory TouchZoomRotateHandlerJsImpl() => throw UnimplementedError();
}

extension TouchZoomRotateHandlerJsImplExtension
    on TouchZoomRotateHandlerJsImpl {
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
  external void enable(JSAny? options);

  ///  Disables the "pinch to rotate and zoom" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.disable();
  external void disable();

  ///  Disables the "pinch to rotate" interaction, leaving the "pinch to zoom"
  ///  interaction enabled.
  ///
  ///  @example
  ///    map.touchZoomRotate.disableRotation();
  external void disableRotation();

  ///  Enables the "pinch to rotate" interaction.
  ///
  ///  @example
  ///    map.touchZoomRotate.enable();
  ///    map.touchZoomRotate.enableRotation();
  external void enableRotation();

  external void onStart(TouchEvent e);
}
