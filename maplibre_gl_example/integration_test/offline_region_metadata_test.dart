// Integration test for `updateOfflineRegionMetadata` on Android and iOS.
//
// iOS had no handler for the call, so it failed with a MissingPluginException.
// The test downloads a tiny region from an HTTP server inside the test process,
// so it never needs the network, then replaces the region's metadata and
// checks that both the returned region and getListOfRegions carry the new
// metadata under the same id. A second case checks that an unknown id fails
// with the same error code on both platforms.
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
import 'package:flutter/services.dart' show PlatformException;
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

      await expectLater(
        pumpUntil(
          tester,
          updateOfflineRegionMetadata(unknownId, {'name': 'nobody'}),
          'updateOfflineRegionMetadata with an unknown id',
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'UpdateMetadataError',
          ),
        ),
      );
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
}) async {
  final finished = Completer<void>();
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
      metadata: metadata,
      onEvent: (event) {
        if (finished.isCompleted) return;
        if (event is Success) finished.complete();
        if (event is Error) finished.completeError(event.cause);
      },
    ),
    'downloadOfflineRegion',
  );
  await pumpUntil(tester, finished.future, 'the offline download to finish');
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
