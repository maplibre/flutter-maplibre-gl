@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

extension type AttributionControlOptionsJsImpl._(JSObject _)
    implements JSObject {
  external bool get compact;

  external JSArray<JSString>? get customAttribution;

  external factory AttributionControlOptionsJsImpl(
      {bool? compact, JSArray<JSString>? customAttribution});
}

/// A `AttributionControl` control contains attributions.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Boolean} [options.compact] If `true`, the attribution control will always collapse when moving the map. If `false`,force the expanded attribution control. The default is a responsive attribution that collapses when the user moves the map on maps less than 640 pixels wide.
/// @param `{List<String>}` [options.customAttribution] Attributions to show in addition to any other attributions.
/// @example
/// var attribution = new maplibregl.AttributionControl();
/// map.addControl(attribution, 'top-left');
/// @see [Display map attribution controls](https://maplibre.org/maplibre-gl-js/docs/examples/attribution-position/)
@JS('AttributionControl')
@staticInterop
class AttributionControlJsImpl {
  external factory AttributionControlJsImpl(
      AttributionControlOptionsJsImpl options);
}

extension AttributionControlJsImplExtension on AttributionControlJsImpl {
  external AttributionControlOptionsJsImpl get options;
  external JSAny? onAdd(MapLibreMapJsImpl map);
  external void onRemove();
}
