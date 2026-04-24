@JS()
library;

import 'dart:js_interop';

/// This class is a wrapper for the jsObject. All the specific JsObject
/// wrappers extend from it.
abstract class JsObjectWrapper<T> {
  /// JS object.
  final T jsObject;

  /// Creates a new JsObjectWrapper type from a [jsObject].
  JsObjectWrapper.fromJsObject(this.jsObject);
}

@JS('Object.keys')
external JSArray<JSString> _objectKeysJs(JSAny? obj);

/// Returns the keys of a JavaScript object as a Dart List&lt;String&gt;.
List<String> objectKeys(Object? obj) {
  if (obj == null) return [];
  final jsObj = obj as JSAny;
  return _objectKeysJs(jsObj).toDart.map((key) => key.toDart).toList();
}

/// Extension type to add property getter/setter to JSObject.
extension type JSObjectExt._(JSObject _) implements JSObject {
  external JSAny? operator [](String property);
  external void operator []=(String property, JSAny? value);
}

/// Helper function to get a property from a JavaScript object.
JSAny? getJsProperty(JSObject obj, String propertyName) {
  return (obj as JSObjectExt)[propertyName];
}

/// Helper function to set a property on a JavaScript object.
void setJsProperty(JSObject obj, String propertyName, JSAny? value) {
  (obj as JSObjectExt)[propertyName] = value;
}

/// Creates an empty JavaScript object literal equivalent to `{}`.
@JS('Object')
external JSObject _newJsObject();

/// Helper function to create an empty JavaScript object.
///
/// Returns `Object()` — a plain `{}` with `Object.prototype` on its chain,
/// so prototype methods like `hasOwnProperty` are available.
///
/// Previously this used `Object.create(null)` (a null-prototype object).
/// It was changed during the MapLibre GL JS v5 migration in #761 because
/// the null-prototype variant caused "missing prototype" failures via
/// interop. If a null-prototype / dictionary-style object is ever needed
/// (e.g. for untrusted keys), add a separate helper rather than altering
/// this one.
JSObject createJsObject() {
  return _newJsObject();
}

/// Parse a JSON string using JavaScript's native JSON.parse.
@JS('JSON.parse')
external JSAny jsonParse(String text);
