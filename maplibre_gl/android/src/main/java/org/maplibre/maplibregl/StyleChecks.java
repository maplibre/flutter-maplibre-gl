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

/** Checks of the layer and source calls, with the codes and messages shared with iOS and web. */
final class StyleChecks {
  private StyleChecks() {}

  static final String UNSUPPORTED_SOURCE_TYPE = "UNSUPPORTED_SOURCE_TYPE";
  static final String INVALID_EXPRESSION = "INVALID_EXPRESSION";
  static final String INVALID_ARGUMENT = "INVALID_ARGUMENT";

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
