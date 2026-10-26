import 'package:flutter/services.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show CameraUpdate;

/// The checks the web layer and source calls make before they reach
/// maplibre-gl-js, with the codes and messages Android and iOS answer for the
/// same case.
///
/// Kept free of `dart:js_interop` so it can be unit-tested from the Dart VM.

/// Whether a layer of [layerType] can draw a source of [sourceType], by
/// MapLibre Native's rule: a layer draws the kind of tile its source makes.
/// maplibre-gl-js checks only some pairs itself.
bool canDraw(String layerType, String sourceType) {
  switch (layerType) {
    case 'fill':
    case 'line':
    case 'symbol':
    case 'circle':
    case 'heatmap':
    case 'fill-extrusion':
      return sourceType == 'geojson' || sourceType == 'vector';
    case 'raster':
      return const {'raster', 'image', 'video', 'canvas'}.contains(sourceType);
    case 'hillshade':
    case 'color-relief':
      return sourceType == 'raster-dem';
    default:
      return true;
  }
}

/// The error of a layer whose type cannot draw the type of its source.
PlatformException incompatibleSource(
  String layerId,
  String layerType,
  String sourceId,
  String sourceType,
) => PlatformException(
  code: 'UNSUPPORTED_SOURCE_TYPE',
  message:
      "Layer '$layerId' of type '$layerType' cannot use source '$sourceId' "
      "of type '$sourceType'.",
);

/// The error of a layer on the vector source [sourceId] that names no source
/// layer. maplibre-gl-js would not add it, and MapLibre Native would draw
/// nothing.
PlatformException sourceLayerRequired(String layerId, String sourceId) =>
    PlatformException(
      code: 'SOURCE_LAYER_REQUIRED',
      message:
          "Source '$sourceId' is a vector source, so layer '$layerId' "
          "requires a 'sourceLayer'.",
    );

/// Whether [minzoom] and [maxzoom] of a layer, each null when not set, are
/// within 0 and 24, the zoom levels of the style spec.
bool isZoomInRange(double? minzoom, double? maxzoom) =>
    (minzoom == null || (minzoom >= 0 && minzoom <= 24)) &&
    (maxzoom == null || (maxzoom >= 0 && maxzoom <= 24));

/// The error of a layer added with a zoom outside 0 to 24.
PlatformException zoomOutOfRange(String layerId) => PlatformException(
  code: 'INVALID_ARGUMENT',
  message:
      "The minzoom and maxzoom of layer '$layerId' must be within 0 and 24.",
);

/// The error of a layer maplibre-gl-js did not add, for [reason], the error
/// it reported, if any.
PlatformException layerNotAdded(String layerId, String? reason) =>
    PlatformException(
      code: 'INVALID_LAYER',
      message:
          reason == null
              ? "Layer '$layerId' was not added."
              : "Layer '$layerId' was not added: $reason",
      details: reason,
    );

/// The reason in [message], an error event maplibre-gl-js fired while it
/// validated the filter under [key], such as `layers.<layer id>` or
/// `queryRenderedFeatures`, or null for an error about something else.
String? filterReason(String message, String key) {
  // An index can follow the key, as in "layers.points.filter[0]: ".
  final match = RegExp(
    '^${RegExp.escape(key)}\\.filter[^:]*: ',
  ).firstMatch(message);
  return match == null ? null : message.substring(match.end);
}

/// Whether [value], a layer property value, reads as an expression: an array
/// that starts with a string. Every platform picks INVALID_EXPRESSION or
/// INVALID_ARGUMENT this way, whatever reason its engine gives.
bool isExpression(Object? value) =>
    value is List && value.isNotEmpty && value.first is String;

/// The error of a value of [property] of the layer [layerId] that MapLibre
/// rejects for [reason].
PlatformException invalidProperty(
  String layerId,
  String property,
  Object? value,
  String reason,
) {
  final expression = isExpression(value);
  return PlatformException(
    code: expression ? 'INVALID_EXPRESSION' : 'INVALID_ARGUMENT',
    message:
        '${expression ? 'Invalid expression' : 'Invalid value'} for property '
        "'$property' of layer '$layerId': $reason",
    details: reason,
  );
}

/// Whether [property] is a property of a layer of [layerType]: style-spec
/// properties are named after their layer type.
bool isPropertyOf(String layerType, String property) {
  if (property == 'visibility') return true;
  switch (layerType) {
    case 'symbol':
      return property.startsWith('symbol-') ||
          property.startsWith('icon-') ||
          property.startsWith('text-');
    case 'fill':
      return property.startsWith('fill-') &&
          !property.startsWith('fill-extrusion-');
    default:
      return property.startsWith('$layerType-');
  }
}

/// A validation error maplibre-gl-js reported for a property of a layer: the
/// property and why.
typedef PropertyError = ({String property, String reason});

final _propertyErrorKey = RegExp(
  r'^layers\..*?\.(?:paint|layout)\.([^.:\[\s]+)[^:]*: ',
);

/// The property error in [message], an error event maplibre-gl-js fired while
/// it validated a layer, or null for an error about something else.
PropertyError? propertyError(String message) {
  final match = _propertyErrorKey.firstMatch(message);
  if (match == null) return null;
  return (property: match.group(1)!, reason: message.substring(match.end));
}

/// Whether [reason], that of a [PropertyError], says maplibre-gl-js does not
/// know the property.
bool isUnknownProperty(String reason) => reason.startsWith('unknown property');

/// Whether [properties], those of a source of [type], have what MapLibre
/// Native needs to build it: a url or tiles, the GeoJSON data or its url, or
/// the media url and four corners.
///
/// The tiles of a source without a url need bounds of four finite numbers,
/// south not above north and west not east of east once the latitudes are
/// clamped to the poles, and a minzoom and maxzoom from 0 to 255, minzoom not
/// above maxzoom. An empty url counts as none.
bool canBuildSource(String? type, Map<String, dynamic> properties) {
  switch (type) {
    case 'vector':
    case 'raster':
    case 'raster-dem':
      final url = properties['url'];
      if (url is String && url.isNotEmpty) return true;
      return properties['tiles'] is List && _hasTileOptions(properties);
    case 'geojson':
      final data = properties['data'];
      return data is String ? data.isNotEmpty : data != null;
    case 'image':
      final url = properties['url'];
      return url is String && url.isNotEmpty && _hasCorners(properties);
    case 'video':
      final urls = properties['urls'];
      return urls is List &&
          urls.isNotEmpty &&
          urls.every((url) => url is String) &&
          _hasCorners(properties);
    default:
      return true;
  }
}

/// Whether the bounds and zoom levels in [properties], those of a tiled
/// source, are ones MapLibre Native takes.
bool _hasTileOptions(Map<String, dynamic> properties) {
  final bounds = properties['bounds'];
  if (bounds != null) {
    if (bounds is! List || bounds.length != 4) return false;
    if (!bounds.every((value) => value is num && value.isFinite)) return false;
    final [west as num, south as num, east as num, north as num] = bounds;
    if (south.clamp(-90, 90) > north.clamp(-90, 90) || west > east) {
      return false;
    }
  }
  final minzoom = properties['minzoom'];
  final maxzoom = properties['maxzoom'];
  for (final zoom in [minzoom, maxzoom]) {
    if (zoom != null && !(zoom is num && zoom >= 0 && zoom <= 255)) {
      return false;
    }
  }
  return !(minzoom is num && maxzoom is num && minzoom > maxzoom);
}

/// Whether `coordinates` holds four [longitude, latitude] corners, latitudes
/// within the range of the map.
bool _hasCorners(Map<String, dynamic> properties) {
  final corners = properties['coordinates'];
  if (corners is! List || corners.length != 4) return false;
  for (final corner in corners) {
    if (corner is! List || corner.length != 2) return false;
    final longitude = corner[0];
    final latitude = corner[1];
    if (longitude is! num || latitude is! num) return false;
    if (!longitude.isFinite || !(latitude >= -90 && latitude <= 90)) {
      return false;
    }
  }
  return true;
}

/// The error of a call made on the source [sourceId], which is not GeoJSON.
/// [methodName] is the Dart method, and [clustered] tells whether it needs a
/// clustered source.
PlatformException notGeoJsonSource(
  String sourceId,
  String methodName, {
  bool clustered = false,
}) => PlatformException(
  code: 'UNSUPPORTED_SOURCE_TYPE',
  message:
      "Source '$sourceId' is not a GeoJSON source. $methodName only applies "
      'to ${clustered ? 'clustered ' : ''}GeoJSON sources.',
);

/// The error of a feature state call on the source [sourceId], of the type
/// [type], which holds no feature state: only GeoJSON and vector sources do.
PlatformException notFeatureStateSource(String sourceId, String type) =>
    PlatformException(
      code: 'UNSUPPORTED_SOURCE_TYPE',
      message:
          "Source '$sourceId' is a $type source. Feature state only applies "
          'to GeoJSON and vector sources.',
    );

/// The error of a feature state call on the vector source [sourceId] that
/// names no source layer.
PlatformException featureStateSourceLayerRequired(String sourceId) =>
    PlatformException(
      code: 'SOURCE_LAYER_REQUIRED',
      message:
          "Source '$sourceId' is a vector source, so feature state calls on "
          "it require a 'sourceLayer'.",
    );

/// The error of a feature state that JSON cannot carry: a non-finite number,
/// or a value of a type JSON has no form for.
PlatformException featureStateNotJson(String sourceId, String featureId) =>
    invalidArgument(
      "The state for feature '$featureId' on source '$sourceId' is not valid "
      'JSON: it holds a non-finite number, or a value of a type JSON cannot '
      'carry.',
    );

/// Whether [value] is made of what JSON can carry: null, booleans, finite
/// numbers, strings, lists, and maps with string keys.
bool isJsonValue(Object? value) {
  if (value == null || value is bool || value is String) return true;
  if (value is num) return value.isFinite;
  if (value is List) return value.every(isJsonValue);
  if (value is Map) {
    return value.entries.every((e) => e.key is String && isJsonValue(e.value));
  }
  return false;
}

/// Why [value] of [property], a layer property, is not a color, or null. Only
/// a hex color is checked: MapLibre Native reads one with digits that are not
/// hex, such as `#ggg`, as black, where maplibre-gl-js rejects it with a
/// reason of its own.
String? hexColorError(String property, Object? value) {
  if (!property.endsWith('-color') || value is! String) return null;
  final color = value.replaceAll(' ', '');
  if (!color.startsWith('#')) return null;
  return _hexColor.hasMatch(color)
      ? null
      : "Could not parse color from value '$value'.";
}

/// A hex color as CSS writes it: #rgb, #rgba, #rrggbb or #rrggbbaa.
final _hexColor = RegExp(
  r'^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
);

/// The message of a latitude or longitude that is NaN or infinite, which
/// MapLibre cannot place.
const nonFiniteCoordinates = 'Latitude and longitude must be finite numbers.';

/// The message of a camera update with a zoom, angle, offset or padding that
/// is NaN or infinite.
const nonFiniteCameraValues =
    'Zoom, bearing, tilt, offsets and padding must be finite numbers.';

/// The message of a screen point that is NaN or infinite.
const nonFiniteScreenPoint = 'Screen coordinates must be finite numbers.';

/// The message of a latitude beyond the poles.
const latitudeOutOfRange = 'Latitude must be within -90 and 90.';

/// The message of a camera padding that does not fit in the 32 bits MapLibre
/// Native takes.
String paddingOutOfRange(int padding) =>
    'Padding $padding does not fit in 32 bits.';

/// An `INVALID_ARGUMENT` error with [message].
PlatformException invalidArgument(String message) =>
    PlatformException(code: 'INVALID_ARGUMENT', message: message);

/// Whether [a] and [b], such as a latitude and a longitude, are finite.
bool isFinite(num a, num b) => a.isFinite && b.isFinite;

/// Why [update] cannot move the camera, or null when it can: a coordinate,
/// then any other value, that is NaN or infinite.
String? cameraUpdateError(CameraUpdate update) {
  final json = update.toJson() as List;
  final coordinates = <Object?>[];
  final values = <Object?>[];
  switch (json.first) {
    case 'newCameraPosition':
      final position = json[1] as Map;
      coordinates.add(position['target']);
      values.addAll([position['bearing'], position['tilt'], position['zoom']]);
    case 'newLatLng':
      coordinates.add(json[1]);
    case 'newLatLngBounds':
      coordinates.addAll(json[1] as List);
      values.addAll(json.skip(2));
    case 'newLatLngZoom':
      coordinates.add(json[1]);
      values.add(json[2]);
    case 'zoomBy':
      values.add(json[1]);
      if (json.length > 2) values.addAll(json[2] as List);
    default:
      values.addAll(json.skip(1));
  }
  bool finite(Object? value) => value is! num || value.isFinite;
  if (!coordinates.every((latLng) => latLng is List && latLng.every(finite))) {
    return nonFiniteCoordinates;
  }
  return values.every(finite) ? null : nonFiniteCameraValues;
}
