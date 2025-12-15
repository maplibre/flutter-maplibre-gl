@JS('maplibregl')
library;

import 'dart:js_interop';

import 'package:maplibre_gl_web/src/interop/ui/events_interop.dart';

@JS()
@staticInterop
abstract class DoubleClickZoomHandlerJsImpl {
  factory DoubleClickZoomHandlerJsImpl() => throw UnimplementedError();
}

extension DoubleClickZoomHandlerJsImplExtension
    on DoubleClickZoomHandlerJsImpl {
  ///  Returns a Boolean indicating whether the "double click to zoom" interaction is enabled.
  ///
  ///  @returns {boolean} `true` if the "double click to zoom" interaction is enabled.
  external bool isEnabled();

  ///  Returns a Boolean indicating whether the "double click to zoom" interaction is active, i.e. currently being used.
  ///
  ///  @returns {boolean} `true` if the "double click to zoom" interaction is active.
  external bool isActive();

  ///  Enables the "double click to zoom" interaction.
  ///
  ///  @example
  ///  map.doubleClickZoom.enable();
  external void enable();

  ///  Disables the "double click to zoom" interaction.
  ///
  ///  @example
  ///  map.doubleClickZoom.disable();
  external void disable();

  external void onTouchStart(MapTouchEventJsImpl e);

  external void onDblClick(MapMouseEventJsImpl e);
}
