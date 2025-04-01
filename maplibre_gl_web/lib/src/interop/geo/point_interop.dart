@JS('maplibregl')
library maplibre.interop.geo.point;

import 'package:js/js.dart';

@JS()
@anonymous
class PointJsImpl {
  external factory PointJsImpl({
    num x,
    num y,
  });
  external num get x;
  external num get y;
}
