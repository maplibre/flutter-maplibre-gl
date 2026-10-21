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
