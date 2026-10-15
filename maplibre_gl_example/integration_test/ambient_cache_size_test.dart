// Integration test for `setMaximumAmbientCacheSize` on Android and iOS.
//
// The ambient cache lives in MapLibre Native, so a unit test with a mocked
// channel can only show that Dart sends the right message. This test drives
// the real SDK: it serves tiles from an HTTP server inside the test process,
// loads a map that fetches them, and watches the offline database file that
// backs the cache. Case one sets a 2 MB limit, loads far more than that, and
// checks the file never grew past it. Case two repeats the load with the SDK's
// 50 MB default and checks the file did grow past 2 MB, so case one cannot
// pass just because the load was too small to matter.
//
// Run on Android or iOS:
//   flutter test integration_test/ambient_cache_size_test.dart -d <device id>
//
// Web has no ambient cache, so there the tests return early.
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';
import 'support/tile_server.dart'
    if (dart.library.io) 'support/tile_server_io.dart';

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
/// cached: a cached tile would never reach the server.
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

  group('setMaximumAmbientCacheSize', () {
    late TileServer server;

    setUpAll(() async {
      if (kIsWeb) return;
      server = await TileServer.start(tileBytes: _tileBytes);
      // Start from an empty store, once. Resetting between cases, after a map
      // had used the store, left the next case's writes invisible on disk.
      await resetOfflineDatabase();
    });

    tearDownAll(() async {
      if (kIsWeb) return;
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
            'the control run must outgrow the limit of the previous case, '
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
  });
}

/// Applies [limit], loads tiles at every one of [stops], and returns the
/// largest size the database file reached while they loaded, in bytes.
///
/// The peak is sampled while tiles stream in: the SDK vacuums the database
/// after evicting, so the file can shrink after the last insert and a size
/// read once at the end would understate how large the store got.
Future<int> _fillCache(
  WidgetTester tester,
  TileServer server, {
  required int limit,
  required List<LatLng> stops,
}) async {
  await setMaximumAmbientCacheSize(limit);
  server.tilesServed = 0;

  final path = await getOfflineDatabasePath();
  if (path == null) fail('getOfflineDatabasePath returned null');
  var peak = 0;
  Future<void> sample() async {
    final size = await fileSize(path);
    if (size > peak) peak = size;
  }

  // Fill the screen, so every stop pulls a full viewport of tiles.
  final view = tester.view;
  final controller = await pumpMap(
    tester,
    styleString: server.styleUrl,
    initialCameraPosition: CameraPosition(target: stops.first, zoom: _zoom),
    size: view.physicalSize / view.devicePixelRatio,
  );

  for (final stop in stops) {
    final before = server.tilesServed;
    // Zoom is set on every move: on iOS the first tiles were requested at
    // zoom 2, before the initial camera had been applied.
    await pumpUntil(
      tester,
      controller.moveCamera(CameraUpdate.newLatLngZoom(stop, _zoom)),
      'moveCamera to $stop',
    );
    // Wait until the server has seen new tiles and then gone quiet, so
    // nothing is still in flight when the map is torn down.
    await pumpUntil(
      tester,
      _serverQuiet(server, minimumTiles: before + 1, onPoll: sample),
      'tiles at $stop',
      timeout: const Duration(seconds: 30),
    );
  }

  // Tear the map down and give the SDK's database thread a moment to flush
  // the last writes before the file is measured.
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpFor(tester, const Duration(seconds: 1));

  await sample();
  debugPrint(
    'ambient cache: limit $limit bytes, ${server.tilesServed} tiles served, '
    'database peaked at $peak bytes, ${await fileSize(path)} at the end',
  );
  return peak;
}

/// Completes once [server] has served at least [minimumTiles] and then
/// received no request for a second. [onPoll] runs every 100 ms meanwhile, so
/// the database is measured while a burst of tiles is being written.
Future<void> _serverQuiet(
  TileServer server, {
  required int minimumTiles,
  required Future<void> Function() onPoll,
}) async {
  Future<void> poll() async {
    await onPoll();
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  // First, prove the camera move produced requests at all.
  while (server.tilesServed < minimumTiles) {
    await poll();
  }
  // Then wait for a full second without a new request, sampling throughout:
  // a burst on loopback is over well within a second.
  var seen = server.tilesServed;
  while (true) {
    for (var i = 0; i < 10; i++) {
      await poll();
    }
    if (server.tilesServed == seen) return;
    seen = server.tilesServed;
  }
}
