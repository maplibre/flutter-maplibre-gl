library maplibre.ui.control.geolocate_control;

import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/util/evented.dart';

class GeolocateControlOptions
    extends JsObjectWrapper<GeolocateControlOptionsJsImpl> {
  PositionOptions get positionOptions =>
      PositionOptions.fromJsObject(jsObject.positionOptions);
  dynamic get fitBoundsOptions => jsObject.fitBoundsOptions;
  bool get trackUserLocation => jsObject.trackUserLocation;
  bool get showAccuracyCircle => jsObject.showAccuracyCircle;
  bool get showUserLocation => jsObject.showUserLocation;

  factory GeolocateControlOptions({
    required PositionOptions positionOptions,
    dynamic fitBoundsOptions,
    bool? trackUserLocation,
    bool? showAccuracyCircle,
    bool? showUserLocation,
  }) =>
      GeolocateControlOptions.fromJsObject(GeolocateControlOptionsJsImpl(
        positionOptions: positionOptions.jsObject,
        fitBoundsOptions: fitBoundsOptions,
        trackUserLocation: trackUserLocation,
        showAccuracyCircle: showAccuracyCircle,
        showUserLocation: showUserLocation,
      ));

  /// Creates a new MapOptions from a [jsObject].
  GeolocateControlOptions.fromJsObject(GeolocateControlOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

class PositionOptions extends JsObjectWrapper<PositionOptionsJsImpl> {
  bool get enableHighAccuracy => jsObject.enableHighAccuracy;
  num get maximumAge => jsObject.maximumAge;
  num get timeout => jsObject.timeout;

  factory PositionOptions({
    bool? enableHighAccuracy,
    num? maximumAge,
    num? timeout,
  }) =>
      PositionOptions.fromJsObject(PositionOptionsJsImpl(
        enableHighAccuracy: enableHighAccuracy,
        maximumAge: maximumAge,
        timeout: timeout,
      ));

  /// Creates a new MapOptions from a [jsObject].
  PositionOptions.fromJsObject(PositionOptionsJsImpl jsObject)
      : super.fromJsObject(jsObject);
}

/// A `GeolocateControl` control provides a button that uses the browser's geolocation
/// API to locate the user on the map.
///
/// Not all browsers support geolocation,
/// and some users may disable the feature. Geolocation support for modern
/// browsers including Chrome requires sites to be served over HTTPS. If
/// geolocation support is not available, the GeolocateControl will not
/// be visible.
///
/// The zoom level applied will depend on the accuracy of the geolocation provided by the device.
///
/// The GeolocateControl has two modes. If `trackUserLocation` is `false` (default) the control acts as a button, which when pressed will set the map's camera to target the user location. If the user moves, the map won't update. This is most suited for the desktop. If `trackUserLocation` is `true` the control acts as a toggle button that when active the user's location is actively monitored for changes. In this mode the GeolocateControl has three states:
/// * active - the map's camera automatically updates as the user's location changes, keeping the location dot in the center.
/// * passive - the user's location dot automatically updates, but the map's camera does not.
/// * disabled
///
/// @implements {IControl}
/// @param {Object} [options]
/// @param {Object} [options.positionOptions={enableHighAccuracy: false, timeout: 6000}] A Geolocation API [PositionOptions](https://developer.mozilla.org/en-US/docs/Web/API/PositionOptions) object.
/// @param {Object} [options.fitBoundsOptions={maxZoom: 15}] A [`fitBounds`](#map#fitbounds) options object to use when the map is panned and zoomed to the user's location. The default is to use a `maxZoom` of 15 to limit how far the map will zoom in for very accurate locations.
/// @param {Object} [options.trackUserLocation=false] If `true` the Geolocate Control becomes a toggle button and when active the map will receive updates to the user's location as it changes.
/// @param {Object} [options.showUserLocation=true] By default a dot will be shown on the map at the user's location. Set to `false` to disable.
///
/// @example
/// map.addControl(new maplibregl.GeolocateControl({
///     positionOptions: {
///         enableHighAccuracy: true
///     },
///     trackUserLocation: true
/// }));
/// @see [Locate the user](https://maplibre.org/maplibre-gl-js/docs/examples/locate-user/)
class GeolocateControl extends Evented {
  final GeolocateControlJsImpl jsObject;
  GeolocateControlOptions get options =>
      GeolocateControlOptions.fromJsObject(jsObject.options);

  factory GeolocateControl(GeolocateControlOptions options) =>
      GeolocateControl.fromJsObject(GeolocateControlJsImpl(options.jsObject));

  onAdd(MapLibreMap map) => jsObject.onAdd(map.jsObject);

  onRemove(MapLibreMap map) => jsObject.onRemove(map.jsObject);

  /// Trigger a geolocation
  ///
  /// @returns {boolean} Returns `false` if called before control was added to a map, otherwise returns `true`.
  trigger() => jsObject.trigger();

  /// Creates a new Camera from a [jsObject].
  GeolocateControl.fromJsObject(this.jsObject) : super.fromJsObject(jsObject);
}
