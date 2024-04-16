import 'package:js/js_util.dart' as util;
import 'interop/js.dart' as js;

/// Returns Dart representation from JS Object.
dynamic dartify(Object? jsObject) {
  if (_isBasicType(jsObject)) {
    return jsObject;
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
  var keys = js.objectKeys(jsObject);
  var map = <String, dynamic>{};
  for (var key in keys) {
    map[key] = dartify(util.getProperty(jsObject!, key));
  }
  return map;
}
