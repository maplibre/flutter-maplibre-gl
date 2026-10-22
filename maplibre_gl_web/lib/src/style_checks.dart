import 'package:flutter/services.dart';

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
/// Native needs to build it: a url or tiles, the GeoJSON data, or the media
/// url and four corners.
bool canBuildSource(String? type, Map<String, dynamic> properties) {
  switch (type) {
    case 'vector':
    case 'raster':
    case 'raster-dem':
      return properties['url'] is String || properties['tiles'] is List;
    case 'geojson':
      return properties['data'] != null;
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
