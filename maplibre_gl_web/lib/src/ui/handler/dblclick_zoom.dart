import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/events.dart';

class DoubleClickZoomHandler
    extends JsObjectWrapper<DoubleClickZoomHandlerJsImpl> {
  ///  Returns a Boolean indicating whether the "double click to zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "double click to zoom" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Returns a Boolean indicating whether the "double click to zoom" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "double click to zoom" interaction is active.
  bool isActive() => jsObject.isActive();

  ///  Enables the "double click to zoom" interaction.
  ///
  ///  @example
  ///  map.doubleClickZoom.enable();
  dynamic enable() => jsObject.enable();

  ///  Disables the "double click to zoom" interaction.
  ///
  ///  @example
  ///  map.doubleClickZoom.disable();
  dynamic disable() => jsObject.disable();

  dynamic onTouchStart(MapTouchEvent e) => jsObject.onTouchStart(e.jsObject);

  dynamic onDblClick(MapMouseEvent e) => jsObject.onDblClick(e.jsObject);

  /// Creates a new DoubleClickZoomHandler from a [jsObject].
  DoubleClickZoomHandler.fromJsObject(super.jsObject) : super.fromJsObject();
}
