@JS('maplibregl')
library;

import 'dart:js_interop';

@JS()
@staticInterop
@anonymous
class PointJsImpl {
  external factory PointJsImpl({
    num x,
    num y,
  });
}

extension PointJsImplExtension on PointJsImpl {
  external num get x;
  external num get y;
}
