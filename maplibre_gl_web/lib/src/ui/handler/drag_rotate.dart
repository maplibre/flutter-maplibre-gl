library mapboxgl.ui.handler.drag_rotate;

import 'dart:html';

import 'package:maplibre_gl_web/src/interop/interop.dart';

class DragRotateHandler extends JsObjectWrapper<DragRotateHandlerJsImpl> {
  ///  Returns a Boolean indicating whether the "drag to rotate" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "drag to rotate" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Returns a Boolean indicating whether the "drag to rotate" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "drag to rotate" interaction is active.
  bool isActive() => jsObject.isActive();

  ///  Enables the "drag to rotate" interaction.
  ///
  ///  @example
  ///  map.dragRotate.enable();
  enable() => jsObject.enable();

  ///  Disables the "drag to rotate" interaction.
  ///
  ///  @example
  ///  map.dragRotate.disable();
  disable() => jsObject.disable();

  onMouseDown(MouseEvent e) => jsObject.onMouseDown(e);

  /// Creates a new DragPanHandler from a [jsObject].
  DragRotateHandler.fromJsObject(DragRotateHandlerJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
