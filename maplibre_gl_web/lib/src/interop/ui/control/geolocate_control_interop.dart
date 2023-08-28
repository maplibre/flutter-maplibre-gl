@JS('maplibregl')
library mapboxgl.interop.ui.control.geolocate_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

@JS()
@anonymous
class GeolocateControlOptionsJsImpl {
  external PositionOptionsJsImpl get positionOptions;

  external dynamic get fitBoundsOptions;

  external bool get trackUserLocation;

  external bool get showAccuracyCircle;

  external bool get showUserLocation;

  external factory GeolocateControlOptionsJsImpl({
    PositionOptionsJsImpl? positionOptions,
    dynamic fitBoundsOptions,
    bool? trackUserLocation,
    bool? showAccuracyCircle,
    bool? showUserLocation,
  });
}

@JS()
@anonymous
class PositionOptionsJsImpl {
  external bool get enableHighAccuracy;

  external num get maximumAge;

  external num get timeout;

  external factory PositionOptionsJsImpl({
    bool? enableHighAccuracy,
    num? maximumAge,
    num? timeout,
  });
}

@JS('GeolocateControl')
abstract class GeolocateControlJsImpl extends EventedJsImpl {
  external GeolocateControlOptionsJsImpl get options;

  external factory GeolocateControlJsImpl(
      GeolocateControlOptionsJsImpl options);

  external onAdd(MapboxMapJsImpl map);

  external onRemove(MapboxMapJsImpl map);

  external trigger();
}
