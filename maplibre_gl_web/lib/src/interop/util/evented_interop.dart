@JS('maplibregl')
library maplibre.interop.util.evented;

import 'package:js/js.dart';
import 'package:maplibre_gl_web/src/interop/geo/geojson_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/point_interop.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';

typedef ListenerJsImpl = dynamic Function(EventJsImpl object);

@JS()
@anonymous
abstract class EventJsImpl {
  external String get id;
  external String get type;
  external LngLatJsImpl get lngLat;
  external List<FeatureJsImpl> get features;
  external PointJsImpl get point;

  external factory EventJsImpl({
    String? id,
    String? type,
    LngLatJsImpl? lngLat,
    List<FeatureJsImpl?>? features,
    PointJsImpl? point,
  });

  external preventDefault();
}

@JS('Evented')
abstract class EventedJsImpl {
  ///  Adds a listener to a specified event type.
  ///
  ///  @param {string} type The event type to add a listen for.
  ///  @param {Function} listener The function to be called when the event is fired.
  ///    The listener function is called with the data object passed to `fire`,
  ///    extended with `target` and `type` properties.
  ///  @returns {Object} `this`
  //external on(String type, Listener listener);
  external MapLibreMapJsImpl on(String type,
      [dynamic layerIdOrListener, ListenerJsImpl? listener]);

  ///  Removes a previously registered event listener.
  ///
  ///  @param {string} type The event type to remove listeners for.
  ///  @param {Function} listener The listener function to remove.
  ///  @returns {Object} `this`
  //external off(String type, Listener listener);
  external MapLibreMapJsImpl off(String type,
      [dynamic layerIdOrListener, ListenerJsImpl? listener]);

  ///  Adds a listener that will be called only once to a specified event type.
  ///
  ///  The listener will be called first time the event fires after the listener is registered.
  ///
  ///  @param {string} type The event type to listen for.
  ///  @param {Function} listener The function to be called when the event is fired the first time.
  ///  @returns {Object} `this`
  external MapLibreMapJsImpl once(String type, ListenerJsImpl listener);

  external fire(EventJsImpl event, [dynamic properties]);

  ///  Returns a true if this instance of Evented or any forwardeed instances of Evented have a listener for the specified type.
  ///
  ///  @param {string} type The event type
  ///  @returns {boolean} `true` if there is at least one registered listener for specified event type, `false` otherwise
  ///  @private
  external listens(String type);

  ///  Bubble all events fired by this instance of Evented to this parent instance of Evented.
  ///
  ///  @private
  ///  @returns {Object} `this`
  ///  @private
  external setEventedParent([EventedJsImpl? parent, dynamic data]);
}
