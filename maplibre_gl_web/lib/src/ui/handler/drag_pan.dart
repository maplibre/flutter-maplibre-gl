library mapboxgl.ui.handler.drag_pan;

import 'dart:html';

import 'package:maplibre_gl_web/src/interop/interop.dart';

class DragPanHandler extends JsObjectWrapper<DragPanHandlerJsImpl> {
  ///  Returns a Boolean indicating whether the "drag to pan" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "drag to pan" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Returns a Boolean indicating whether the "drag to pan" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "drag to pan" interaction is active.
  bool isActive() => jsObject.isActive();

  ///  Enables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.enable();
  enable() => jsObject.enable();

  ///  Disables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.disable();
  disable() => jsObject.disable();

  onMouseDown(MouseEvent e) => jsObject.onMouseDown(e);

  onTouchStart(TouchEvent e) => jsObject.onTouchStart(e);

  /// Creates a new DragPanHandler from a [jsObject].
  DragPanHandler.fromJsObject(DragPanHandlerJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
