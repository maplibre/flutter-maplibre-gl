// A tile server that runs inside the test process, for tests that need the
// native SDK to download and cache real HTTP responses. Android and iOS only:
// import it through tile_server.dart so the web build still compiles.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Serves one raster style and an endless supply of large, cacheable tiles.
///
/// The tile bytes are random rather than a real PNG: MapLibre Native writes a
/// response to the ambient cache as soon as it arrives, before the tile worker
/// decodes it, so the cache fills either way and the map simply draws nothing.
class TileServer {
  TileServer._(this._server, this._tile);

  final HttpServer _server;
  final List<int> _tile;

  /// Tiles served since the counter was last reset.
  int tilesServed = 0;

  String get styleUrl => '$_origin/style';

  String get _origin => 'http://${_server.address.host}:${_server.port}';

  /// Starts a server on loopback whose tiles are each [tileBytes] long.
  static Future<TileServer> start({required int tileBytes}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random(1);
    final tile = List<int>.generate(tileBytes, (_) => random.nextInt(256));
    final tileServer = TileServer._(server, tile);
    server.listen(tileServer._handle);
    return tileServer;
  }

  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final response = request.response;
    if (request.uri.path == '/style') {
      final style = {
        'version': 8,
        'sources': {
          'fixture': {
            'type': 'raster',
            'tiles': ['$_origin/tiles/{z}/{x}/{y}'],
            'tileSize': 256,
          },
        },
        'layers': [
          {'id': 'fixture', 'type': 'raster', 'source': 'fixture'},
        ],
      };
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(style));
    } else if (request.uri.path.startsWith('/tiles/')) {
      tilesServed++;
      response.headers.contentType = ContentType('image', 'png');
      // Long-lived, so the SDK stores the tile rather than treating it as
      // uncacheable.
      response.headers.set(HttpHeaders.cacheControlHeader, 'max-age=86400');
      response.add(_tile);
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    unawaited(response.close());
  }
}

/// Size of the file at [path] in bytes.
Future<int> fileSize(String path) => File(path).length();
