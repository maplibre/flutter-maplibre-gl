@JS('maplibregl')
library mapboxgl.interop.ui.handler.box_zoom;

import 'dart:html';

import 'package:js/js.dart';

@JS()
@anonymous
abstract class BoxZoomHandlerJsImpl {
  ///  Returns a Boolean indicating whether the "box zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "box zoom" interaction is enabled.
  external bool isEnabled();

  ///  Returns a Boolean indicating whether the "box zoom" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "box zoom" interaction is active.
  external bool isActive();

  ///  Enables the "box zoom" interaction.
  ///
  ///  @example
  ///    map.boxZoom.enable();
  external enable();

  ///  Disables the "box zoom" interaction.
  ///
  ///  @example
  ///    map.boxZoom.disable();
  external disable();

  external onMouseDown(MouseEvent e);
}
