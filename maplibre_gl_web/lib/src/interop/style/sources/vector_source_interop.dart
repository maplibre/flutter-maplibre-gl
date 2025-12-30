@JS('maplibregl')
library;

import 'dart:js_interop';

extension type VectorSourceJsImpl._(JSObject _) implements JSObject {
  external String get url;
  external JSArray<JSString> get tiles;
  external factory VectorSourceJsImpl({
    String? type,
    String? url,
    JSArray<JSString>? tiles,
  });
}
