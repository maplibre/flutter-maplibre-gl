@JS('maplibregl')
library mapboxgl.interop.ui.handler.drag_rotate;

import 'dart:html';

import 'package:js/js.dart';

@JS()
@anonymous
abstract class DragRotateHandlerJsImpl {
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
  external enable();

  ///  Disables the "drag to rotate" interaction.
  ///
  ///  @example
  ///  map.dragRotate.disable();
  external disable();

  external onMouseDown(MouseEvent e);
}
