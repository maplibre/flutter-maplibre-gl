/// Registers the `pmtiles://` protocol with MapLibre GL JS.
///
/// The maplibre_gl plugin loads MapLibre GL JS itself, so the `maplibregl`
/// global does not exist while index.html is parsed and this registration can
/// no longer live in an inline script there. It runs from `main()` instead,
/// after `MapLibreMap.ensureWebLibraryLoaded()` has completed.
///
/// The pmtiles library itself still ships as a plain `<script>` tag in
/// index.html: it is self-contained, and nothing here runs before `main()`,
/// by which time that tag has long executed.
@JS()
library;

import 'dart:js_interop';

@JS('maplibregl.addProtocol')
external void _addProtocol(String customProtocol, JSFunction loadFn);

/// `new pmtiles.Protocol()`. `tile` is the load callback maplibre expects
/// (pmtiles defines it as a bound arrow-function property, so it can be
/// passed around detached); `add` registers an archive with the protocol.
@JS('pmtiles.Protocol')
extension type _Protocol._(JSObject _) implements JSObject {
  external _Protocol();

  external JSFunction get tile;

  external void add(_PMTiles archive);
}

/// `new pmtiles.PMTiles(source)`, one archive.
@JS('pmtiles.PMTiles')
extension type _PMTiles._(JSObject _) implements JSObject {
  external _PMTiles(_FetchSource source);
}

/// `new pmtiles.FetchSource(url)`, reads the archive with HTTP range
/// requests.
@JS('pmtiles.FetchSource')
extension type _FetchSource._(JSObject _) implements JSObject {
  external _FetchSource(String url);
}

/// Registers the `pmtiles://` protocol and adds the archive at [archiveUrl].
void registerPmTilesProtocol(String archiveUrl) {
  final protocol = _Protocol();
  _addProtocol('pmtiles', protocol.tile);
  protocol.add(_PMTiles(_FetchSource(archiveUrl)));
}
