package org.maplibre.maplibregl;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;

import java.util.Arrays;
import java.util.List;

import org.junit.Test;
import org.maplibre.geojson.Feature;
import org.maplibre.geojson.Point;

/** The ids of the features the SDK answers with, as Dart reads them. */
public class FeatureJsonTest {
  /** A feature as the SDK hands it over: its id is always text. */
  private static Feature feature(String id, boolean marked) {
    final JsonObject properties = new JsonObject();
    properties.addProperty("name", "a");
    if (marked) {
      properties.addProperty(FeatureJson.STRING_ID_MARKER, true);
    }
    return Feature.fromGeometry(Point.fromLngLat(1, 2), properties, id);
  }

  private static JsonObject json(Feature feature) {
    return JsonParser.parseString(FeatureJson.of(feature)).getAsJsonObject();
  }

  private static JsonPrimitive id(Feature feature) {
    return json(feature).getAsJsonPrimitive("id");
  }

  @Test
  public void textThatReadsAsANumberIsANumber() {
    assertTrue(id(feature("2", false)).isNumber());
    assertEquals(2, id(feature("2", false)).getAsLong());
    assertEquals(-3, id(feature("-3", false)).getAsLong());
    assertEquals(2.5, id(feature("2.5", false)).getAsDouble(), 0);
  }

  @Test
  public void aMarkedIdStaysText() {
    assertEquals(new JsonPrimitive("2"), id(feature("2", true)));
    assertEquals(new JsonPrimitive("2.5"), id(feature("2.5", true)));
  }

  @Test
  public void theMarkerNeverReachesDart() {
    for (boolean marked : new boolean[] {true, false}) {
      final JsonObject properties = json(feature("2", marked)).getAsJsonObject("properties");
      assertFalse(properties.has(FeatureJson.STRING_ID_MARKER));
      assertEquals("a", properties.get("name").getAsString());
    }
  }

  @Test
  public void otherTextStaysText() {
    assertEquals(new JsonPrimitive("poi-12"), id(feature("poi-12", false)));
    assertEquals(new JsonPrimitive("02"), id(feature("02", false)));
    // Beyond a long: kept as text rather than rounded.
    assertEquals(
        new JsonPrimitive("99999999999999999999"), id(feature("99999999999999999999", false)));
  }

  @Test
  public void anEmptyIdIsLeftOut() {
    assertFalse(json(feature("", false)).has("id"));
  }

  @Test
  public void everyFeatureOfAListIsConverted() {
    final List<String> features =
        FeatureJson.of(Arrays.asList(feature("2", true), feature("2", false)));

    assertEquals(2, features.size());
    final JsonObject text = JsonParser.parseString(features.get(0)).getAsJsonObject();
    final JsonObject number = JsonParser.parseString(features.get(1)).getAsJsonObject();
    assertTrue(text.getAsJsonPrimitive("id").isString());
    assertTrue(number.getAsJsonPrimitive("id").isNumber());
    assertTrue(FeatureJson.of((List<Feature>) null).isEmpty());
  }
}
