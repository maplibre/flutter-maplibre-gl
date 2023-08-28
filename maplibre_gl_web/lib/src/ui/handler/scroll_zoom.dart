library mapboxgl.ui.handler.scroll_zoom;

import 'dart:html';

import 'package:maplibre_gl_web/src/interop/interop.dart';

class ScrollZoomHandler extends JsObjectWrapper<ScrollZoomHandlerJsImpl> {
  ///  Set the zoom rate of a trackpad
  ///  @param {number} [zoomRate = 1/100]
  setZoomRate(num zoomRate) => jsObject.setZoomRate(zoomRate);

  ///  Set the zoom rate of a mouse wheel
  ///  @param {number} [wheelZoomRate = 1/450]
  setWheelZoomRate(num wheelZoomRate) =>
      jsObject.setWheelZoomRate(wheelZoomRate);

  ///  Returns a Boolean indicating whether the "scroll to zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "scroll to zoom" interaction is enabled.
  bool isEnabled() => jsObject.isEnabled();

  ///  Active state is turned on and off with every scroll wheel event and is set back to false before the map
  ///  render is called, so _active is not a good candidate for determining if a scroll zoom animation is in
  ///  progress.
  bool isActive() => jsObject.isActive();

  bool isZooming() => jsObject.isZooming();

  ///  Enables the "scroll to zoom" interaction.
  ///
  ///  @param {Object} [options]
  ///  @param {string} `options.around` If "center" is passed, map will zoom around center of map
  ///
  ///  @example
  ///    map.scrollZoom.enable();
  ///  @example
  ///   map.scrollZoom.enable({ around: 'center' })
  enable([dynamic options]) => jsObject.enable(options);

  ///  Disables the "scroll to zoom" interaction.
  ///
  ///  @example
  ///    map.scrollZoom.disable();
  disable() => jsObject.disable();

  onWheel(WheelEvent e) => jsObject.onWheel(e);

  /// Creates a new ScrollZoomHandler from a [jsObject].
  ScrollZoomHandler.fromJsObject(ScrollZoomHandlerJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
