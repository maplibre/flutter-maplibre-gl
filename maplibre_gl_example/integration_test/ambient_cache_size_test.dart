// Integration test for `setMaximumAmbientCacheSize` on Android and iOS.
//
// The ambient cache lives in MapLibre Native, so a unit test with a mocked
// channel can only show that Dart sends the right message. This test drives
// the real SDK: it serves tiles from an HTTP server inside the test process,
// loads a map that fetches them, and watches the offline database file that
// backs the cache. Case one sets a 2 MB limit, loads far more than that, and
// checks the file never grew past it. Case two repeats the load with the SDK's
// 50 MB default in place and checks the file did grow past 2 MB. Without case
// two, case one could pass with a broken setter simply because the load was
// too small to matter.
//
// Run on a simulator, emulator or device:
//   flutter test integration_test/ambient_cache_size_test.dart -d <device id>
//
// The assertions only run on Android and iOS; on web the ambient cache does
// not exist and the test is a no-op so the suite stays green everywhere.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Every tile response carries this many bytes, so a handful of camera moves
/// is enough to outgrow [_smallLimit] several times over.
const int _tileBytes = 64 * 1024;

/// The limit under test. Small, so the fixture outgrows it quickly.
const int _smallLimit = 2 * 1024 * 1024;

/// The SDK default, used by the control case.
const int _defaultLimit = 50 * 1024 * 1024;

/// How far past the limit the file may grow. Eviction runs per insert, so the
/// overshoot is a few tiles plus SQLite page granularity, not a whole batch.
const int _slack = _smallLimit ~/ 2;

/// Zoom for every stop. At this zoom a stop two degrees away is a new set of
/// tiles, and a viewport covers a few dozen of them.
const double _zoom = 12;

/// Camera stops far enough apart that no tile is shared between them. The two
/// cases use different latitudes so neither asks for tiles the other already
/// cached; the fixture waits for fresh requests at every stop, and a cached
/// tile would never reach the server.
const List<LatLng> _limitedStops = [
  LatLng(0, 0),
  LatLng(0, 2),
  LatLng(0, 4),
  LatLng(2, 0),
  LatLng(2, 2),
  LatLng(2, 4),
];
const List<LatLng> _controlStops = [
  LatLng(10, 0),
  LatLng(10, 2),
  LatLng(10, 4),
  LatLng(12, 0),
  LatLng(12, 2),
  LatLng(12, 4),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _TileServer server;

  setUpAll(() async {
    server = await _TileServer.start();
    // Start from an empty store, and do it once, before any map exists.
    // Resetting between cases instead, after a map had used the store, left
    // the next case's writes invisible on disk in every run tried.
    await resetOfflineDatabase();
  });

  tearDownAll(() async {
    await server.close();
  });

  testWidgets('the database stays within the configured limit', (
    tester,
  ) async {
    if (kIsWeb) return;

    final peak = await _fillCache(
      tester,
      server,
      limit: _smallLimit,
      stops: _limitedStops,
    );

    expect(
      peak,
      lessThanOrEqualTo(_smallLimit + _slack),
      reason:
          'the ambient cache should have been trimmed to the limit '
          '(served ${server.tilesServed} tiles)',
    );
  });

  testWidgets('control: the same load outgrows the limit without it', (
    tester,
  ) async {
    if (kIsWeb) return;

    final peak = await _fillCache(
      tester,
      server,
      limit: _defaultLimit,
      stops: _controlStops,
    );

    expect(
      peak,
      greaterThan(_smallLimit + _slack),
      reason:
          'the control run must outgrow the limit the previous case imposed, '
          'or that case would pass without the limit doing anything '
          '(served ${server.tilesServed} tiles)',
    );
    // The tiles are random bytes and do not compress, so every one served
    // should still be on disk: nothing may be evicted under the default.
    expect(
      peak,
      greaterThanOrEqualTo(server.tilesServed * _tileBytes),
      reason:
          'nothing should be evicted under the default limit '
          '(served ${server.tilesServed} tiles of $_tileBytes bytes)',
    );
  });
}

/// Applies [limit], loads tiles at every one of [stops], and returns the
/// largest size the database file reached while they loaded, in bytes.
///
/// The peak is sampled while tiles stream in rather than read once at the
/// end: the SDK vacuums the database after evicting, so the file can shrink
/// after the last insert and an end-of-run size would understate how large
/// the store actually got.
Future<int> _fillCache(
  WidgetTester tester,
  _TileServer server, {
  required int limit,
  required List<LatLng> stops,
}) async {
  await setMaximumAmbientCacheSize(limit);
  server.tilesServed = 0;

  final path = await getOfflineDatabasePath();
  if (path == null) fail('getOfflineDatabasePath returned null');
  final database = File(path);
  var peak = 0;
  Future<void> sample() async {
    final size = await database.length();
    if (size > peak) peak = size;
  }

  final controllerCompleter = Completer<MapLibreMapController>();
  final styleLoaded = Completer<void>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MapLibreMap(
          styleString: server.styleUrl,
          initialCameraPosition: CameraPosition(
            target: stops.first,
            zoom: _zoom,
          ),
          onMapCreated: controllerCompleter.complete,
          onStyleLoadedCallback: () {
            if (!styleLoaded.isCompleted) styleLoaded.complete();
          },
        ),
      ),
    ),
  );

  final controller = await _await(
    tester,
    controllerCompleter.future,
    'onMapCreated',
  );
  await _await(tester, styleLoaded.future, 'onStyleLoaded');

  for (final stop in stops) {
    final before = server.tilesServed;
    // Zoom is set on every move rather than trusted from initialCameraPosition:
    // on iOS the first tiles were requested at zoom 2, so the initial camera
    // had not been applied by the time the style loaded.
    await controller.moveCamera(CameraUpdate.newLatLngZoom(stop, _zoom));
    // Each stop should pull a fresh viewport of tiles. Wait until the server
    // has seen some and then gone quiet, so nothing is still in flight when
    // the map is torn down.
    await _await(
      tester,
      _serverQuiet(server, minimumNewTiles: before + 1, onPoll: sample),
      'tiles at $stop',
    );
  }

  // Tear the map down and give the SDK's database thread a moment to flush
  // the last writes before the file is measured.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));

  await sample();
  debugPrint(
    'ambient cache: limit $limit bytes, ${server.tilesServed} tiles served, '
    'database peaked at $peak bytes, ${await database.length()} at the end',
  );
  return peak;
}

/// Completes once [server] has served at least [minimumNewTiles] and then
/// received no request for a second.
///
/// [onPoll] runs every 100 ms for as long as this waits. The caller passes the
/// database sampler, so the file is measured while a burst of tiles is being
/// written, not only after it has finished.
Future<void> _serverQuiet(
  _TileServer server, {
  required int minimumNewTiles,
  required Future<void> Function() onPoll,
}) async {
  // First, prove the camera move produced requests at all.
  while (server.tilesServed < minimumNewTiles) {
    await onPoll();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  // Then wait for the burst to end: a full second with no new request. The
  // second is taken in ten slices so the sampler keeps running through it; a
  // burst on loopback is over in well under a second and a single sample at
  // the end would miss the peak.
  var seen = server.tilesServed;
  while (true) {
    for (var i = 0; i < 10; i++) {
      await onPoll();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (server.tilesServed == seen) return;
    seen = server.tilesServed;
  }
}

/// Serves one raster style and an endless supply of large, cacheable tiles.
///
/// The tile bytes are random rather than a real PNG: MapLibre Native writes a
/// response to the ambient cache as soon as it arrives, before the tile worker
/// decodes it, so the cache fills either way and the map simply draws nothing.
class _TileServer {
  _TileServer._(this._server, this._tile);

  final HttpServer _server;
  final List<int> _tile;

  /// Tiles served since the counter was last reset. Read by the test to know
  /// when a camera move has finished loading.
  int tilesServed = 0;

  String get styleUrl => 'http://${_server.address.host}:${_server.port}/style';

  static Future<_TileServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final random = Random(1);
    final tile = List<int>.generate(_tileBytes, (_) => random.nextInt(256));
    final tileServer = _TileServer._(server, tile);
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
            'tiles': [
              'http://${_server.address.host}:${_server.port}/tiles/{z}/{x}/{y}',
            ],
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

/// Awaits [future] while pumping frames, failing with [label] if it doesn't
/// complete within the timeout (avoids hanging the whole suite on a stuck map).
Future<T> _await<T>(
  WidgetTester tester,
  Future<T> future,
  String label, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  var done = false;
  T? result;
  unawaited(
    future.then((value) {
      done = true;
      result = value;
    }),
  );
  while (!done) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $label');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return result as T;
}
