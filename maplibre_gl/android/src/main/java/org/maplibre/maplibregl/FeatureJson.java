package org.maplibre.maplibregl;

import com.google.gson.JsonObject;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;
import org.maplibre.geojson.Feature;

/**
 * The GeoJSON text of the features the SDK answers with, each with the id it has in the data.
 *
 * <p>The SDK hands every feature id over as text (the engine turns numbers into text, and a missing
 * id into ""), so {@code 2} arrives as "2", as does {@code "2"}. Text that reads as a number goes
 * back as a number, unless Dart marked the feature with {@link #STRING_ID_MARKER} because its id
 * was that text. The marker never leaves this class.
 */
final class FeatureJson {
  /** The property Dart adds to a feature whose id is text that reads as a number. */
  static final String STRING_ID_MARKER = "maplibre_gl:string_id";

  // The same rule as _numericText in native_map_platform.dart.
  private static final Pattern INTEGER_ID = Pattern.compile("-?(0|[1-9][0-9]*)");
  private static final Pattern DECIMAL_ID = Pattern.compile("-?(0|[1-9][0-9]*)\\.[0-9]+");

  private FeatureJson() {}

  /** Each of {@code features} as GeoJSON text, so nested properties survive intact. */
  static List<String> of(List<Feature> features) {
    final List<String> json = new ArrayList<>();
    if (features != null) {
      for (Feature feature : features) {
        json.add(of(feature));
      }
    }
    return json;
  }

  /** {@code feature} as GeoJSON text. An empty id is left out. */
  static String of(Feature feature) {
    final String id = feature.id();
    final JsonObject properties = feature.properties();
    final boolean textId = properties != null && properties.remove(STRING_ID_MARKER) != null;
    if (id == null) {
      return feature.toJson();
    }
    final String number = textId ? null : number(id);
    if (number == null && !id.isEmpty()) {
      return feature.toJson();
    }
    // Serialized once without the id, which then goes in as a bare number:
    // query results can hold thousands of features and this runs on the
    // platform thread, so no parse and reserialize round trip.
    final String json =
        Feature.fromGeometry(feature.geometry(), properties, null, feature.bbox()).toJson();
    if (number == null) {
      return json;
    }
    return "{\"id\":" + number + "," + json.substring(1);
  }

  /**
   * {@code id} as a JSON number when it reads as one, or null. An integer beyond a long stays text
   * rather than being rounded; a fraction arrives in its shortest form, such as "1.5".
   */
  private static String number(String id) {
    if (INTEGER_ID.matcher(id).matches()) {
      try {
        return Long.toString(Long.parseLong(id));
      } catch (NumberFormatException e) {
        return null;
      }
    }
    if (DECIMAL_ID.matcher(id).matches()) {
      final double value = Double.parseDouble(id);
      return Double.isInfinite(value) ? null : Double.toString(value);
    }
    return null;
  }
}
