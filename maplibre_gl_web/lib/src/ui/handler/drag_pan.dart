import 'dart:html';

import 'package:maplibre_gl_web/src/interop/interop.dart';

class DragPanHandler extends JsObjectWrapper<DragPanHandlerJsImpl> {
  /// Creates a new DragPanHandler from a [jsObject].
  DragPanHandler.fromJsObject(super.jsObject) : super.fromJsObject();

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
  dynamic enable() => jsObject.enable();

  ///  Disables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.disable();
  dynamic disable() => jsObject.disable();

  dynamic onMouseDown(MouseEvent e) => jsObject.onMouseDown(e);

  dynamic onTouchStart(TouchEvent e) => jsObject.onTouchStart(e);
}
