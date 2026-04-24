import 'package:maplibre_gl_web/src/interop/interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

/// Dart wrapper around [ScaleControlOptionsJsImpl].
class ScaleControlOptions extends JsObjectWrapper<ScaleControlOptionsJsImpl> {
  /// Maximum width of the scale control in pixels.
  num get maxWidth => jsObject.maxWidth;

  /// Unit of the distance (e.g. "metric", "imperial", or "nautical").
  String get unit => jsObject.unit;

  factory ScaleControlOptions({
    num? maxWidth,
    String? unit,
  }) {
    return ScaleControlOptions.fromJsObject(
      ScaleControlOptionsJsImpl(
        maxWidth: maxWidth,
        unit: unit,
      ),
    );
  }

  /// Create a new [ScaleControlOptions] from a [jsObject].
  ScaleControlOptions.fromJsObject(super.jsObject) : super.fromJsObject();
}

/// Dart wrapper around [ScaleControlJsImpl].
///
/// Displays the ratio of a distance on the map to the corresponding distance
/// on the ground. You can change units dynamically via [setUnit].
class ScaleControl extends JsObjectWrapper<ScaleControlJsImpl> {
  /// Access to the underlying JS options, or null if created with defaults.
  ScaleControlOptions? get options {
    final opts = jsObject.options;
    return opts != null ? ScaleControlOptions.fromJsObject(opts) : null;
  }

  /// Creates a new ScaleControl with the given [options].
  factory ScaleControl(ScaleControlOptions options) {
    return ScaleControl.fromJsObject(
      ScaleControlJsImpl(options.jsObject),
    );
  }

  /// Create a [ScaleControl] from an existing [ScaleControlJsImpl].
  ScaleControl.fromJsObject(super.jsObject) : super.fromJsObject();

  /// Add this control to the given [map].
  dynamic onAdd(MapLibreMap map) => jsObject.onAdd(map.jsObject);

  /// Remove this control from the map.
  dynamic onRemove() => jsObject.onRemove();

  /// Return the default position for this control ("bottom-left").
  String getDefaultPosition() => jsObject.getDefaultPosition();

  /// Set the scale’s unit of distance (e.g. "imperial", "metric", "nautical").
  void setUnit(String unit) => jsObject.setUnit(unit);
}
