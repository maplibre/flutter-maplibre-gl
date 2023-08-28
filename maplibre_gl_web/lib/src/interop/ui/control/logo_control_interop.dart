@JS('maplibregl')
library mapboxgl.interop.ui.control.logo_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

/// A `LogoControl` is a control that adds the Mapbox watermark
/// to the map as required by the [terms of service](https://www.mapbox.com/tos/) for Mapbox
/// vector tiles and core styles.
///
/// @implements {IControl}
/// @private
@JS('LogoControl')
class LogoControlJsImpl {
  external factory LogoControlJsImpl();

  external onAdd(MapboxMapJsImpl map);

  external onRemove();

  external getDefaultPosition();
}
