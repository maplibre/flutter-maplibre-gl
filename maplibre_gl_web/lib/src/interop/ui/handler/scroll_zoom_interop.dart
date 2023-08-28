@JS('maplibregl')
library mapboxgl.interop.ui.handler.scroll_zoom;

import 'dart:html';

import 'package:js/js.dart';

@JS()
@anonymous
abstract class ScrollZoomHandlerJsImpl {
  ///  Set the zoom rate of a trackpad
  ///  @param {number} [zoomRate = 1/100]
  external setZoomRate(num zoomRate);

  ///  Set the zoom rate of a mouse wheel
  ///  @param {number} [wheelZoomRate = 1/450]
  external setWheelZoomRate(num wheelZoomRate);

  ///  Returns a Boolean indicating whether the "scroll to zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "scroll to zoom" interaction is enabled.
  external bool isEnabled();

  ///  Active state is turned on and off with every scroll wheel event and is set back to false before the map
  ///  render is called, so _active is not a good candidate for determining if a scroll zoom animation is in
  ///  progress.
  external bool isActive();

  external bool isZooming();

  ///  Enables the "scroll to zoom" interaction.
  ///
  ///  @param {Object} [options]
  ///  @param {string} `options.around` If "center" is passed, map will zoom around center of map
  ///
  ///  @example
  ///    map.scrollZoom.enable();
  ///  @example
  ///   map.scrollZoom.enable({ around: 'center' })
  external enable(dynamic options);

  ///  Disables the "scroll to zoom" interaction.
  ///
  ///  @example
  ///    map.scrollZoom.disable();
  external disable();

  external onWheel(WheelEvent e);
}
