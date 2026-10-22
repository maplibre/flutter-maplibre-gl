part of '../maplibre_gl_platform_interface.dart';

/// [text] as a url MapLibre loads, or null when it is empty or cannot be a
/// url at all.
///
/// Every character a url cannot hold is percent-encoded as UTF-8, the way
/// browsers and iOS read such a url: a space, a quote, `{`, `|`, a character
/// beyond ASCII, a `%` not followed by two hex digits, a `#` after the first,
/// and a `[` or `]` outside the host. A url that holds none of them comes
/// back as it is. A url Dart's [Uri] still cannot read after that, such as
/// one with a port that is not a number, is null.
///
/// Every platform runs it on the url of a GeoJSON source, an image source or
/// a raster-dem source, and on the url of `editGeoJsonUrl`, so the same text
/// loads the same file everywhere.
String? encodeUrl(String text) {
  if (text.isEmpty) return null;
  final hostEnd = _schemeAndHost.matchAsPrefix(text)?.end ?? 0;
  var fragment = false;
  final encoded = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final char = String.fromCharCode(unit);
    final bool keep;
    if (char == '#') {
      keep = !fragment;
      fragment = true;
    } else if (char == '[' || char == ']') {
      keep = i < hostEnd;
    } else if (char == '%') {
      keep = _isHexAt(text, i + 1) && _isHexAt(text, i + 2);
    } else {
      keep = unit < 0x80 && _urlCharacters.contains(char);
    }
    if (keep) {
      encoded.write(char);
      continue;
    }
    // A character beyond the basic plane takes two code units.
    final pair =
        unit >= 0xD800 &&
        unit < 0xDC00 &&
        i + 1 < text.length &&
        text.codeUnitAt(i + 1) >= 0xDC00 &&
        text.codeUnitAt(i + 1) < 0xE000;
    final character = pair ? text.substring(i, i + 2) : char;
    if (pair) i++;
    for (final byte in utf8.encode(character)) {
      encoded.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  final url = encoded.toString();
  return Uri.tryParse(url) == null ? null : url;
}

/// [source], the JSON of a source, with the url it loads read by [encodeUrl]:
/// the `data` of a GeoJSON source when it is a string, and the `url` of an
/// image or raster-dem source. A url [encodeUrl] reads as null is left out,
/// so the source fails as one without it.
Map<String, dynamic> encodeSourceUrl(Map<String, dynamic> source) {
  final key = switch (source['type']) {
    'geojson' => 'data',
    'image' || 'raster-dem' => 'url',
    _ => null,
  };
  if (key == null) return source;
  final text = source[key];
  if (text is! String) return source;
  final url = encodeUrl(text);
  if (url == text) return source;
  final encoded = {...source};
  if (url == null) {
    encoded.remove(key);
  } else {
    encoded[key] = url;
  }
  return encoded;
}

/// The scheme of a url and the authority after it, which holds the host.
final _schemeAndHost = RegExp(r'[A-Za-z][A-Za-z0-9+.\-]*://[^/?#]*');

/// The characters RFC 3986 lets a url hold as they are, besides `%`, `#`, `[`
/// and `]`, which [encodeUrl] checks on their own.
const _urlCharacters =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    r"-._~:/?@!$&'()*+,;=";

bool _isHexAt(String text, int index) =>
    index < text.length && '0123456789ABCDEFabcdef'.contains(text[index]);
