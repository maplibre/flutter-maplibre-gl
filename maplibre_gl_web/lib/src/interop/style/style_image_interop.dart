@JS('maplibregl')
library;

import 'dart:js_interop';

@JS()
@staticInterop
abstract class StyleImageJsImpl {}

extension StyleImageJsImplExtension on StyleImageJsImpl {
  external JSAny get data;

  external num get pixelRatio;

  external bool get sdf;

  external num get version;

  external bool get hasRenderCallback;

  external StyleImageInterfaceJsImpl get userImage;
}

@JS()
@staticInterop
abstract class StyleImageInterfaceJsImpl {}

extension StyleImageInterfaceJsImplExtension on StyleImageInterfaceJsImpl {
  external num get width;

  external num get height;

  external JSAny get data;

  external JSFunction get render;

  external JSFunction get onAdd;

  external JSFunction get onRemove;
}
