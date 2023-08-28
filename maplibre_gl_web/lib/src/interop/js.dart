@JS()
library mapboxgl.interop.js;

import 'package:js/js.dart';

/// This class is a wrapper for the jsObject. All the specific JsObject
/// wrappers extend from it.
abstract class JsObjectWrapper<T> {
  /// JS object.
  final T jsObject;

  /// Creates a new JsObjectWrapper type from a [jsObject].
  JsObjectWrapper.fromJsObject(this.jsObject);
}

@JS('Object.keys')
external List<String> objectKeys(Object? obj);
