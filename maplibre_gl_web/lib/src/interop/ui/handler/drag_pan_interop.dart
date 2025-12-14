@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@staticInterop
abstract class DragPanHandlerJsImpl {
  factory DragPanHandlerJsImpl() => throw UnimplementedError();
}

extension DragPanHandlerJsImplExtension on DragPanHandlerJsImpl {
  ///  Returns a Boolean indicating whether the "drag to pan" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "drag to pan" interaction is enabled.
  external bool isEnabled();

  ///  Returns a Boolean indicating whether the "drag to pan" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "drag to pan" interaction is active.
  external bool isActive();

  ///  Enables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.enable();
  external void enable();

  ///  Disables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.disable();
  external void disable();

  external void onMouseDown(MouseEvent e);

  external void onTouchStart(TouchEvent e);
}
