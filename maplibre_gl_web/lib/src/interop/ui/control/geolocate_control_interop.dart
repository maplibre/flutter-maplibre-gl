@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/js.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';

@JS()
@staticInterop
class GeolocateControlOptionsJsImpl {
  factory GeolocateControlOptionsJsImpl() =>
      createJsObject() as GeolocateControlOptionsJsImpl;
}

extension GeolocateControlOptionsJsImplExtension
    on GeolocateControlOptionsJsImpl {
  external PositionOptionsJsImpl? get positionOptions;
  external set positionOptions(PositionOptionsJsImpl? value);

  external JSAny? get fitBoundsOptions;
  external set fitBoundsOptions(JSAny? value);

  external bool? get trackUserLocation;
  external set trackUserLocation(bool? value);

  external bool? get showAccuracyCircle;
  external set showAccuracyCircle(bool? value);

  external bool? get showUserLocation;
  external set showUserLocation(bool? value);
}

@JS()
@staticInterop
class PositionOptionsJsImpl {
  factory PositionOptionsJsImpl() => createJsObject() as PositionOptionsJsImpl;
}

extension PositionOptionsJsImplExtension on PositionOptionsJsImpl {
  external bool? get enableHighAccuracy;
  external set enableHighAccuracy(bool? value);

  external num? get maximumAge;
  external set maximumAge(num? value);

  external num? get timeout;
  external set timeout(num? value);
}

@JS('GeolocateControl')
@staticInterop
abstract class GeolocateControlJsImpl extends EventedJsImpl {
  external factory GeolocateControlJsImpl(
      [GeolocateControlOptionsJsImpl? options]);
}

extension GeolocateControlJsImplExtension on GeolocateControlJsImpl {
  external GeolocateControlOptionsJsImpl get options;

  external void onAdd(MapLibreMapJsImpl map);

  external void onRemove(MapLibreMapJsImpl map);

  external void trigger();
}
