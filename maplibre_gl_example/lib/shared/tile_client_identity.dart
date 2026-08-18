import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// User-Agent this example sends with every request the map makes: tiles,
/// style JSON, sprites and glyphs.
///
/// Tile servers use it to tell one client from another, and several of them
/// now refuse traffic they cannot attribute to an application. OpenStreetMap's
/// tile usage policy is the strictest of the ones this example has met: it
/// asks for "a clear, unique User-Agent string that names your app" and blocks
/// library defaults such as `okhttp/...` outright, answering every tile with a
/// picture that says "Access blocked" instead of the map.
/// See https://operations.osmfoundation.org/policies/tiles/.
///
/// Name your own app here rather than copying this string, and point the URL
/// at something that reaches you.
const String tileClientUserAgent = 'flutter-maplibre-gl-example';

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
