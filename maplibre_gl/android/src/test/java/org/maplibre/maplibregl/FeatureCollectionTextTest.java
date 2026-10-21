package org.maplibre.maplibregl;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import com.google.gson.JsonElement;
import com.google.gson.JsonParser;

import org.junit.Test;

/** The cases setGeoJsonFeature relies on when it merges one feature into a source. */
public class FeatureCollectionTextTest {
  private static JsonElement json(String text) {
    return JsonParser.parseString(text);
  }

  private static String point(String id, int n) {
    return "{\"type\":\"Feature\",\"id\":" + id + ",\"properties\":{\"n\":" + n
        + "},\"geometry\":{\"type\":\"Point\",\"coordinates\":[" + n + ",0]}}";
  }

  private static String collection(String... features) {
    return "{\"type\":\"FeatureCollection\",\"features\":[" + String.join(",", features) + "]}";
  }

  @Test
  public void replacesOneFeatureAndKeepsTheOthersAsTheyWere() {
    final FeatureCollectionText data = FeatureCollectionText.parse(
        collection(point("\"a\"", 1), point("\"b\"", 2), point("\"c\"", 3)));

    assertTrue(data.replace(json(point("\"b\"", 20))));

    assertEquals(collection(point("\"a\"", 1), point("\"b\"", 20), point("\"c\"", 3)),
        data.toJson());
  }

  @Test
  public void keepsNumericIdsNumericAndMatchesThemByText() {
    final FeatureCollectionText data =
        FeatureCollectionText.parse(collection(point("1", 1), point("2", 2)));

    assertTrue(data.replace(json(point("2", 20))));
    assertEquals(json(collection(point("1", 1), point("2", 20))), json(data.toJson()));

    // 2 and "2" are the same feature, as before.
    assertTrue(data.replace(json(point("\"2\"", 21))));
    assertEquals(json(collection(point("1", 1), point("\"2\"", 21))), json(data.toJson()));
  }

  @Test
  public void replacesTheFirstOfTwoFeaturesWithTheSameId() {
    final FeatureCollectionText data =
        FeatureCollectionText.parse(collection(point("\"a\"", 1), point("\"a\"", 2)));

    assertTrue(data.replace(json(point("\"a\"", 10))));

    assertEquals(collection(point("\"a\"", 10), point("\"a\"", 2)), data.toJson());
  }

  @Test
  public void leavesTheSourceAloneForAnUnknownIdOrNoId() {
    final String source = collection(point("\"a\"", 1));
    final FeatureCollectionText data = FeatureCollectionText.parse(source);

    assertFalse(data.replace(json(point("\"z\"", 9))));
    assertFalse(data.replace(json("{\"type\":\"Feature\",\"properties\":{},"
        + "\"geometry\":{\"type\":\"Point\",\"coordinates\":[0,0]}}")));

    assertEquals(source, data.toJson());
  }

  @Test
  public void readsOnlyTheTopLevelIdOfEachFeature() {
    final String withNestedIds = "{\"type\":\"Feature\",\"properties\":{\"id\":\"inner\"},"
        + "\"geometry\":{\"type\":\"Point\",\"coordinates\":[0,0]},\"id\":\"outer\"}";
    final FeatureCollectionText data = FeatureCollectionText.parse(collection(withNestedIds));

    assertFalse(data.replace(json(point("\"inner\"", 1))));
    assertTrue(data.replace(json(point("\"outer\"", 1))));
  }

  @Test
  public void keepsWhitespaceEscapesAndOtherMembers() {
    final String tricky = "{ \"type\" : \"Feature\", \"id\" : \"x\\\"y\",\n"
        + "  \"properties\" : { \"name\" : \"a]}\\\"[{b\", \"e\" : \"\\u00e9\\\\\" },\n"
        + "  \"geometry\" : { \"type\" : \"Point\", \"coordinates\" : [ 1.5e2 , -0.0 ] } }";
    final String head = "{\n  \"bbox\" : [0, 0, 1, 1],\n  \"type\" : \"FeatureCollection\",\n"
        + "  \"features\" : [";
    final String tail = "],\n  \"name\" : \"layer\"\n}";
    final String source =
        head + "\n    " + tricky + " ,\n    " + point("\"b\"", 2) + "\n  " + tail;
    final FeatureCollectionText data = FeatureCollectionText.parse(source);

    // Untouched, the features and the members around them come back as they
    // were given; only the whitespace between features goes.
    assertEquals(head + tricky + "," + point("\"b\"", 2) + tail, data.toJson());

    // The escaped id matches the id Gson reads from the same text.
    assertTrue(data.replace(json(tricky.replace("1.5e2", "7"))));
    assertTrue(data.replace(json(point("\"b\"", 20))));
    final JsonElement expected = json(source
        .replace(tricky, tricky.replace("1.5e2", "7"))
        .replace(point("\"b\"", 2), point("\"b\"", 20)));
    assertEquals(expected, json(data.toJson()));
  }

  @Test
  public void matchesAnIdWrittenWithAUnicodeEscape() {
    final FeatureCollectionText data =
        FeatureCollectionText.parse(collection(point("\"caf\\u00e9\"", 1)));

    assertTrue(data.replace(json(point("\"café\"", 2))));
  }

  @Test
  public void wrapsALoneFeatureInACollection() {
    final FeatureCollectionText data = FeatureCollectionText.parse(point("\"a\"", 1));

    assertTrue(data.replace(json(point("\"a\"", 2))));

    assertEquals(json(collection(point("\"a\"", 2))), json(data.toJson()));
  }

  @Test
  public void handlesAnEmptyCollection() {
    final String source = collection();
    final FeatureCollectionText data = FeatureCollectionText.parse(source);

    assertFalse(data.replace(json(point("\"a\"", 1))));
    assertEquals(source, data.toJson());
  }

  @Test
  public void answersNullForDataThatIsNotACollectionOrAFeature() {
    assertNull(FeatureCollectionText.parse("{\"type\":\"Point\",\"coordinates\":[0,0]}"));
    assertNull(FeatureCollectionText.parse("[1,2]"));
    assertNull(FeatureCollectionText.parse("{\"type\":\"FeatureCollection\"}"));
    assertNull(FeatureCollectionText.parse(
        "{\"type\":\"FeatureCollection\",\"features\":{\"a\":1}}"));
  }
}
