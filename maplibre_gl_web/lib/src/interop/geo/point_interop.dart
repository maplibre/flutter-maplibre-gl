@JS('maplibregl')
library;

import 'package:js/js.dart';

@JS()
@anonymous
class PointJsImpl {
  external num get x;
  external num get y;

  external factory PointJsImpl({
    num x,
    num y,
  });
}
