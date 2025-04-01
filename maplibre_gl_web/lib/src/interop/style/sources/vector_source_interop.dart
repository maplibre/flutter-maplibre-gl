@JS('maplibregl')
library maplibre.style.interop.sources.vector_source;

import 'package:js/js.dart';

@JS()
@anonymous
class VectorSourceJsImpl {
  external factory VectorSourceJsImpl({
    String? type,
    String? url,
    List<String>? tiles,
  });
  external String get url;
  external List<String> get tiles;
}
