import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/interop.dart';

class StyleImage extends JsObjectWrapper<StyleImageJsImpl> {
  dynamic get data => jsObject.data;
  num get pixelRatio => jsObject.pixelRatio;
  bool get sdf => jsObject.sdf;
  num get version => jsObject.version;
  bool get hasRenderCallback => jsObject.hasRenderCallback;
  StyleImageInterface get userImage =>
      StyleImageInterface.fromJsObject(jsObject.userImage);

  /// Creates a new EvaluationParameters from a [jsObject].
  StyleImage.fromJsObject(super.jsObject) : super.fromJsObject();
}

class StyleImageInterface extends JsObjectWrapper<StyleImageInterfaceJsImpl> {
  num get width => jsObject.width;
  num get height => jsObject.height;
  dynamic get data => jsObject.data;
  JSFunction get render => jsObject.render;
  JSFunction get onAdd => jsObject.onAdd;
  JSFunction get onRemove => jsObject.onRemove;

  /// Creates a new EvaluationParameters from a [jsObject].
  StyleImageInterface.fromJsObject(super.jsObject) : super.fromJsObject();
}
