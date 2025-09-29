@JS('maplibregl')
library;

import 'package:js/js.dart';

@JS()
@anonymous
class VectorSourceJsImpl {
  external String get url;
  external List<String> get tiles;
  external factory VectorSourceJsImpl({
    String? type,
    String? url,
    List<String>? tiles,
  });
}
