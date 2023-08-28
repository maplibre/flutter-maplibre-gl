@JS('maplibregl')
library mapboxgl.interop.ui.handler.drag_pan;

import 'dart:html';

import 'package:js/js.dart';

@JS()
@anonymous
abstract class DragPanHandlerJsImpl {
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
  external enable();

  ///  Disables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.disable();
  external disable();

  external onMouseDown(MouseEvent e);

  external onTouchStart(TouchEvent e);
}
