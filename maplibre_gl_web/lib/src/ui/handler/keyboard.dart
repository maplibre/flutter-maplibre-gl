library mapboxgl.ui.handler.keyboard;

import 'package:maplibre_gl_web/src/interop/interop.dart';

class KeyboardHandler extends JsObjectWrapper<KeyboardHandlerJsImpl> {
  ///  Returns a Boolean indicating whether keyboard interaction is enabled.
  ///
  ///  @returns {boolean} `true` if keyboard interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Enables keyboard interaction.
  ///
  ///  @example
  ///  map.keyboard.enable();
  bool enable() => jsObject.enable();

  ///  Disables keyboard interaction.
  ///
  ///  @example
  ///  map.keyboard.disable();
  bool disable() => jsObject.disable();

  /// Creates a new KeyboardHandler from a [jsObject].
  KeyboardHandler.fromJsObject(KeyboardHandlerJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
