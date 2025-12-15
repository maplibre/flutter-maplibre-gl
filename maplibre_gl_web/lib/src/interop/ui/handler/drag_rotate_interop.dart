@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@staticInterop
abstract class DragRotateHandlerJsImpl {
  factory DragRotateHandlerJsImpl() => throw UnimplementedError();
}

extension DragRotateHandlerJsImplExtension on DragRotateHandlerJsImpl {
  ///  Returns a Boolean indicating whether the "drag to rotate" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "drag to rotate" interaction is enabled.
  external bool isEnabled();

  ///  Returns a Boolean indicating whether the "drag to rotate" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "drag to rotate" interaction is active.
  external bool isActive();

  ///  Enables the "drag to rotate" interaction.
  ///
  ///  @example
  ///  map.dragRotate.enable();
  external void enable();

  ///  Disables the "drag to rotate" interaction.
  ///
  ///  @example
  ///  map.dragRotate.disable();
  external void disable();

  external void onMouseDown(MouseEvent e);
}
