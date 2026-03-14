import 'dart:js_interop';

import 'package:maplibre_gl_web/src/geo/geojson.dart';
import 'package:maplibre_gl_web/src/geo/lng_lat.dart';
import 'package:maplibre_gl_web/src/geo/point.dart';
import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/control/geolocate_control.dart';

typedef Listener = dynamic Function(Event object);
typedef GeoListener = dynamic Function(dynamic object);
typedef LayerEventListener = dynamic Function(Event object, String layerId);

/// Dart wrapper around MapLibre GL JS v5+ Subscription object.
/// Allows unsubscribing from events without storing the listener reference.
class Subscription extends JsObjectWrapper<SubscriptionJsImpl> {
  final void Function()? _onUnsubscribe;

  /// Removes the event listener associated with this subscription.
  void unsubscribe() {
    jsObject.unsubscribe();
    _onUnsubscribe?.call();
  }

  Subscription.fromJsObject(super.jsObject, {void Function()? onUnsubscribe})
    : _onUnsubscribe = onUnsubscribe,
      super.fromJsObject();
}

class Event extends JsObjectWrapper<EventJsImpl> {
  String get id => jsObject.id;

  String get type => jsObject.type;

  LngLat get lngLat => LngLat.fromJsObject(jsObject.lngLat);

  List<Feature> get features {
    final jsFeatures = jsObject.features;
    if (jsFeatures == null) return [];
    // Convert JSAny to List using casting
    final list = (jsFeatures as JSArray).toDart;
    return list.nonNulls
        .map((f) => Feature.fromJsObject(f as FeatureJsImpl))
        .toList();
  }

  Point get point => Point.fromJsObject(jsObject.point);

  factory Event({
    String? id,
    String? type,
    required LngLat lngLat,
    required List<Feature> features,
    required Point point,
  }) {
    final jsFeatures = features.map((f) => f.jsObject).toList().jsify();
    return Event.fromJsObject(
      EventJsImpl(
        id: id,
        type: type,
        lngLat: lngLat.jsObject,
        features: jsFeatures,
        point: point.jsObject,
      ),
    );
  }

  preventDefault() => jsObject.preventDefault();

  /// Creates a new Event from a [jsObject].
  Event.fromJsObject(super.jsObject) : super.fromJsObject();
}

class Evented extends JsObjectWrapper<EventedJsImpl> {
  /// Store listener references so `off` can use the same one.
  /// Key is a composite of (eventType, layerIdOrListener.hashCode?, listener.hashCode)
  final _listeners = <String, JSFunction>{};

  /// Build a composite key (eventType::layerId::listenerHashCode).
  String _listenerKey(
    String type,
    dynamic layerIdOrListener,
    LayerEventListener? listener,
  ) {
    return '$type::${layerIdOrListener?.hashCode}::${listener?.hashCode}';
  }

  ///  Adds a listener to a specified event type.
  ///
  ///  @param {string} type The event type to add a listen for.
  ///  @param {Function} listener The function to be called when the event is fired.
  ///    The listener function is called with the data object passed to `fire`,
  ///    extended with `target` and `type` properties.
  ///  @returns {Subscription} A subscription that can be used to unsubscribe.
  Subscription on(
    String type, [
    dynamic layerIdOrListener,
    LayerEventListener? listener,
  ]) {
    final JSFunction jsFn;
    final SubscriptionJsImpl sub;
    if (this is GeolocateControl && layerIdOrListener is GeoListener) {
      jsFn =
          ((JSAny position) {
            layerIdOrListener(position);
          }).toJS;
      sub = jsObject.on(type, jsFn);
    } else if (layerIdOrListener is Listener) {
      jsFn =
          ((EventJsImpl object) {
            layerIdOrListener(Event.fromJsObject(object));
          }).toJS;
      sub = jsObject.on(type, jsFn);
    } else {
      jsFn =
          ((EventJsImpl object) {
            listener!(Event.fromJsObject(object), layerIdOrListener);
          }).toJS;
      final layerId =
          layerIdOrListener is String
              ? layerIdOrListener.toJS
              : layerIdOrListener.toString().toJS;
      sub = jsObject.on(type, layerId, jsFn);
    }

    final key = _listenerKey(type, layerIdOrListener, listener);
    _listeners[key] = jsFn;
    final subscription = Subscription.fromJsObject(
      sub,
      onUnsubscribe: () {
        _listeners.remove(key);
      },
    );

    return subscription;
  }

  ///  Removes a previously registered event listener.
  ///
  ///  @param {string} type The event type to remove listeners for.
  ///  @param {Function} listener The listener function to remove.
  void off(
    String type, [
    dynamic layerIdOrListener,
    LayerEventListener? listener,
  ]) {
    final key = _listenerKey(type, layerIdOrListener, listener);
    final jsFn = _listeners.remove(key);

    if (layerIdOrListener is Listener || layerIdOrListener is GeoListener) {
      jsObject.off(type, jsFn);
    } else {
      final layerId =
          layerIdOrListener is String
              ? layerIdOrListener.toJS
              : layerIdOrListener.toString().toJS;
      jsObject.off(type, layerId, jsFn);
    }
  }

  ///  Adds a listener that will be called only once to a specified event type.
  ///
  ///  The listener will be called first time the event fires after the listener is registered.
  ///
  ///  @param {string} type The event type to listen for.
  ///  @param {Function} listener The function to be called when the event is fired the first time.
  ///  @returns {Subscription} A subscription that can be used to unsubscribe.
  Subscription once(String type, Listener listener) {
    final sub = jsObject.once(
      type,
      ((EventJsImpl object) {
        listener(Event.fromJsObject(object));
      }).toJS,
    );
    return Subscription.fromJsObject(sub);
  }

  fire(Event event, [JSAny? properties]) =>
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
