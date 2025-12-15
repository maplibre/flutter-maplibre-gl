@JS('maplibregl')
library;

import 'dart:js_interop';

@JS()
@staticInterop
abstract class KeyboardHandlerJsImpl {
  factory KeyboardHandlerJsImpl() => throw UnimplementedError();
}

extension KeyboardHandlerJsImplExtension on KeyboardHandlerJsImpl {
  ///  Returns a Boolean indicating whether keyboard interaction is enabled.
  ///
  ///  @returns {boolean} `true` if keyboard interaction is enabled.
  external bool isEnabled();

  ///  Enables keyboard interaction.
  ///
  ///  @example
  ///  map.keyboard.enable();
  external bool? enable();

  ///  Disables keyboard interaction.
  ///
  ///  @example
  ///  map.keyboard.disable();
  external bool? disable();
}
