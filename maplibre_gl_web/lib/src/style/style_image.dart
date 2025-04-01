import 'package:maplibre_gl_web/src/interop/interop.dart';

class StyleImage extends JsObjectWrapper<StyleImageJsImpl> {
  /// Creates a new EvaluationParameters from a [jsObject].
  StyleImage.fromJsObject(super.jsObject) : super.fromJsObject();
  dynamic get data => jsObject.data;
  num get pixelRatio => jsObject.pixelRatio;
  bool get sdf => jsObject.sdf;
  num get version => jsObject.version;
  bool get hasRenderCallback => jsObject.hasRenderCallback;
  StyleImageInterface get userImage =>
      StyleImageInterface.fromJsObject(jsObject.userImage);
}

class StyleImageInterface extends JsObjectWrapper<StyleImageInterfaceJsImpl> {
  /// Creates a new EvaluationParameters from a [jsObject].
  StyleImageInterface.fromJsObject(super.jsObject) : super.fromJsObject();
  num get width => jsObject.width;
  num get height => jsObject.height;
  dynamic get data => jsObject.data;
  Function get render => jsObject.render;
  void Function(MapLibreMapJsImpl map, String id) get onAdd =>
      jsObject.onAdd; //TODO: Remove JsImpl
  Function get onRemove => jsObject.onRemove;
}
