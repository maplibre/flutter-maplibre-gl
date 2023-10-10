@JS('maplibregl')
library mapboxgl.interop.ui.control.navigation_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

@JS()
@anonymous
class AttributionControlOptionsJsImpl {
  external bool get compact;

  external List<String>? get customAttribution;

  external factory AttributionControlOptionsJsImpl(
      {bool? compact, List<String>? customAttribution});
}

/// A `AttributionControl` control contains attributions.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Boolean} [options.compact] If `true`, the attribution control will always collapse when moving the map. If `false`,force the expanded attribution control. The default is a responsive attribution that collapses when the user moves the map on maps less than 640 pixels wide.
/// @param {List<String>} [options.customAttribution] Attributions to show in addition to any other attributions.
/// @example
/// var attribution = new mapboxgl.AttributionControl();
/// map.addControl(attribution, 'top-left');
/// @see [Display map attribution controls](https://maplibre.org/maplibre-gl-js/docs/examples/attribution-position/)
@JS('AttributionControl')
class AttributionControlJsImpl {
  external AttributionControlOptionsJsImpl get options;

  external factory AttributionControlJsImpl(
      AttributionControlOptionsJsImpl options);

  external onAdd(MapboxMapJsImpl map);

  external onRemove();
}
