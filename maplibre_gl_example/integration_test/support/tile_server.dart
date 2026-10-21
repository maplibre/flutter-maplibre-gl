// Stub of tile_server_io.dart for platforms without dart:io (web), so test
// files that import it still compile there. Nothing here is meant to run: the
// tests that use it return early on web.

/// Serves a raster style and large, cacheable tiles over HTTP on loopback.
/// See tile_server_io.dart.
class TileServer {
  TileServer._();

  static Future<TileServer> start({required int tileBytes}) =>
      throw UnsupportedError('TileServer needs dart:io.');

  int tilesServed = 0;

  int tileRequests = 0;

  void holdTiles() {}

  void releaseTiles() {}

  String get styleUrl => throw UnsupportedError('TileServer needs dart:io.');

  Future<void> close() async {}
}

/// Size of the file at [path] in bytes.
Future<int> fileSize(String path) =>
    throw UnsupportedError('fileSize needs dart:io.');
