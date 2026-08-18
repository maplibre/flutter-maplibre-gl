import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// User-Agent this example sends with every request the map makes: tiles,
/// style JSON, sprites and glyphs.
///
/// Every tile this example draws is served by someone else, for free:
/// demotiles.maplibre.org, OpenFreeMap, NASA GIBS, the AWS terrain tiles. The
/// documentation site embeds this app about nineteen times over, so its
/// traffic is not negligible to them. A client that names itself can be
/// throttled, or its authors reached, on its own; one that does not leaves an
/// operator with nothing to act on but the address, which is how a whole
/// network ends up blocked for what one page was doing.
///
/// Some providers require it outright. OpenStreetMap's tile usage policy asks
/// for "a clear, unique User-Agent string that names your app" and rejects
/// library defaults such as `okhttp/...`, answering with a picture that says
/// "Access blocked" instead of the map.
/// See https://operations.osmfoundation.org/policies/tiles/.
///
/// Name your own app here rather than copying this string, and keep the URL
/// pointing at something that reaches you.
const String tileClientUserAgent =
    'flutter-maplibre-gl-example (+https://github.com/maplibre/flutter-maplibre-gl)';

/// Announces this app to every tile server the example talks to.
///
/// Call it once at start-up, before the first map is built. The headers are
/// global to the process and are applied at request time, so a single call
/// covers every [MapLibreMap] the app creates afterwards.
///
/// On web this is a no-op: the browser owns the User-Agent header and refuses
/// to let a page set it, so there is no global channel behind
/// [setHttpHeaders] there. Browsers send an identifying User-Agent of their
/// own anyway.
Future<void> configureTileClientIdentity() async {
  if (kIsWeb) return;
  try {
    await setHttpHeaders({'User-Agent': tileClientUserAgent});
  } catch (error) {
    // Losing the header costs quality of service with some tile providers, not
    // the app: keep going and let the platform default identify us.
    debugPrint('could not set the tile client User-Agent: $error');
  }
}
