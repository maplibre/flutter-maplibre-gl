// Integration test for `updateOfflineRegionMetadata` and the offline error
// codes on Android and iOS.
//
// iOS had no handler for the call, so it failed with a MissingPluginException.
// The test downloads a tiny region from an HTTP server inside the test process,
// so it never needs the network, then replaces the region's metadata and
// checks that both the returned region and getListOfRegions carry the new
// metadata under the same id. A second case checks that two downloads started
// together both finish.
//
// The offline errors group checks that both platforms answer the same code and
// message: REGION_NOT_FOUND for an unknown id in every call that takes one,
// and INVALID_ARGUMENT for a negative tile count limit or ambient cache size
// and for a concurrent request limit below 1.
//
// The resume group pauses a download while the server holds its tiles back.
// One case resumes it and waits for its Success event. The other comes as
// close to an app restart as one run can: it exports the store with the
// paused region in it, deletes the region and merges the copy back, so the
// region is stored but no download of this session follows it. It resumes
// without events on both platforms and completes, and resuming it once
// complete leaves it as it is.
//
// The empty getListOfRegions right after launch on iOS (#381) is not covered:
// it needs a cold start of the app with regions already stored, which a single
// integration test run cannot do.
//
// Run on Android or iOS:
//   flutter test integration_test/offline_region_metadata_test.dart -d <device id>
//
// Web has no offline regions, so there the tests return early.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
// The generated client reaches native with arguments the public functions
// reject in Dart first, to check the native answer to them.
// ignore: implementation_imports
import 'package:maplibre_gl/src/native/messages.g.dart'
    show MapLibreGlobalHostApi;
import 'package:path_provider/path_provider.dart';

import 'support/map_harness.dart';
import 'support/tile_server.dart'
    if (dart.library.io) 'support/tile_server_io.dart';

/// Small tiles: the test is about the region record, not the tile data.
const int _tileBytes = 1024;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('updateOfflineRegionMetadata', () {
    late TileServer server;
    final downloaded = <int>[];

    setUpAll(() async {
      if (kIsWeb) return;
      server = await TileServer.start(tileBytes: _tileBytes);
    });

    tearDownAll(() async {
      if (kIsWeb) return;
      for (final id in downloaded) {
        await deleteOfflineRegion(id);
      }
      await server.close();
    });

    testWidgets('replaces the metadata and keeps the region', (tester) async {
      if (kIsWeb) return;

      final region = await _downloadTinyRegion(
        tester,
        server,
        metadata: {'name': 'before'},
      );
      downloaded.add(region.id);
      expect(region.metadata, {'name': 'before'});

      final updated = await pumpUntil(
        tester,
        updateOfflineRegionMetadata(region.id, {
          'name': 'after',
          'pinned': true,
        }),
        'updateOfflineRegionMetadata',
      );
      expect(updated.id, region.id);
      expect(updated.metadata, {'name': 'after', 'pinned': true});
      _expectSameDefinition(updated.definition, region.definition);

      final regions = await pumpUntil(
        tester,
        getListOfRegions(),
        'getListOfRegions',
      );
      final listed = regions.where((r) => r.id == region.id).toList();
      expect(
        listed,
        hasLength(1),
        reason: 'the region should still be listed under its id',
      );
      expect(listed.single.metadata, {'name': 'after', 'pinned': true});
      _expectSameDefinition(listed.single.definition, region.definition);
    });

    testWidgets('two downloads at the same time both finish', (tester) async {
      if (kIsWeb) return;

      // Each download used to need its own setup call before it started, and
      // the second setup overwrote the first, so starting two downloads
      // together failed one of them. Areas apart from each other and from the
      // other tests' region, so none replaces another as a duplicate.
      final regions = await pumpUntil(
        tester,
        Future.wait([
          _startTinyDownload(
            server,
            metadata: {'name': 'west'},
            center: const LatLng(0, 20),
          ),
          _startTinyDownload(
            server,
            metadata: {'name': 'east'},
            center: const LatLng(0, 30),
          ),
        ]),
        'two downloads at the same time',
      );
      downloaded.addAll(regions.map((r) => r.id));

      expect(regions.map((r) => r.metadata['name']), ['west', 'east']);
      expect(regions.first.id, isNot(regions.last.id));
    });
  });

  group('offline errors', () {
    testWidgets('an unknown id fails with REGION_NOT_FOUND in every call', (
      tester,
    ) async {
      if (kIsWeb) return;

      final regions = await pumpUntil(
        tester,
        getListOfRegions(),
        'getListOfRegions',
      );
      final ids = regions.map((r) => r.id).toSet();
      var unknownId = -1;
      while (ids.contains(unknownId)) {
        unknownId--;
      }

      final calls = <String, Future<Object?> Function()>{
        'pauseOfflineRegionDownload':
            () => pauseOfflineRegionDownload(unknownId),
        'resumeOfflineRegionDownload':
            () => resumeOfflineRegionDownload(unknownId),
        'getOfflineRegionStatus': () => getOfflineRegionStatus(unknownId),
        'deleteOfflineRegion': () => deleteOfflineRegion(unknownId),
        'updateOfflineRegionMetadata':
            () => updateOfflineRegionMetadata(unknownId, {'name': 'nobody'}),
      };
      for (final MapEntry(key: method, value: call) in calls.entries) {
        final error = await expectPlatformError(
          tester,
          call(),
          '$method with an unknown id',
          code: 'REGION_NOT_FOUND',
        );
        expect(
          error.message,
          'There is no offline region with id $unknownId.',
          reason: method,
        );
      }
    });

    testWidgets('a negative tile count limit fails with INVALID_ARGUMENT', (
      tester,
    ) async {
      if (kIsWeb) return;

      final error = await expectPlatformError(
        tester,
        setOfflineTileCountLimit(-1),
        'setOfflineTileCountLimit(-1)',
        code: 'INVALID_ARGUMENT',
      );
      expect(error.message, 'limit must be >= 0 (got -1)');
    });

    testWidgets('a negative ambient cache size fails with INVALID_ARGUMENT', (
      tester,
    ) async {
      if (kIsWeb) return;

      // setMaximumAmbientCacheSize throws an ArgumentError before native.
      final error = await expectPlatformError(
        tester,
        MapLibreGlobalHostApi().setMaximumAmbientCacheSize(-1),
        'setMaximumAmbientCacheSize(-1) in native',
        code: 'INVALID_ARGUMENT',
      );
      expect(error.message, 'bytes must be >= 0 (got -1)');
    });

    testWidgets('a concurrent request limit below 1 fails with '
        'INVALID_ARGUMENT', (tester) async {
      if (kIsWeb) return;

      // setOfflineMaxConcurrentRequests asserts both before native. iOS has
      // no total limit, and still rejects one Android would reject.
      final api = MapLibreGlobalHostApi();
      final total = await expectPlatformError(
        tester,
        api.setOfflineMaxConcurrentRequests(0, null),
        'setOfflineMaxConcurrentRequests(maxRequests: 0) in native',
        code: 'INVALID_ARGUMENT',
      );
      expect(total.message, 'maxRequests must be >= 1 (got 0)');

      final perHost = await expectPlatformError(
        tester,
        api.setOfflineMaxConcurrentRequests(null, 0),
        'setOfflineMaxConcurrentRequests(maxRequestsPerHost: 0) in native',
        code: 'INVALID_ARGUMENT',
      );
      expect(perHost.message, 'maxRequestsPerHost must be >= 1 (got 0)');
    });
  });

  group('resumeOfflineRegionDownload', () {
    // A server per case: its port is part of every tile URL, so no tile of
    // one case is already in the store when the other downloads, which would
    // let a download complete before it can be paused.
    TileServer? server;
    final downloaded = <int>[];

    tearDown(() async {
      if (kIsWeb) return;
      for (final id in downloaded) {
        await deleteOfflineRegion(id);
      }
      downloaded.clear();
      await server?.close();
      server = null;
    });

    testWidgets('a paused download resumes and completes', (tester) async {
      if (kIsWeb) return;
      final tiles = server = await TileServer.start(tileBytes: _tileBytes);

      final finished = Completer<void>();
      final region = await _startPausedDownload(
        tester,
        tiles,
        name: 'paused',
        onEvent: (event) {
          if (finished.isCompleted) return;
          if (event is Success) finished.complete();
          if (event is Error) finished.completeError(event.cause);
        },
      );
      downloaded.add(region.id);

      tiles.releaseTiles();
      await pumpUntil(
        tester,
        resumeOfflineRegionDownload(region.id),
        'resumeOfflineRegionDownload',
      );
      await pumpUntil(tester, finished.future, 'the resumed download');

      final status = await pumpUntil(
        tester,
        getOfflineRegionStatus(region.id),
        'getOfflineRegionStatus',
      );
      expect(status.isComplete, isTrue);
    });

    testWidgets('a region no download of this session follows resumes', (
      tester,
    ) async {
      if (kIsWeb) return;
      final tiles = server = await TileServer.start(tileBytes: _tileBytes);

      final paused = await _startPausedDownload(
        tester,
        tiles,
        name: 'restored',
      );
      // The store as an earlier session would leave it, with the paused
      // region in it. A new directory each run, so no SQLite sidecar of an
      // earlier copy sits next to this one.
      final directory = await (await getTemporaryDirectory()).createTemp(
        'resume_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final copy = await pumpUntil(
        tester,
        exportOfflineDatabase('${directory.path}/regions.db'),
        'exportOfflineDatabase',
      );
      expect(copy, isNotNull);
      await pumpUntil(
        tester,
        deleteOfflineRegion(paused.id),
        'deleteOfflineRegion',
      );
      tiles.releaseTiles();

      final merged = await pumpUntil(
        tester,
        mergeOfflineRegions(copy!),
        'mergeOfflineRegions',
      );
      final restored = merged.singleWhere(
        (r) => r.metadata['name'] == 'restored',
      );
      downloaded.add(restored.id);

      // Android failed this resume with ResumeRegionError: no download of
      // this session followed the region.
      await pumpUntil(
        tester,
        resumeOfflineRegionDownload(restored.id),
        'resumeOfflineRegionDownload',
      );
      // No events: nothing listens to this download, so poll its status.
      await pumpUntilValue(
        tester,
        () => getOfflineRegionStatus(restored.id),
        (status) => status.isComplete,
        'the resumed region to complete',
        timeout: const Duration(seconds: 30),
      );

      // Already complete: nothing to do, and the region stays complete.
      await pumpUntil(
        tester,
        resumeOfflineRegionDownload(restored.id),
        'resumeOfflineRegionDownload of a complete region',
      );
      final status = await pumpUntil(
        tester,
        getOfflineRegionStatus(restored.id),
        'getOfflineRegionStatus',
      );
      expect(status.isComplete, isTrue);
      expect(status.completedResourceCount, status.requiredResourceCount);
    });
  });
}

/// Starts downloading a region of a few tiles from [server] with its tiles
/// held back, pauses it once the first tile request arrives, and returns it.
/// The caller releases the tiles.
Future<OfflineRegion> _startPausedDownload(
  WidgetTester tester,
  TileServer server, {
  required String name,
  void Function(DownloadRegionStatus event)? onEvent,
}) async {
  server.holdTiles();
  final region = await pumpUntil(
    tester,
    downloadOfflineRegion(
      OfflineRegionDefinition(
        bounds: LatLngBounds(
          southwest: const LatLng(-1, -1),
          northeast: const LatLng(1, 1),
        ),
        mapStyleUrl: server.styleUrl,
        minZoom: 0,
        maxZoom: 1,
      ),
      metadata: {'name': name},
      onEvent: onEvent,
    ),
    'downloadOfflineRegion',
  );
  await pumpUntilValue(
    tester,
    () async => server.tileRequests,
    (requests) => requests > 0,
    'the first tile request',
  );
  await pumpUntil(
    tester,
    pauseOfflineRegionDownload(region.id),
    'pauseOfflineRegionDownload',
  );
  final status = await pumpUntil(
    tester,
    getOfflineRegionStatus(region.id),
    'getOfflineRegionStatus while paused',
  );
  expect(status.isComplete, isFalse, reason: 'paused before any tile');
  return region;
}

/// Downloads a region of a few tiles from [server] and returns it once the
/// download has finished, so no transfer is still running when the test
/// changes or deletes it.
Future<OfflineRegion> _downloadTinyRegion(
  WidgetTester tester,
  TileServer server, {
  required Map<String, dynamic> metadata,
}) => pumpUntil(
  tester,
  _startTinyDownload(server, metadata: metadata),
  'the offline download to finish',
);

/// Starts downloading the region of a few tiles around [center] and
/// completes with it once the download has finished. Does not pump: the
/// caller does, once for any number of downloads.
Future<OfflineRegion> _startTinyDownload(
  TileServer server, {
  required Map<String, dynamic> metadata,
  LatLng center = const LatLng(0, 0),
}) async {
  final finished = Completer<void>();
  final region = await downloadOfflineRegion(
    OfflineRegionDefinition(
      bounds: LatLngBounds(
        southwest: LatLng(center.latitude - 1, center.longitude - 1),
        northeast: LatLng(center.latitude + 1, center.longitude + 1),
      ),
      mapStyleUrl: server.styleUrl,
      minZoom: 0,
      maxZoom: 1,
    ),
    metadata: metadata,
    onEvent: (event) {
      if (finished.isCompleted) return;
      if (event is Success) finished.complete();
      if (event is Error) finished.completeError(event.cause);
    },
  );
  await finished.future;
  return region;
}

void _expectSameDefinition(
  OfflineRegionDefinition actual,
  OfflineRegionDefinition expected,
) {
  expect(actual.mapStyleUrl, expected.mapStyleUrl);
  expect(actual.minZoom, expected.minZoom);
  expect(actual.maxZoom, expected.maxZoom);
  expect(actual.bounds, expected.bounds);
}
