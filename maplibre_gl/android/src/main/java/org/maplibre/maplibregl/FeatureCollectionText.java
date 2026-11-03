package org.maplibre.maplibregl;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The data of a GeoJSON source kept as the JSON text of each feature, so setGeoJsonFeature can
 * replace one feature by joining strings instead of serializing every feature of the source again.
 *
 * <p>Reading the source text is a single scan that copies each feature as it is and reads only its
 * top-level id. A Gson tree of the whole source, which the scan replaces, took tens of
 * milliseconds of the platform thread for 1,000 annotations, and an annotation manager pays that
 * on the first update after every add or remove. Text the scan does not expect, such as a lone
 * Feature, still goes through Gson.
 *
 * <p>Ids are compared by their text, so 2 and "2" match, and the merged JSON keeps numeric ids
 * numeric: a Java Feature would turn every id of the source into a String.
 */
final class FeatureCollectionText {
  // The source text up to and including the opening bracket of the features array.
  private final String head;
  // The source text from the closing bracket of the features array to the end.
  private final String tail;
  private final List<String> features;
  // Index of the first feature with each id, the one a merge replaces.
  private final Map<String, Integer> indexById;

  private FeatureCollectionText(
      String head, String tail, List<String> features, Map<String, Integer> indexById) {
    this.head = head;
    this.tail = tail;
    this.features = features;
    this.indexById = indexById;
  }

  /**
   * The source data in {@code json} as a FeatureCollection, or null when it is neither a
   * FeatureCollection nor a Feature.
   */
  static FeatureCollectionText parse(String json) {
    final FeatureCollectionText scanned = new Scanner(json).collection();
    return scanned != null ? scanned : parseTree(json);
  }

  // Through a Gson tree, which also wraps a lone Feature in a collection.
  private static FeatureCollectionText parseTree(String json) {
    final JsonElement element = JsonParser.parseString(json);
    if (!element.isJsonObject()) {
      return null;
    }
    JsonObject data = element.getAsJsonObject();
    final JsonElement type = data.get("type");
    final String typeName = type != null && type.isJsonPrimitive() ? type.getAsString() : null;
    if ("Feature".equals(typeName)) {
      final JsonArray wrapped = new JsonArray();
      wrapped.add(data);
      data = new JsonObject();
      data.addProperty("type", "FeatureCollection");
      data.add("features", wrapped);
    } else if (!"FeatureCollection".equals(typeName) || !data.has("features")
        || !data.get("features").isJsonArray()) {
      return null;
    }

    final JsonArray array = data.getAsJsonArray("features");
    final List<String> features = new ArrayList<>(array.size());
    final Map<String, Integer> indexById = new HashMap<>();
    for (int i = 0; i < array.size(); i++) {
      final JsonElement feature = array.get(i);
      features.add(feature.toString());
      final String id = idKey(feature);
      if (id != null && !indexById.containsKey(id)) {
        indexById.put(id, i);
      }
    }
    final JsonObject rest = new JsonObject();
    for (Map.Entry<String, JsonElement> member : data.entrySet()) {
      if (!"features".equals(member.getKey())) {
        rest.add(member.getKey(), member.getValue());
      }
    }
    final String restJson = rest.toString();
    final String head = restJson.substring(0, restJson.length() - 1)
        + (rest.entrySet().isEmpty() ? "" : ",")
        + "\"features\":[";
    return new FeatureCollectionText(head, "]}", features, indexById);
  }

  // The id of a parsed feature as text, or null when it has none.
  private static String idKey(JsonElement feature) {
    if (feature == null || !feature.isJsonObject()) {
      return null;
    }
    final JsonElement id = feature.getAsJsonObject().get("id");
    return id != null && id.isJsonPrimitive() ? id.getAsString() : null;
  }

  /**
   * Replaces the feature with the same id as {@code feature}. False when the collection has no
   * feature with that id, or {@code feature} has no id.
   */
  boolean replace(JsonElement feature) {
    final String id = idKey(feature);
    final Integer index = id != null ? indexById.get(id) : null;
    if (index == null) {
      return false;
    }
    features.set(index, feature.toString());
    return true;
  }

  String toJson() {
    int length = head.length() + tail.length() + features.size();
    for (String feature : features) {
      length += feature.length();
    }
    final StringBuilder json = new StringBuilder(length).append(head);
    for (int i = 0; i < features.size(); i++) {
      if (i > 0) {
        json.append(',');
      }
      json.append(features.get(i));
    }
    return json.append(tail).toString();
  }

  /**
   * One pass over a FeatureCollection written as strict JSON, as the Dart side encodes it.
   * Anything else, or anything malformed, makes {@link #collection} answer null.
   */
  private static final class Scanner {
    private final String json;
    // Indexed directly, which costs less per character than charAt.
    private final char[] chars;
    private int pos;

    Scanner(String json) {
      this.json = json;
      this.chars = json.toCharArray();
    }

    FeatureCollectionText collection() {
      try {
        expect('{');
        String type = null;
        int headEnd = -1;
        int tailStart = -1;
        List<String> features = null;
        Map<String, Integer> indexById = null;
        if (consume('}')) {
          return null;
        }
        do {
          final String key = string();
          expect(':');
          if ("type".equals(key)) {
            skipWhitespace();
            type = chars[pos] == '"' ? string() : null;
            if (type == null) {
              skipValue();
            }
          } else if ("features".equals(key)) {
            if (features != null) {
              // Gson keeps the last of two features members: leave this to it.
              return null;
            }
            expect('[');
            headEnd = pos;
            features = new ArrayList<>();
            indexById = new HashMap<>();
            if (!consume(']')) {
              do {
                skipWhitespace();
                final int start = pos;
                final String id = featureId();
                features.add(json.substring(start, pos));
                if (id != null && !indexById.containsKey(id)) {
                  indexById.put(id, features.size() - 1);
                }
              } while (consume(','));
              expect(']');
            }
            tailStart = pos - 1;
          } else {
            skipValue();
          }
        } while (consume(','));
        expect('}');
        skipWhitespace();
        if (pos != chars.length || !"FeatureCollection".equals(type) || features == null) {
          return null;
        }
        return new FeatureCollectionText(
            json.substring(0, headEnd), json.substring(tailStart), features, indexById);
      } catch (Unexpected | IndexOutOfBoundsException | NumberFormatException e) {
        return null;
      }
    }

    // Skips one feature and answers its top-level id as text, as Gson's getAsString would give
    // it, or null when it has none.
    private String featureId() {
      skipWhitespace();
      if (chars[pos] != '{') {
        skipValue();
        return null;
      }
      pos++;
      String id = null;
      if (consume('}')) {
        return null;
      }
      do {
        final String key = string();
        expect(':');
        if ("id".equals(key)) {
          // Gson keeps the last of two id members, and so does this.
          id = primitiveText();
        } else {
          skipValue();
        }
      } while (consume(','));
      expect('}');
      return id;
    }

    // A string, number or boolean value as text; null for null, objects and arrays.
    private String primitiveText() {
      skipWhitespace();
      final char c = chars[pos];
      if (c == '"') {
        return string();
      }
      if (c == '{' || c == '[') {
        skipValue();
        return null;
      }
      final String literal = literal();
      return "null".equals(literal) ? null : literal;
    }

    private void skipValue() {
      skipWhitespace();
      final char c = chars[pos];
      if (c == '"') {
        skipString();
      } else if (c == '{' || c == '[') {
        int depth = 0;
        do {
          switch (chars[pos++]) {
            case '"':
              pos--;
              skipString();
              break;
            case '{':
            case '[':
              depth++;
              break;
            case '}':
            case ']':
              depth--;
              break;
            default:
              break;
          }
        } while (depth > 0);
      } else {
        literal();
      }
    }

    // A number, true, false or null, up to the next delimiter.
    private String literal() {
      final int start = pos;
      while (pos < chars.length && !isDelimiter(chars[pos])) {
        pos++;
      }
      if (pos == start) {
        throw new Unexpected();
      }
      return json.substring(start, pos);
    }

    private static boolean isDelimiter(char c) {
      switch (c) {
        case ',':
        case ':':
        case ']':
        case '}':
        case '[':
        case '{':
        case '"':
        case ' ':
        case '\t':
        case '\n':
        case '\r':
          return true;
        default:
          return false;
      }
    }

    private String string() {
      skipWhitespace();
      if (chars[pos] != '"') {
        throw new Unexpected();
      }
      final int start = ++pos;
      StringBuilder decoded = null;
      while (true) {
        final char c = chars[pos];
        if (c == '"') {
          final String text = decoded == null
              ? json.substring(start, pos)
              : decoded.toString();
          pos++;
          return text;
        }
        if (c == '\\') {
          if (decoded == null) {
            decoded = new StringBuilder(json.substring(start, pos));
          }
          final char escaped = chars[pos + 1];
          switch (escaped) {
            case '"':
            case '\\':
            case '/':
              decoded.append(escaped);
              break;
            case 'b':
              decoded.append('\b');
              break;
            case 'f':
              decoded.append('\f');
              break;
            case 'n':
              decoded.append('\n');
              break;
            case 'r':
              decoded.append('\r');
              break;
            case 't':
              decoded.append('\t');
              break;
            case 'u':
              decoded.append((char) Integer.parseInt(json.substring(pos + 2, pos + 6), 16));
              pos += 4;
              break;
            default:
              throw new Unexpected();
          }
          pos += 2;
        } else {
          if (decoded != null) {
            decoded.append(c);
          }
          pos++;
        }
      }
    }

    private void skipString() {
      pos++;
      while (true) {
        final char c = chars[pos++];
        if (c == '"') {
          return;
        }
        if (c == '\\') {
          pos++;
        }
      }
    }

    private void skipWhitespace() {
      while (pos < chars.length) {
        final char c = chars[pos];
        if (c != ' ' && c != '\t' && c != '\n' && c != '\r') {
          return;
        }
        pos++;
      }
    }

    private boolean consume(char c) {
      skipWhitespace();
      if (pos < chars.length && chars[pos] == c) {
        pos++;
        return true;
      }
      return false;
    }

    private void expect(char c) {
      if (!consume(c)) {
        throw new Unexpected();
      }
    }
  }

  // Thrown by the scan for text it does not expect. Carries no stack trace: it is control flow.
  private static final class Unexpected extends RuntimeException {
    Unexpected() {
      super(null, null, false, false);
    }
  }
}
