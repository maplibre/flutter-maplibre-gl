library mapboxgl.ui.control.Attribution_control;

import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/control/attribution_control_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

class AttributionControlOptions
    extends JsObjectWrapper<AttributionControlOptionsJsImpl> {
  factory AttributionControlOptions({
    bool? compact,
    List<String>? customAttribution,
  }) =>
      AttributionControlOptions.fromJsObject(AttributionControlOptionsJsImpl(
        compact: compact,
        customAttribution: customAttribution,
      ));

  /// Creates a new AttributionControlOptions from a [jsObject].
  AttributionControlOptions.fromJsObject(
      AttributionControlOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

/// A `AttributionControl` control contains zoom buttons and a compass.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Boolean} [options.compact] If `true`, the attribution control will always collapse when moving the map. If `false`,force the expanded attribution control. The default is a responsive attribution that collapses when the user moves the map on maps less than 640 pixels wide.
/// @param {List<String>} [options.customAttribution] Attributions to show in addition to any other attributions.
/// @example
/// var attribution = new mapboxgl.AttributionControl();
/// map.addControl(attribution, 'top-left');
/// @see [Display map attribution controls](https://maplibre.org/maplibre-gl-js/docs/examples/attribution-position/)
class AttributionControl extends JsObjectWrapper<AttributionControlJsImpl> {
  AttributionControlOptions get options =>
      AttributionControlOptions.fromJsObject(jsObject.options);

  factory AttributionControl(AttributionControlOptions options) =>
      AttributionControl.fromJsObject(
          AttributionControlJsImpl(options.jsObject));

  onAdd(MapboxMap map) => jsObject.onAdd(map.jsObject);

  onRemove() => jsObject.onRemove();

  /// Creates a new MapOptions from a [jsObject].
  AttributionControl.fromJsObject(AttributionControlJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
