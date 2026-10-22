package org.maplibre.maplibregl;

import androidx.annotation.Nullable;
import java.util.List;
import java.util.Map;
import org.maplibre.android.style.sources.GeoJsonSource;
import org.maplibre.android.style.sources.ImageSource;
import org.maplibre.android.style.sources.RasterDemSource;
import org.maplibre.android.style.sources.RasterSource;
import org.maplibre.android.style.sources.Source;
import org.maplibre.android.style.sources.VectorSource;

/** Checks of the map calls, with the codes and messages shared with iOS and web. */
final class StyleChecks {
  private StyleChecks() {}

  static final String UNSUPPORTED_SOURCE_TYPE = "UNSUPPORTED_SOURCE_TYPE";
  static final String INVALID_EXPRESSION = "INVALID_EXPRESSION";
  static final String INVALID_ARGUMENT = "INVALID_ARGUMENT";
  static final String SOURCE_LAYER_REQUIRED = "SOURCE_LAYER_REQUIRED";
  static final String STYLE_NOT_READY = "STYLE_NOT_READY";
  static final String STYLE_NOT_READY_MESSAGE =
      "Style is null or not fully loaded. Has onStyleLoaded() already been invoked?";

  /** The message of a coordinate that is NaN or infinite, which MapLibre cannot place. */
  static final String NON_FINITE_COORDINATES = "Latitude and longitude must be finite numbers.";

  /** The message of a latitude beyond the poles. */
  static final String LATITUDE_OUT_OF_RANGE = "Latitude must be within -90 and 90.";

  /** The message of a screen point that is NaN or infinite. */
  static final String NON_FINITE_SCREEN_POINT = "Screen coordinates must be finite numbers.";

  /** The message of a camera update with a zoom, angle, offset or padding that is not finite. */
  static final String NON_FINITE_CAMERA_VALUES =
      "Zoom, bearing, tilt, offsets and padding must be finite numbers.";

  /** The lowest and highest zoom a layer can have. */
  static final double MIN_ZOOM = 0;

  static final double MAX_ZOOM = 24;

  /** The message of a camera padding that does not fit in the 32 bits the engine takes. */
  static String paddingOutOfRange(long padding) {
    return "Padding " + padding + " does not fit in 32 bits.";
  }

  /** Whether {@code a} and {@code b}, such as a latitude and a longitude, are finite. */
  static boolean isFinite(double a, double b) {
    return !Double.isNaN(a) && !Double.isInfinite(a) && !Double.isNaN(b) && !Double.isInfinite(b);
  }

  /** The message of a source that cannot be built from the properties it was given. */
  static String unbuildableSource(String sourceId, String type) {
    return "Source '" + sourceId + "' cannot be built from its properties as a '" + type
        + "' source.";
  }

  /**
   * The message of a call made on a source that is not GeoJSON. {@code methodName} is the Dart
   * method, and {@code clustered} tells whether it needs a clustered source.
   */
  static String notGeoJsonSource(String sourceId, String methodName, boolean clustered) {
    return "Source '" + sourceId + "' is not a GeoJSON source. " + methodName
        + " only applies to " + (clustered ? "clustered " : "") + "GeoJSON sources.";
  }

  /** The message of a layer on a vector source that names no source layer. */
  static String sourceLayerRequired(String layerId, String sourceId) {
    return "Source '" + sourceId + "' is a vector source, so layer '" + layerId
        + "' requires a 'sourceLayer'.";
  }

  /** Whether {@code minzoom} and {@code maxzoom}, each null when not set, are within 0 and 24. */
  static boolean isZoomInRange(@Nullable Double minzoom, @Nullable Double maxzoom) {
    return (minzoom == null || (minzoom >= MIN_ZOOM && minzoom <= MAX_ZOOM))
        && (maxzoom == null || (maxzoom >= MIN_ZOOM && maxzoom <= MAX_ZOOM));
  }

  /** The message of a layer add with a zoom outside 0 to 24. */
  static String zoomOutOfRange(String layerId) {
    return "The minzoom and maxzoom of layer '" + layerId + "' must be within 0 and 24.";
  }

  /** The style-spec type of {@code source}, or null for a source the style spec has no type for. */
  @Nullable
  static String sourceType(Source source) {
    if (source instanceof GeoJsonSource) {
      return "geojson";
    }
    if (source instanceof VectorSource) {
      return "vector";
    }
    if (source instanceof RasterDemSource) {
      return "raster-dem";
    }
    if (source instanceof RasterSource) {
      return "raster";
    }
    if (source instanceof ImageSource) {
      return "image";
    }
    return null;
  }

  /**
   * Whether a layer of {@code layerType} can draw a source of {@code sourceType}: a layer draws the
   * kind of tile its source makes, and the engine refuses any other pair.
   */
  static boolean canDraw(String layerType, String sourceType) {
    switch (layerType) {
      case "fill":
      case "line":
      case "symbol":
      case "circle":
      case "heatmap":
      case "fill-extrusion":
        return sourceType.equals("geojson") || sourceType.equals("vector");
      case "raster":
        return sourceType.equals("raster") || sourceType.equals("image");
      case "hillshade":
      case "color-relief":
        return sourceType.equals("raster-dem");
      default:
        return true;
    }
  }

  /** The message of a layer whose type cannot draw the type of its source. */
  static String incompatibleSource(
      String layerId, String layerType, String sourceId, String sourceType) {
    return "Layer '"
        + layerId
        + "' of type '"
        + layerType
        + "' cannot use source '"
        + sourceId
        + "' of type '"
        + sourceType
        + "'.";
  }

  /** The message of a video source, which MapLibre Native does not have. */
  static String videoSource(String sourceId) {
    return "Source '" + sourceId + "' is a video source. Video sources are only supported on web.";
  }

  /** Whether {@code properties} give an image source a url and four [lng, lat] corners. */
  static boolean isImageSource(Map<String, Object> properties) {
    final Object url = properties.get("url");
    if (!(url instanceof String) || ((String) url).isEmpty()) {
      return false;
    }
    final Object coordinates = properties.get("coordinates");
    if (!(coordinates instanceof List) || ((List<?>) coordinates).size() != 4) {
      return false;
    }
    for (Object corner : (List<?>) coordinates) {
      if (!(corner instanceof List) || ((List<?>) corner).size() != 2) {
        return false;
      }
      final Object longitude = ((List<?>) corner).get(0);
      final Object latitude = ((List<?>) corner).get(1);
      if (!(longitude instanceof Number) || !(latitude instanceof Number)) {
        return false;
      }
      final double lng = ((Number) longitude).doubleValue();
      final double lat = ((Number) latitude).doubleValue();
      if (Double.isNaN(lng) || Double.isInfinite(lng) || !(lat >= -90 && lat <= 90)) {
        return false;
      }
    }
    return true;
  }

  /**
   * Whether {@code value}, a layer property value, is an expression: an array that starts with a
   * string. It decides between INVALID_EXPRESSION and INVALID_ARGUMENT.
   */
  static boolean isExpression(@Nullable Object value) {
    return value instanceof List
        && !((List<?>) value).isEmpty()
        && ((List<?>) value).get(0) instanceof String;
  }

  /** The code of a property value the engine rejects. */
  static String invalidPropertyCode(@Nullable Object value) {
    return isExpression(value) ? INVALID_EXPRESSION : INVALID_ARGUMENT;
  }

  /**
   * Why {@code value} of {@code property} is not a color, or null. Only a hex color is checked: the
   * engine reads one with digits that are not hex, such as #ggg, as black, where iOS and web reject
   * it.
   */
  @Nullable
  static String hexColorError(String property, @Nullable Object value) {
    if (!property.endsWith("-color") || !(value instanceof String)) {
      return null;
    }
    final String color = ((String) value).replace(" ", "");
    if (!color.startsWith("#")) {
      return null;
    }
    final int digits = color.length() - 1;
    boolean valid = digits == 3 || digits == 4 || digits == 6 || digits == 8;
    for (int i = 1; valid && i < color.length(); i++) {
      final char c = Character.toLowerCase(color.charAt(i));
      valid = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f');
    }
    return valid ? null : "Could not parse color from value '" + value + "'.";
  }

  /** The message of a property value the engine rejects, with the reason it gave. */
  static String invalidProperty(
      String layerId, String property, @Nullable Object value, String reason) {
    return (isExpression(value) ? "Invalid expression" : "Invalid value")
        + " for property '"
        + property
        + "' of layer '"
        + layerId
        + "': "
        + reason;
  }

  /** The reason in {@code logged}, the engine's "name reason" line about {@code property}. */
  static String propertyReason(String logged, String property) {
    String reason = logged.trim();
    if (reason.startsWith(property)) {
      reason = reason.substring(property.length()).trim();
    }
    return reason.isEmpty() ? "MapLibre rejected the value." : reason;
  }
}
