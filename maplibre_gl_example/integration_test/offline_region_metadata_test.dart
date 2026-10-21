// Integration test for `updateOfflineRegionMetadata` on Android and iOS.
//
// iOS had no handler for the call, so it failed with a MissingPluginException.
// The test downloads a tiny region from an HTTP server inside the test process,
// so it never needs the network, then replaces the region's metadata and
// checks that both the returned region and getListOfRegions carry the new
// metadata under the same id. A second case checks that an unknown id fails
// with the same error code on both platforms, and a third that two downloads
// started together both finish.
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

    testWidgets('an unknown id fails with UpdateMetadataError', (
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

      await expectPlatformError(
        tester,
        updateOfflineRegionMetadata(unknownId, {'name': 'nobody'}),
        'updateOfflineRegionMetadata with an unknown id',
        code: 'UpdateMetadataError',
      );
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
