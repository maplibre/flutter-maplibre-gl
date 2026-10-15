import 'dart:js_interop';

import 'package:web/web.dart';

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
  ///  [linearity], [deceleration] and [maxSpeed] tune the inertia after the
  ///  drag. Values left null keep the maplibre-gl-js defaults, and calling
  ///  `enable()` again without them restores those defaults.
  ///
  ///  @example
  ///  map.dragPan.enable();
  void enable({num? linearity, num? deceleration, num? maxSpeed}) {
    final options = <String, Object>{
      if (linearity != null) 'linearity': linearity,
      if (deceleration != null) 'deceleration': deceleration,
      if (maxSpeed != null) 'maxSpeed': maxSpeed,
    };
    jsObject.enable(options.jsify());
  }

  ///  Disables the "drag to pan" interaction.
  ///
  ///  @example
  ///  map.dragPan.disable();
  disable() => jsObject.disable();

  onMouseDown(MouseEvent e) => jsObject.onMouseDown(e);

  onTouchStart(TouchEvent e) => jsObject.onTouchStart(e);

  /// Creates a new DragPanHandler from a [jsObject].
  DragPanHandler.fromJsObject(super.jsObject) : super.fromJsObject();
}
