@JS('maplibregl')
library;

import 'dart:js_interop';

import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

/// JS interop class for the ScaleControl options.
extension type ScaleControlOptionsJsImpl._(JSObject _) implements JSObject {
  external num get maxWidth;
  external String get unit;

  external factory ScaleControlOptionsJsImpl({
    num? maxWidth,
    String? unit,
  });
}

/// A `ScaleControl` control displays the ratio of a distance on the map
/// to the corresponding distance on the ground.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Number} [options.maxWidth=100] The maximum length of the scale control in pixels.
/// @param {String} [options.unit='metric'] Unit of the distance ('imperial', 'metric' or 'nautical').
@JS('ScaleControl')
@staticInterop
class ScaleControlJsImpl {
  external factory ScaleControlJsImpl([ScaleControlOptionsJsImpl? options]);
}

extension ScaleControlJsImplExtension on ScaleControlJsImpl {
  external ScaleControlOptionsJsImpl? get options;
  external JSAny? onAdd(MapLibreMapJsImpl map);
  external void onRemove();
  external String getDefaultPosition();
  external void setUnit(String unit);
}
