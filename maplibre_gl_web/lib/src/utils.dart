import 'dart:convert';
import 'dart:js_interop';

import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show jsonValueOf;

import 'interop/js.dart';

/// Returns Dart representation from JS Object.
dynamic dartify(Object? jsObject) {
  if (_isBasicType(jsObject)) {
    return jsObject;
  }

  // Convert JSAny types to Dart primitives
  // ignore: invalid_runtime_check_with_js_interop_types
  if (jsObject is JSAny) {
    if (jsObject.isA<JSBoolean>()) {
      return (jsObject as JSBoolean).toDart;
    }

    if (jsObject.isA<JSNumber>()) {
      return (jsObject as JSNumber).toDartDouble;
    }

    if (jsObject.isA<JSString>()) {
      return (jsObject as JSString).toDart;
    }

    // Handle a JS array. Asking the JS side rather than relying on the Dart
    // check below, which only answers true when compiling to JavaScript: there
    // a JS array is a Dart List, while under dart2wasm it is a boxed JSValue
    // that would fall through to dartifyMap and come back as {'0': ...}.
    if (jsObject.isA<JSArray>()) {
      return (jsObject as JSArray).toDart.map(dartify).toList();
    }
  }

  // Handle list
  if (jsObject is Iterable) {
    return jsObject.map(dartify).toList();
  }

  // Assume a map then...
  return dartifyMap(jsObject);
}

/// Returns `true` if the [value] is a very basic built-in type - e.g.
/// `null`, [num], [bool] or [String]. It returns `false` in the other case.
bool _isBasicType(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return true;
  }
  return false;
}

Map<String, dynamic> dartifyMap(Object? jsObject) {
  if (jsObject == null) return {};

  final keys = objectKeys(jsObject);
  final map = <String, dynamic>{};
  for (final key in keys) {
    final value = getJsProperty(jsObject as JSObject, key);
    map[key] = dartify(value);
  }
  return map;
}

/// Converts a Dart object to a JavaScript object.
JSAny? jsify(Object? dartObject) {
  if (dartObject == null) return null;
  if (dartObject is String) return dartObject.toJS;
  if (dartObject is num) return dartObject.toJS;
  if (dartObject is bool) return dartObject.toJS;
  if (dartObject is List) {
    final jsArray = dartObject.map((e) => jsify(e)).toList();
    return jsArray.toJS;
  }
  if (dartObject is Map) {
    return jsifyMap(Map<String, dynamic>.from(dartObject));
  }
  // For objects that already have jsObject property (like Layer, Source wrappers)
  if (dartObject is JsObjectWrapper) {
    return dartObject.jsObject as JSAny;
  }
  // Fallback: assume it's already a JSAny
  return dartObject as JSAny?;
}

/// Converts a Dart Map to a JavaScript object.
/// Null values are omitted to avoid MapLibre GL JS style validation errors.
JSObject jsifyMap(Map<String, dynamic> map) {
  final jsObj = createJsObject();
  map.forEach((key, value) {
    if (value == null) return;
    final jsValue = jsify(value);
    setJsProperty(jsObj, key, jsValue);
  });
  return jsObj;
}

/// Converts [value], JSON data from Dart, to a JS value the way `jsonEncode`
/// writes it for Android and iOS: an object other than a map, list, string,
/// number, bool or null goes in as what its `toJson()` returns. Map entries
/// that are null are left out, as [jsifyMap] does.
///
/// Throws a [JsonUnsupportedObjectError] for what `jsonEncode` cannot write,
/// a number that is not finite included.
JSAny? jsifyJson(Object? value) {
  final json = jsonValueOf(value);
  if (json == null) return null;
  if (json is String) return json.toJS;
  if (json is bool) return json.toJS;
  if (json is num) {
    if (json.isFinite) return json.toJS;
    throw JsonUnsupportedObjectError(json);
  }
  if (json is List) return [for (final item in json) jsifyJson(item)].toJS;
  if (json is Map) {
    final object = createJsObject();
    for (final MapEntry(:key, value: item) in json.entries) {
      if (key is! String) throw JsonUnsupportedObjectError(json);
      if (item != null) setJsProperty(object, key, jsifyJson(item));
    }
    return object;
  }
  throw JsonUnsupportedObjectError(value);
}
