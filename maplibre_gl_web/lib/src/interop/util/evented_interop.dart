@JS('maplibregl')
library;

import 'dart:js_interop';
import 'package:maplibre_gl_web/src/interop/geo/lng_lat_interop.dart';
import 'package:maplibre_gl_web/src/interop/geo/point_interop.dart';

typedef ListenerJsImpl = JSFunction;

/// A subscription returned by `on()` / `once()` in MapLibre GL JS v5+.
/// Call [unsubscribe] to remove the listener without needing the original
/// function reference.
@JS()
@staticInterop
class SubscriptionJsImpl {}

extension SubscriptionJsImplExtension on SubscriptionJsImpl {
  /// Removes the event listener associated with this subscription.
  external void unsubscribe();
}

@JS()
@staticInterop
@anonymous
class EventJsImpl {
  external factory EventJsImpl({
    String? id,
    String? type,
    LngLatJsImpl? lngLat,
    JSAny? features,
    PointJsImpl? point,
  });
}

extension EventJsImplExtension on EventJsImpl {
  external String get id;
  external String get type;
  external LngLatJsImpl get lngLat;
  external JSAny? get features;
  external PointJsImpl get point;
  external void preventDefault();
}

@JS('Evented')
@staticInterop
class EventedJsImpl {}

extension EventedJsImplExtension on EventedJsImpl {
  ///  Adds a listener to a specified event type.
  ///
  ///  @param {string} type The event type to add a listen for.
  ///  @param {Function} listener The function to be called when the event is fired.
  ///    The listener function is called with the data object passed to `fire`,
  ///    extended with `target` and `type` properties.
  ///  @returns {Subscription} A subscription that can be used to unsubscribe.
  external SubscriptionJsImpl on(
    String type, [
    JSAny? layerIdOrListener,
    ListenerJsImpl? listener,
  ]);

  ///  Removes a previously registered event listener.
  ///
  ///  @param {string} type The event type to remove listeners for.
  ///  @param {Function} listener The listener function to remove.
  ///  @returns {Subscription} A subscription that can be used to unsubscribe.
  external SubscriptionJsImpl off(
    String type, [
    JSAny? layerIdOrListener,
    ListenerJsImpl? listener,
  ]);

  ///  Adds a listener that will be called only once to a specified event type.
  ///
  ///  The listener will be called first time the event fires after the listener is registered.
  ///
  ///  @param {string} type The event type to listen for.
  ///  @param {Function} listener The function to be called when the event is fired the first time.
  ///  @returns {Subscription} A subscription that can be used to unsubscribe.
  external SubscriptionJsImpl once(String type, ListenerJsImpl listener);

  external void fire(EventJsImpl event, [JSAny? properties]);

  ///  Returns a true if this instance of Evented or any forwardeed instances of Evented have a listener for the specified type.
  ///
  ///  @param {string} type The event type
  ///  @returns {boolean} `true` if there is at least one registered listener for specified event type, `false` otherwise
  ///  @private
  external bool listens(String type);

  ///  Bubble all events fired by this instance of Evented to this parent instance of Evented.
  ///
  ///  @private
  ///  @returns {Object} `this`
  ///  @private
  external void setEventedParent([EventedJsImpl? parent, JSAny? data]);
}
