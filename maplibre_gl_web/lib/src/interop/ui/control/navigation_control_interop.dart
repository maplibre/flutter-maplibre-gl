@JS('maplibregl')
library maplibre.interop.ui.control.navigation_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

@JS()
@anonymous
class NavigationControlOptionsJsImpl {
  external bool get showCompass;

  external bool get showZoom;

  external bool get visualizePitch;

  external factory NavigationControlOptionsJsImpl({
    bool? showCompass,
    bool? showZoom,
    bool? visualizePitch,
  });
}

/// A `NavigationControl` control contains zoom buttons and a compass.
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Boolean} [options.showCompass=true] If `true` the compass button is included.
/// @param {Boolean} [options.showZoom=true] If `true` the zoom-in and zoom-out buttons are included.
/// @param {Boolean} [options.visualizePitch=false] If `true` the pitch is visualized by rotating X-axis of compass.
/// @example
/// var nav = new maplibregl.NavigationControl();
/// map.addControl(nav, 'top-left');
/// @see [Display map navigation controls](https://maplibre.org/maplibre-gl-js/docs/examples/navigation/)
/// @see [Add a third party vector tile source](https://maplibre.org/maplibre-gl-js/docs/examples/third-party/)
@JS('NavigationControl')
class NavigationControlJsImpl {
  external NavigationControlOptionsJsImpl get options;

  external factory NavigationControlJsImpl(
      NavigationControlOptionsJsImpl options);

  external onAdd(MapLibreMapJsImpl map);

  external onRemove();
}
