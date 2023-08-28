@JS('maplibregl')
library mapboxgl.interop.style.style_image;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';

@JS()
@anonymous
abstract class StyleImageJsImpl {
  external dynamic get data;

  external num get pixelRatio;

  external bool get sdf;

  external num get version;

  external bool get hasRenderCallback;

  external StyleImageInterfaceJsImpl get userImage;
}

@JS()
@anonymous
abstract class StyleImageInterfaceJsImpl {
  external num get width;

  external num get height;

  external dynamic get data;

  external Function get render;

  external Function(MapboxMapJsImpl map, String id) get onAdd;

  external Function get onRemove;
}
