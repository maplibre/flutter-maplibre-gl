@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:web/web.dart';

@JS()
@staticInterop
abstract class BoxZoomHandlerJsImpl {
  factory BoxZoomHandlerJsImpl() => throw UnimplementedError();
}

extension BoxZoomHandlerJsImplExtension on BoxZoomHandlerJsImpl {
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
  external void enable();

  ///  Disables the "box zoom" interaction.
  ///
  ///  @example
  ///    map.boxZoom.disable();
  external void disable();

  external void onMouseDown(MouseEvent e);
}
