package org.maplibre.maplibregl;

import android.net.Uri;
import android.util.Log;
import androidx.annotation.Nullable;
import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonParser;
import org.maplibre.android.style.expressions.Expression;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.geometry.LatLngQuad;
import org.maplibre.android.style.sources.GeoJsonOptions;
import org.maplibre.android.style.sources.GeoJsonSource;
import org.maplibre.android.style.sources.ImageSource;
import org.maplibre.android.style.sources.RasterDemSource;
import org.maplibre.android.style.sources.RasterSource;
import org.maplibre.android.style.sources.Source;
import org.maplibre.android.style.sources.TileSet;
import org.maplibre.android.style.sources.VectorSource;
import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;

class SourcePropertyConverter {
  private static final String TAG = "SourcePropertyConverter";

  static TileSet buildTileset(Map<String, Object> data) {
    final Object tiles = data.get("tiles");

    // options are only valid with tiles
    if (tiles == null) {
      return null;
    }

    final TileSet tileSet =
        new TileSet("2.1.0", (String[]) Convert.toList(tiles).toArray(new String[0]));

    final Object bounds = data.get("bounds");
    if (bounds != null) {
      List<Float> boundsFloat = new ArrayList<Float>();
      for (Object item : Convert.toList(bounds)) {
        boundsFloat.add(Convert.toFloat(item));
      }
      tileSet.setBounds(boundsFloat.toArray(new Float[0]));
    }

    final Object scheme = data.get("scheme");
    if (scheme != null) {
      tileSet.setScheme(Convert.toString(scheme));
    }

    final Object minzoom = data.get("minzoom");
    if (minzoom != null) {
      tileSet.setMinZoom(Convert.toFloat(minzoom));
    }

    final Object maxzoom = data.get("maxzoom");
    if (maxzoom != null) {
      tileSet.setMaxZoom(Convert.toFloat(maxzoom));
    }

    final Object attribution = data.get("attribution");
    if (attribution != null) {
      tileSet.setAttribution(Convert.toString(attribution));
    }
    return tileSet;
  }

  static GeoJsonOptions buildGeojsonOptions(Map<String, Object> data) {
    // Disabled until upstream maplibre-native#4326 is fixed: synchronousUpdate causes a
    // texture atlas slot-reuse bug that silently discards icons added via addImage().
    GeoJsonOptions options = new GeoJsonOptions().withSynchronousUpdate(false);

    final Object buffer = data.get("buffer");
    if (buffer != null) {
      options = options.withBuffer(Convert.toInt(buffer));
    }

    final Object cluster = data.get("cluster");
    if (cluster != null) {
      options = options.withCluster(Convert.toBoolean(cluster));
    }

    final Object clusterMaxZoom = data.get("clusterMaxZoom");
    if (clusterMaxZoom != null) {
      options = options.withClusterMaxZoom(Convert.toInt(clusterMaxZoom));
    }

    final Object clusterRadius = data.get("clusterRadius");
    if (clusterRadius != null) {
      options = options.withClusterRadius(Convert.toInt(clusterRadius));
    }

    final Object clusterMinPoints = data.get("clusterMinPoints");
    if (clusterMinPoints != null) {
      options = options.withClusterMinPoints(Convert.toInt(clusterMinPoints));
    }

    final Object lineMetrics = data.get("lineMetrics");
    if (lineMetrics != null) {
      options = options.withLineMetrics(Convert.toBoolean(lineMetrics));
    }

    // The spec key is lowercase, which is what GeojsonSourceProperties sends.
    // A GeoJSON source has no minzoom, so there is nothing to read for one.
    final Object maxZoom = data.get("maxzoom");
    if (maxZoom != null) {
      options = options.withMaxZoom(Convert.toInt(maxZoom));
    }

    final Object tolerance = data.get("tolerance");
    if (tolerance != null) {
      options = options.withTolerance(Convert.toFloat(tolerance));
    }

    final Object clusterProperties = data.get("clusterProperties");
    if (clusterProperties instanceof Map) {
      final Gson gson = new Gson();
      for (Map.Entry<?, ?> entry : ((Map<?, ?>) clusterProperties).entrySet()) {
        final String propertyName = entry.getKey().toString();
        if (!(entry.getValue() instanceof List)) continue;
        final List<?> value = (List<?>) entry.getValue();
        if (value.size() < 2) continue;
        // Format: [operator, map_expression]. The operator may be a simple string
        // (e.g. "+") that needs expanding to ["+", ["accumulated"], ["get", propertyName]],
        // or a full reduce-expression array that is passed through as-is.
        final Object opRaw = value.get(0);
        final JsonElement operatorJson;
        if (opRaw instanceof String) {
          final List<Object> expanded = Arrays.asList(
              opRaw,
              Collections.singletonList("accumulated"),
              Arrays.asList("get", propertyName));
          operatorJson = JsonParser.parseString(gson.toJson(expanded));
        } else {
          operatorJson = JsonParser.parseString(gson.toJson(opRaw));
        }
        final JsonElement mapExprJson = JsonParser.parseString(gson.toJson(value.get(1)));
        final Expression operatorExpr = Expression.Converter.convert(operatorJson);
        final Expression mapExpr = Expression.Converter.convert(mapExprJson);
        options = options.withClusterProperty(propertyName, operatorExpr, mapExpr);
      }
    }

    return options;
  }

  static GeoJsonSource buildGeojsonSource(String id, Map<String, Object> properties) {
    final Object data = properties.get("data");
    final GeoJsonOptions options = buildGeojsonOptions(properties);
    if (data != null) {
      if (data instanceof String) {
        try {
          final URI uri = new URI(Convert.toString(data));
          return new GeoJsonSource(id, uri, options);
        } catch (URISyntaxException e) {
        }
      } else {
        Gson gson = new Gson();
        String geojson = gson.toJson(data);
        // Raw JSON, so the engine keeps numeric feature ids numeric; a Java
        // FeatureCollection would turn them into Strings.
        return new GeoJsonSource(id, geojson, options);
      }
    }
    return null;
  }

  /**
   * {@code coordinates}, the four [longitude, latitude] corners of an image source from the top
   * left clockwise, as a quad.
   */
  static LatLngQuad buildLatLngQuad(Object coordinates) {
    final List<LatLng> corners = Convert.toLatLngList(coordinates, true);
    return new LatLngQuad(corners.get(0), corners.get(1), corners.get(2), corners.get(3));
  }

  static ImageSource buildImageSource(String id, Map<String, Object> properties) {
    final Object url = properties.get("url");
    final LatLngQuad quad = buildLatLngQuad(properties.get("coordinates"));
    try {
      final URI uri = new URI(Convert.toString(url));
      return new ImageSource(id, quad, uri);
    } catch (URISyntaxException e) {
    }
    return null;
  }

  static VectorSource buildVectorSource(String id, Map<String, Object> properties) {
    final Object url = properties.get("url");
    if (url != null) {
      final Uri uri = Uri.parse(Convert.toString(url));

      if (uri != null) {
        return new VectorSource(id, uri);
      }
      return null;
    }

    final TileSet tileSet = buildTileset(properties);
    return tileSet != null ? new VectorSource(id, tileSet) : null;
  }

  static RasterSource buildRasterSource(String id, Map<String, Object> properties) {
    final Object url = properties.get("url");
    final Object tileSizeObj = properties.get("tileSize");
    if (url != null) {
      final String uri = Convert.toString(url);
      if (tileSizeObj != null) {
        final int tileSize = Convert.toInt(tileSizeObj);
        return new RasterSource(id, uri, tileSize);
      } else {
        return new RasterSource(id, uri);
      }
    }

    final TileSet tileSet = buildTileset(properties);
    if (tileSet != null) {
      if (tileSizeObj != null) {
        final int tileSize = Convert.toInt(tileSizeObj);
        return new RasterSource(id, tileSet, tileSize);
      } else {
        return new RasterSource(id, tileSet);
      }
    } else {
      return null;
    }
  }

  static RasterDemSource buildRasterDemSource(String id, Map<String, Object> properties) {
    final Object url = properties.get("url");
    if (url != null) {
      try {
        final URI uri = new URI(Convert.toString(url));
        return new RasterDemSource(id, uri);
      } catch (URISyntaxException e) {
      }
    }

    final TileSet tileSet = buildTileset(properties);
    if (tileSet != null) {
      final Object encoding = properties.get("encoding");
      if (encoding != null) {
        tileSet.setEncoding(Convert.toString(encoding));
      }
      return new RasterDemSource(id, tileSet);
    }
    return null;
  }

  /** Whether {@link #buildSource} knows the source type {@code type}. */
  static boolean isSupportedType(String type) {
    switch (type) {
      case "vector":
      case "raster":
      case "raster-dem":
      case "image":
      case "geojson":
        return true;
      default:
        return false;
    }
  }

  /**
   * The source of type {@code type} that {@code properties} describe, or null when they do not
   * describe one, such as a tiled source with neither a url nor tiles.
   */
  @Nullable
  static Source buildSource(String id, String type, Map<String, Object> properties) {
    Source source;
    try {
      switch (type) {
        case "vector":
          source = buildVectorSource(id, properties);
          break;
        case "raster":
          source = buildRasterSource(id, properties);
          break;
        case "raster-dem":
          source = buildRasterDemSource(id, properties);
          break;
        case "image":
          source = buildImageSource(id, properties);
          break;
        case "geojson":
          source = buildGeojsonSource(id, properties);
          break;
        default:
          source = null;
      }
    } catch (RuntimeException e) {
      // A property of the wrong kind, such as missing image coordinates.
      Log.w(TAG, "buildSource: cannot build source '" + id + "'", e);
      return null;
    }

    if (source != null) {
      // Tile caching is a source-level setting rather than a tileset option, so
      // it is applied to the built source. Set before the source joins the
      // style, so the first tile requests already honour it.
      final Object volatileTiles = properties.get("volatile");
      if (volatileTiles != null) {
        source.setVolatile(Convert.toBoolean(volatileTiles));
      }
    }
    return source;
  }
}
