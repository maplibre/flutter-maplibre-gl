@JS('maplibregl')
library maplibre.interop.ui.control.geolocate_control;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

@JS()
@anonymous
class GeolocateControlOptionsJsImpl {
  external factory GeolocateControlOptionsJsImpl({
    PositionOptionsJsImpl? positionOptions,
    dynamic fitBoundsOptions,
    bool? trackUserLocation,
    bool? showAccuracyCircle,
    bool? showUserLocation,
  });
  external PositionOptionsJsImpl get positionOptions;

  external dynamic get fitBoundsOptions;

  external bool get trackUserLocation;

  external bool get showAccuracyCircle;

  external bool get showUserLocation;
}

@JS()
@anonymous
class PositionOptionsJsImpl {
  external factory PositionOptionsJsImpl({
    bool? enableHighAccuracy,
    num? maximumAge,
    num? timeout,
  });
  external bool get enableHighAccuracy;

  external num get maximumAge;

  external num get timeout;
}

@JS('GeolocateControl')
abstract class GeolocateControlJsImpl extends EventedJsImpl {
  external factory GeolocateControlJsImpl(
    GeolocateControlOptionsJsImpl options,
  );
  external GeolocateControlOptionsJsImpl get options;

  external dynamic onAdd(MapLibreMapJsImpl map);

  external dynamic onRemove(MapLibreMapJsImpl map);

  external dynamic trigger();
}
