library mapboxgl.ui.control.navigation_control;

import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

class NavigationControlOptions
    extends JsObjectWrapper<NavigationControlOptionsJsImpl> {
  bool get showCompass => jsObject.showCompass;

  bool get showZoom => jsObject.showZoom;

  bool get visualizePitch => jsObject.visualizePitch;

  factory NavigationControlOptions({
    bool? showCompass,
    bool? showZoom,
    bool? visualizePitch,
  }) =>
      NavigationControlOptions.fromJsObject(NavigationControlOptionsJsImpl(
        showCompass: showCompass,
        showZoom: showZoom,
        visualizePitch: visualizePitch,
      ));

  /// Creates a new NavigationControlOptions from a [jsObject].
  NavigationControlOptions.fromJsObject(NavigationControlOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

/// A `NavigationControl` control contains zoom buttons and a compass.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Boolean} [options.showCompass=true] If `true` the compass button is included.
/// @param {Boolean} [options.showZoom=true] If `true` the zoom-in and zoom-out buttons are included.
/// @param {Boolean} [options.visualizePitch=false] If `true` the pitch is visualized by rotating X-axis of compass.
/// @example
/// var nav = new mapboxgl.NavigationControl();
/// map.addControl(nav, 'top-left');
/// @see [Display map navigation controls](https://www.mapbox.com/mapbox-gl-js/example/navigation/)
/// @see [Add a third party vector tile source](https://www.mapbox.com/mapbox-gl-js/example/third-party/)
class NavigationControl extends JsObjectWrapper<NavigationControlJsImpl> {
  NavigationControlOptions get options =>
      NavigationControlOptions.fromJsObject(jsObject.options);

  factory NavigationControl(NavigationControlOptions options) =>
      NavigationControl.fromJsObject(NavigationControlJsImpl(options.jsObject));

  onAdd(MapboxMap map) => jsObject.onAdd(map.jsObject);

  onRemove() => jsObject.onRemove();

  /// Creates a new MapOptions from a [jsObject].
  NavigationControl.fromJsObject(NavigationControlJsImpl jsObject)
      : super.fromJsObject(jsObject);
}
