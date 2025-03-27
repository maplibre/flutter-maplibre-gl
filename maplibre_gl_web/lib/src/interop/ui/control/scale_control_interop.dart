@JS('maplibregl')
library maplibre.interop.ui.control.scale_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

/// JS interop class for the ScaleControl options.
@JS()
@anonymous
class ScaleControlOptionsJsImpl {
  external num get maxWidth;
  external String get unit;

  external factory ScaleControlOptionsJsImpl({
    num? maxWidth,
    String? unit,
  });
}

/// JS interop class for ScaleControl itself.
@JS('ScaleControl')
class ScaleControlJsImpl {
  external ScaleControlOptionsJsImpl get options;

  external factory ScaleControlJsImpl(ScaleControlOptionsJsImpl options);

  external dynamic onAdd(MapLibreMapJsImpl map);

  external dynamic onRemove();

  external String getDefaultPosition();

  external void setUnit(String unit);
}
