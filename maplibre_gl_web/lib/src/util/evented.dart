import 'dart:js';

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/geo/point.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/control/geolocate_control.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

typedef Listener = dynamic Function(Event object);
typedef GeoListener = dynamic Function(dynamic object);
typedef LayerEventListener = dynamic Function(Event object, String layerId);

class Event extends JsObjectWrapper<EventJsImpl> {
  String get id => jsObject.id;

  String get type => jsObject.type;

  LngLat get lngLat => LngLat.fromJsObject(jsObject.lngLat);

  List<Feature> get features =>
      jsObject.features?.map((dynamic f) => Feature.fromJsObject(f)).toList() ??
      [];

  Point get point => Point.fromJsObject(jsObject.point);

  factory Event({
    String? id,
    String? type,
    required LngLat lngLat,
    required List<Feature> features,
    required Point point,
  }) =>
      Event.fromJsObject(EventJsImpl(
        id: id,
        type: type,
        lngLat: lngLat.jsObject,
        features: features.map((dynamic f) => f.jsObject).toList()
            as List<FeatureJsImpl?>?,
        point: point.jsObject,
      ));

  preventDefault() => jsObject.preventDefault();

  /// Creates a new Event from a [jsObject].
  Event.fromJsObject(super.jsObject) : super.fromJsObject();
}

class Evented extends JsObjectWrapper<EventedJsImpl> {
  /// Store listener references so `off` can use the same one.
  /// Key is a composite of (eventType, layerIdOrListener.hashCode?, listener.hashCode)
  final _listeners = <String, dynamic>{};

  /// Build a composite key (eventType::layerId::listenerHashCode).
  String _listenerKey(
      String type, dynamic layerIdOrListener, LayerEventListener? listener) {
    return '$type::${layerIdOrListener?.hashCode}::${listener?.hashCode}';
  }

  ///  Adds a listener to a specified event type.
  ///
  ///  @param {string} type The event type to add a listen for.
  ///  @param {Function} listener The function to be called when the event is fired.
  ///    The listener function is called with the data object passed to `fire`,
  ///    extended with `target` and `type` properties.
  ///  @returns {Object} `this`
  MapLibreMap on(String type,
      [dynamic layerIdOrListener, LayerEventListener? listener]) {
    final ListenerJsImpl jsFn;
    final MapLibreMapJsImpl mapJsImpl;
    if (this is GeolocateControl && layerIdOrListener is GeoListener) {
      jsFn = allowInterop(
        (dynamic position) {
          layerIdOrListener(position);
        },
      );
      mapJsImpl = jsObject.on(type, jsFn);
    } else if (layerIdOrListener is Listener) {
      jsFn = allowInterop(
        (EventJsImpl object) {
          layerIdOrListener(Event.fromJsObject(object));
        },
      );
      mapJsImpl = jsObject.on(type, jsFn);
    } else {
      jsFn = allowInterop((EventJsImpl object) {
        listener!(Event.fromJsObject(object), layerIdOrListener);
      });
      mapJsImpl = jsObject.on(type, layerIdOrListener, jsFn);
    }

    _listeners[_listenerKey(type, layerIdOrListener, listener)] = jsFn;

    return MapLibreMap.fromJsObject(mapJsImpl);
  }

  ///  Removes a previously registered event listener.
  ///
  ///  @param {string} type The event type to remove listeners for.
  ///  @param {Function} listener The listener function to remove.
  ///  @returns {Object} `this`
  MapLibreMap off(String type,
      [dynamic layerIdOrListener, LayerEventListener? listener]) {
    final key = _listenerKey(type, layerIdOrListener, listener);
    final jsFn = _listeners.remove(key);
    final MapLibreMapJsImpl mapJsImpl;

    if (layerIdOrListener is Listener || layerIdOrListener is GeoListener) {
      mapJsImpl = jsObject.off(type, jsFn);
    } else {
      mapJsImpl = jsObject.off(type, layerIdOrListener, jsFn);
    }
    return MapLibreMap.fromJsObject(mapJsImpl);
  }

  ///  Adds a listener that will be called only once to a specified event type.
  ///
  ///  The listener will be called first time the event fires after the listener is registered.
  ///
  ///  @param {string} type The event type to listen for.
  ///  @param {Function} listener The function to be called when the event is fired the first time.
  ///  @returns {Object} `this`
  MapLibreMap once(String type, Listener listener) =>
      MapLibreMap.fromJsObject(jsObject.once(type, allowInterop(
        (EventJsImpl object) {
          listener(Event.fromJsObject(object));
        },
      )));

  fire(Event event, [dynamic properties]) =>
      jsObject.fire(event.jsObject, properties);

  ///  Returns a true if this instance of Evented or any forwardeed instances of Evented have a listener for the specified type.
  ///
  ///  @param {string} type The event type
  ///  @returns {boolean} `true` if there is at least one registered listener for specified event type, `false` otherwise
  ///  @private
  listens(String type) => jsObject.listens(type);

  ///  Bubble all events fired by this instance of Evented to this parent instance of Evented.
  ///
  ///  @private
  ///  @returns {Object} `this`
  ///  @private
  setEventedParent([Evented? parent, dynamic data]) =>
      jsObject.setEventedParent(parent?.jsObject, data);

  /// Creates a new Evented from a [jsObject].
  Evented.fromJsObject(super.jsObject) : super.fromJsObject();
}
