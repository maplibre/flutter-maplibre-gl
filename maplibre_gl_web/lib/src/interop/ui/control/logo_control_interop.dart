@JS('maplibregl')
library maplibre.interop.ui.control.logo_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

/// A LogoControl is a control that adds the watermark.
///
/// @implements {IControl}
/// @private
@JS('LogoControl')
class LogoControlJsImpl {
  external factory LogoControlJsImpl();

  external dynamic onAdd(MapLibreMapJsImpl map);

  external dynamic onRemove();

  external dynamic getDefaultPosition();
}
