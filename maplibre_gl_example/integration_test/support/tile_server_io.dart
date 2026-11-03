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

  /// Tile requests received, answered or held.
  int tileRequests = 0;

  /// Open while tiles are answered; [holdTiles] closes it.
  Completer<void>? _tileGate;

  /// Leaves every tile request unanswered until [releaseTiles], so a test can
  /// pause an offline download before any of its tiles arrives.
  void holdTiles() => _tileGate ??= Completer<void>();

  /// Answers the tile requests [holdTiles] held back, and every later one.
  void releaseTiles() {
    _tileGate?.complete();
    _tileGate = null;
  }

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
      tileRequests++;
      final gate = _tileGate;
      if (gate == null) {
        unawaited(_sendTile(response));
      } else {
        unawaited(gate.future.then((_) => _sendTile(response)));
      }
      return;
    } else {
      response.statusCode = HttpStatus.notFound;
    }
    unawaited(response.close());
  }

  Future<void> _sendTile(HttpResponse response) async {
    try {
      tilesServed++;
      response.headers.contentType = ContentType('image', 'png');
      // Long-lived, so the SDK stores the tile rather than treating it as
      // uncacheable.
      response.headers.set(HttpHeaders.cacheControlHeader, 'max-age=86400');
      response.add(_tile);
      await response.close();
    } on Object {
      // The SDK dropped the request while it was held: a paused download
      // cancels the requests it has in flight.
    }
  }
}

/// Size of the file at [path] in bytes.
Future<int> fileSize(String path) => File(path).length();
