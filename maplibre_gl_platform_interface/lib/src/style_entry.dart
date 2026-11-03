part of '../maplibre_gl_platform_interface.dart';

/// Normalizes a style entry (a layer or a source, in MapLibre style-spec form)
/// into the one shape [MapLibrePlatform.getLayerProperties] and
/// [MapLibrePlatform.getSourceProperties] promise on every platform.
///
/// The problem this solves is that JavaScript has a single number type. A style
/// that writes `4` and one that writes `4.0` are the same value in the browser,
/// so the web implementation cannot report the difference the native platforms
/// report: there, the SDK hands back JSON and `jsonDecode` turns `4` into an int
/// and `1.0` into a double. Reading `properties['minzoom'] as int` therefore
/// worked on Android and iOS and threw in the browser, and normalizing only the
/// web side would have moved the same breakage onto `1.0`.
///
/// So both sides are normalized instead, to what the browser can actually
/// represent: every integral number becomes an int, and only genuinely
/// fractional ones stay doubles. `minzoom` reads as an int everywhere, and a
/// `fill-opacity` of `1.0` reads as an int everywhere too, which is why callers
/// should read numbers as `num` rather than `int` or `double`.
Map<String, dynamic> shapeStyleProperties(Map<dynamic, dynamic> entry) =>
    entry.map(
      (key, dynamic value) => MapEntry(key.toString(), _shapeStyleValue(value)),
    );

Object? _shapeStyleValue(Object? value) {
  if (value is double) {
    return value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : value;
  }
  if (value is List) return value.map(_shapeStyleValue).toList();
  if (value is Map) {
    return value.map(
      (key, dynamic child) => MapEntry(key, _shapeStyleValue(child)),
    );
  }
  return value;
}
