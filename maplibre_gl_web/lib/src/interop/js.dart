@JS()
library maplibre.interop.js;

import 'package:js/js.dart';

/// This class is a wrapper for the jsObject. All the specific JsObject
/// wrappers extend from it.
abstract class JsObjectWrapper<T> {
  /// Creates a new JsObjectWrapper type from a [jsObject].
  JsObjectWrapper.fromJsObject(this._jsObject);

  /// JS object.
  final T _jsObject;
  T get jsObject => _jsObject;
}

@JS('Object.keys')
external List<String> objectKeys(Object? obj);
