import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

/// A LogoControl is a control that adds the watermark.
class LogoControl extends JsObjectWrapper<LogoControlJsImpl> {
  factory LogoControl() => LogoControl.fromJsObject(LogoControlJsImpl());

  dynamic onAdd(MapLibreMap map) => jsObject.onAdd(map.jsObject);

  dynamic onRemove() => jsObject.onRemove();

  dynamic getDefaultPosition() => jsObject.getDefaultPosition();

  /// Creates a new LogoControl from a [jsObject].
  LogoControl.fromJsObject(super.jsObject) : super.fromJsObject();
}
