// The Android and iOS path of the global functions: they go through the
// Pigeon-generated MapLibreGlobalHostApi, replaced here by a fake that records
// the calls. Web throws an UnsupportedError per call instead, which
// maplibre_gl_web tests on its own, hence vm only.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl/src/native/messages.g.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show MapLibreGlobalMethodChannel, MapLibreGlobalPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGlobalHostApi api;

  final fakeRegionJson = json.encode({
    'id': 1,
    'definition': {
      'bounds': [
        [10.0, 20.0],
        [30.0, 40.0],
      ],
      'mapStyleUrl': 'https://example.com/style.json',
      'minZoom': 5.0,
      'maxZoom': 15.0,
      'includeIdeographs': false,
    },
    'metadata': <String, dynamic>{},
  });

  final definition = OfflineRegionDefinition(
    bounds: LatLngBounds(
      southwest: const LatLng(10.0, 20.0),
      northeast: const LatLng(30.0, 40.0),
    ),
    mapStyleUrl: 'https://example.com/style.json',
    minZoom: 5.0,
    maxZoom: 15.0,
  );

  setUp(() {
    api = _FakeGlobalHostApi(regionJson: fakeRegionJson);
    MapLibreNativePlugin.registerWith(globalHostApi: api);
  });

  tearDown(
    () => MapLibreGlobalPlatform.instance = MapLibreGlobalMethodChannel(),
  );

  /// What native does while a download runs: an event for the download
  /// Dart started, tagged with the id Dart chose.
  Future<void> sendDownloadEvent(PgOfflineDownloadEvent event) =>
      (MapLibreGlobalPlatform.instance as MapLibreOfflineDownloadFlutterApi)
          .onDownloadEvent(api.lastDownloadId!, event);

  group('setOffline', () {
    test('sends the flag on Android', () async {
      await setOffline(true);

      expect(api.calls, [
        ['setOffline', true],
      ]);
    });

    test('throws UnsupportedError on iOS and sends nothing', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => setOffline(true),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('not available on iOS'), contains('Android only')),
          ),
        ),
      );
      expect(api.calls, isEmpty);
    });
  });

  test('setHttpHeaders sends the headers', () async {
    await setHttpHeaders({'Authorization': 'Bearer token'});

    expect(api.calls, [
      [
        'setHttpHeaders',
        {'Authorization': 'Bearer token'},
      ],
    ]);
  });

  test('installOfflineMapTiles sends the path', () async {
    await installOfflineMapTiles('assets/cache.db');

    expect(api.calls, [
      ['installOfflineMapTiles', 'assets/cache.db'],
    ]);
  });

  test('deleteOfflineRegion sends the id', () async {
    await deleteOfflineRegion(42);

    expect(api.calls, [
      ['deleteOfflineRegion', 42],
    ]);
  });

  test('getListOfRegions parses the regions', () async {
    final regions = await getListOfRegions();

    expect(regions, hasLength(1));
    expect(regions.single.id, 1);
    expect(regions.single.definition.minZoom, 5.0);
  });

  test('updateOfflineRegionMetadata sends the metadata', () async {
    final region = await updateOfflineRegionMetadata(1, {'name': 'x'});

    expect(api.calls, [
      [
        'updateOfflineRegionMetadata',
        1,
        {'name': 'x'},
      ],
    ]);
    expect(region.id, 1);
  });

  test('mergeOfflineRegions sends the path and parses the regions', () async {
    final regions = await mergeOfflineRegions('/data/other.db');

    expect(api.calls, [
      ['mergeOfflineRegions', '/data/other.db'],
    ]);
    expect(regions.single.id, 1);
  });

  group('getOfflineDatabasePath', () {
    test('returns the path native answers', () async {
      api.databasePath = '/data/offline.db';

      expect(await getOfflineDatabasePath(), '/data/offline.db');
    });

    test('returns null when native has no path', () async {
      expect(await getOfflineDatabasePath(), isNull);
    });
  });

  group('exportOfflineDatabase', () {
    test('returns null when there is no database path', () async {
      expect(await exportOfflineDatabase('/tmp/copy.db'), isNull);
    });

    test('copies the database and its sidecars', () async {
      final dir = Directory.systemTemp.createTempSync('maplibre_export_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/offline.db').writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/offline.db-wal').writeAsBytesSync([4]);
      api.databasePath = '${dir.path}/offline.db';
      final destination = '${dir.path}/copy.db';

      expect(await exportOfflineDatabase(destination), destination);
      expect(File(destination).readAsBytesSync(), [1, 2, 3]);
      expect(File('$destination-wal').readAsBytesSync(), [4]);
      expect(File('$destination-shm').existsSync(), isFalse);
    });
  });

  test('setOfflineTileCountLimit sends the limit', () async {
    await setOfflineTileCountLimit(6000);

    expect(api.calls, [
      ['setOfflineTileCountLimit', 6000],
    ]);
  });

  test('clearAmbientCache reaches native', () async {
    await clearAmbientCache();

    expect(api.calls, [
      ['clearAmbientCache'],
    ]);
  });

  group('downloadOfflineRegion', () {
    test('sends the definition and metadata and returns the region', () async {
      final region = await downloadOfflineRegion(
        definition,
        metadata: {'name': 'test'},
      );

      expect(api.calls.single[0], 'downloadOfflineRegion');
      expect(api.calls.single[2], definition.toMap());
      expect(api.calls.single[3], {'name': 'test'});
      expect(region.id, 1);
    });

    test('gives every download its own id', () async {
      await downloadOfflineRegion(definition);
      await downloadOfflineRegion(definition);

      final ids = api.calls.map((call) => call[1]).toList();
      expect(ids.toSet(), hasLength(2));
    });

    test('does not hand out an id again after a hot restart', () async {
      await downloadOfflineRegion(definition);
      final earlierId = api.lastDownloadId!;

      // A hot restart registers a new instance while the download native
      // started for the old one can still send events.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      MapLibreNativePlugin.registerWith(globalHostApi: api);
      final statuses = <DownloadRegionStatus>[];
      await downloadOfflineRegion(definition, onEvent: statuses.add);
      await (MapLibreGlobalPlatform.instance
              as MapLibreOfflineDownloadFlutterApi)
          .onDownloadEvent(
            earlierId,
            PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
          );

      expect(api.lastDownloadId, isNot(earlierId));
      expect(statuses, isEmpty);
    });

    test('onEvent receives start, progress and success', () async {
      final statuses = <DownloadRegionStatus>[];
      await downloadOfflineRegion(definition, onEvent: statuses.add);

      await sendDownloadEvent(
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );
      await sendDownloadEvent(
        PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.progress,
          progress: 50.0,
          completedResourceCount: 100,
          requiredResourceCount: 200,
          completedResourceSize: 1024000,
        ),
      );
      await sendDownloadEvent(
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.success),
      );

      expect(statuses, hasLength(3));
      expect((statuses[0] as InProgress).progress, 0.0);
      final progress = statuses[1] as InProgress;
      expect(progress.progress, 50.0);
      expect(progress.completedResourceCount, 100);
      expect(progress.requiredResourceCount, 200);
      expect(progress.completedResourceSize, 1024000);
      expect(statuses[2], isA<Success>());
    });

    test('onEvent receives an error as an Error status', () async {
      final statuses = <DownloadRegionStatus>[];
      await downloadOfflineRegion(definition, onEvent: statuses.add);

      await sendDownloadEvent(
        PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.error,
          errorCode: 'TILE_COUNT_LIMIT_EXCEEDED',
          errorMessage: 'too many tiles',
        ),
      );

      expect(statuses, hasLength(1));
      final cause = (statuses.single as Error).cause;
      expect(cause.code, 'TILE_COUNT_LIMIT_EXCEEDED');
      expect(cause.message, 'too many tiles');
    });

    test('drops the events that follow the end of a download', () async {
      final statuses = <DownloadRegionStatus>[];
      await downloadOfflineRegion(definition, onEvent: statuses.add);

      await sendDownloadEvent(
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.success),
      );
      await sendDownloadEvent(
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );

      expect(statuses, [isA<Success>()]);
    });

    test('ignores the events of a download nobody listens to', () async {
      await downloadOfflineRegion(definition);

      await expectLater(
        sendDownloadEvent(
          PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
        ),
        completes,
      );
    });

    test('fails with the error native answers', () async {
      api.downloadError = PlatformException(
        code: 'INVALID_REGION_DEFINITION',
        message: 'bad bounds',
      );

      await expectLater(
        downloadOfflineRegion(definition),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_REGION_DEFINITION',
          ),
        ),
      );
    });

    test('drops the listener when native fails the call', () async {
      // As iOS does on a definition it cannot read: no event follows.
      api.downloadError = PlatformException(code: 'INVALID_REGION_DEFINITION');
      final statuses = <DownloadRegionStatus>[];

      await expectLater(
        downloadOfflineRegion(definition, onEvent: statuses.add),
        throwsA(isA<PlatformException>()),
      );
      await sendDownloadEvent(
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );

      expect(statuses, isEmpty);
    });
  });

  test('pause and resume send the id', () async {
    await pauseOfflineRegionDownload(99);
    await resumeOfflineRegionDownload(99);

    expect(api.calls, [
      ['pauseOfflineRegionDownload', 99],
      ['resumeOfflineRegionDownload', 99],
    ]);
  });

  group('setOfflineMaxConcurrentRequests', () {
    test('sends both limits', () async {
      await setOfflineMaxConcurrentRequests(
        maxRequests: 32,
        maxRequestsPerHost: 4,
      );

      expect(api.calls, [
        ['setOfflineMaxConcurrentRequests', 32, 4],
      ]);
    });

    test('sends null for a limit not given', () async {
      await setOfflineMaxConcurrentRequests(maxRequestsPerHost: 2);

      expect(api.calls, [
        ['setOfflineMaxConcurrentRequests', null, 2],
      ]);
    });

    test('rejects a limit below 1 before reaching native', () {
      expect(
        () => setOfflineMaxConcurrentRequests(maxRequests: 0),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            'maxRequests must be >= 1 (got 0)',
          ),
        ),
      );
      expect(
        () => setOfflineMaxConcurrentRequests(maxRequestsPerHost: 0),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            'maxRequestsPerHost must be >= 1 (got 0)',
          ),
        ),
      );
      expect(api.calls, isEmpty);
    });
  });

  group('setMaximumAmbientCacheSize', () {
    test('sends the byte limit', () async {
      await setMaximumAmbientCacheSize(10 * 1024 * 1024);

      expect(api.calls, [
        ['setMaximumAmbientCacheSize', 10 * 1024 * 1024],
      ]);
    });

    test('zero is allowed, it disables ambient caching', () async {
      await setMaximumAmbientCacheSize(0);

      expect(api.calls, [
        ['setMaximumAmbientCacheSize', 0],
      ]);
    });

    test('rejects a negative limit before reaching native', () {
      expect(() => setMaximumAmbientCacheSize(-1), throwsArgumentError);
      expect(api.calls, isEmpty);
    });
  });

  test('getOfflineRegionStatus parses the status', () async {
    final status = await getOfflineRegionStatus(42);

    expect(api.calls, [
      ['getOfflineRegionStatus', 42],
    ]);
    expect(status.completedResourceCount, 150);
    expect(status.requiredResourceCount, 300);
    expect(status.completedResourceSize, 2048000);
    expect(status.isComplete, false);
    expect(status.downloadProgress, 50.0);
  });

  test('resetOfflineDatabase drops the listeners native left behind', () async {
    final statuses = <DownloadRegionStatus>[];
    await downloadOfflineRegion(definition, onEvent: statuses.add);
    final downloadId = api.lastDownloadId!;

    await resetOfflineDatabase();
    await (MapLibreGlobalPlatform.instance as MapLibreOfflineDownloadFlutterApi)
        .onDownloadEvent(
          downloadId,
          PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
        );

    expect(statuses, isEmpty);
  });

  test('resetOfflineDatabase keeps a download started meanwhile', () async {
    final earlier = <DownloadRegionStatus>[];
    await downloadOfflineRegion(definition, onEvent: earlier.add);
    final earlierId = api.lastDownloadId!;

    final reset = resetOfflineDatabase();
    final later = <DownloadRegionStatus>[];
    await downloadOfflineRegion(definition, onEvent: later.add);
    final laterId = api.lastDownloadId!;
    await reset;

    final events =
        MapLibreGlobalPlatform.instance as MapLibreOfflineDownloadFlutterApi;
    for (final id in [earlierId, laterId]) {
      await events.onDownloadEvent(
        id,
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );
    }

    expect(earlier, isEmpty);
    expect(later, [isA<InProgress>()]);
  });

  test('ensureWebLibraryLoaded completes without reaching native', () async {
    await expectLater(MapLibreMap.ensureWebLibraryLoaded(), completes);

    expect(api.calls, isEmpty);
  });

  group('preWarm', () {
    test('reaches native', () async {
      await MapLibreMap.preWarm();

      expect(api.calls, [
        ['preWarm'],
      ]);
    });

    test('does nothing when no native side answers', () async {
      // The generated client with nothing on the other end of its channel.
      MapLibreNativePlugin.registerWith(globalHostApi: MapLibreGlobalHostApi());

      await expectLater(MapLibreMap.preWarm(), completes);
    });

    test('reports other native errors', () async {
      api.preWarmError = PlatformException(code: 'error', message: 'boom');

      await expectLater(
        MapLibreMap.preWarm(),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  // The generated registrant does not run everywhere, for instance in an
  // isolate the app spawns, so the first global call installs the Android and
  // iOS implementation itself when the default is still in place.
  group('the first global call', () {
    setUp(
      () => MapLibreGlobalPlatform.instance = MapLibreGlobalMethodChannel(),
    );
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('installs the Pigeon one on ${platform.name}', () async {
        debugDefaultTargetPlatformOverride = platform;
        const channel =
            'dev.flutter.pigeon.maplibre_gl.MapLibreGlobalHostApi.getListOfRegions';
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMessageHandler(
          channel,
          (_) async => MapLibreGlobalHostApi.pigeonChannelCodec.encodeMessage([
            '[$fakeRegionJson]',
          ]),
        );
        addTearDown(() => messenger.setMockMessageHandler(channel, null));

        final regions = await getListOfRegions();

        expect(regions.single.id, 1);
        expect(
          MapLibreGlobalPlatform.instance,
          isA<MapLibreOfflineDownloadFlutterApi>(),
        );
      });
    }

    for (final platform in [
      TargetPlatform.fuchsia,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    ]) {
      test('leaves the default in place on ${platform.name}', () async {
        debugDefaultTargetPlatformOverride = platform;

        await MapLibreMap.ensureWebLibraryLoaded();

        expect(
          MapLibreGlobalPlatform.instance,
          isA<MapLibreGlobalMethodChannel>(),
        );
      });
    }

    test('keeps a subclass of the default a package installed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final custom = _CustomGlobalMethodChannel();
      MapLibreGlobalPlatform.instance = custom;

      expect(await getListOfRegions(), isEmpty);
      expect(MapLibreGlobalPlatform.instance, same(custom));
    });

    test('keeps an implementation a platform registered', () async {
      MapLibreNativePlugin.registerWith(globalHostApi: api);
      final registered = MapLibreGlobalPlatform.instance;

      await deleteOfflineRegion(1);

      expect(MapLibreGlobalPlatform.instance, same(registered));
      expect(api.calls, [
        ['deleteOfflineRegion', 1],
      ]);
    });
  });
}

/// A package's own take on the default implementation.
class _CustomGlobalMethodChannel extends MapLibreGlobalMethodChannel {
  @override
  Future<List<OfflineRegion>> getListOfRegions() async => [];
}

/// Records every call with its arguments and answers like native would.
class _FakeGlobalHostApi extends MapLibreGlobalHostApi {
  _FakeGlobalHostApi({required this.regionJson});

  final String regionJson;

  /// Each call as its name followed by its arguments.
  final List<List<Object?>> calls = [];
  int? lastDownloadId;
  PlatformException? downloadError;
  PlatformException? preWarmError;

  /// What getOfflineDatabasePath answers.
  String? databasePath;

  static final String _statusJson = json.encode({
    'completedResourceCount': 150,
    'requiredResourceCount': 300,
    'completedResourceSize': 2048000,
    'isComplete': false,
    'downloadProgress': 50.0,
  });

  @override
  Future<void> preWarm() async {
    calls.add(['preWarm']);
    if (preWarmError != null) throw preWarmError!;
  }

  @override
  Future<void> installOfflineMapTiles(String tilesDb) async =>
      calls.add(['installOfflineMapTiles', tilesDb]);

  @override
  Future<void> setOffline(bool offline) async =>
      calls.add(['setOffline', offline]);

  @override
  Future<void> setHttpHeaders(Map<String, String> headers) async =>
      calls.add(['setHttpHeaders', headers]);

  @override
  Future<String> mergeOfflineRegions(String path) async {
    calls.add(['mergeOfflineRegions', path]);
    return '[$regionJson]';
  }

  @override
  Future<String?> getOfflineDatabasePath() async => databasePath;

  @override
  Future<String> getListOfRegions() async => '[$regionJson]';

  @override
  Future<String> updateOfflineRegionMetadata(
    int id,
    Map<String, Object?> metadata,
  ) async {
    calls.add(['updateOfflineRegionMetadata', id, metadata]);
    return regionJson;
  }

  @override
  Future<void> setOfflineMaxConcurrentRequests(
    int? maxRequests,
    int? maxRequestsPerHost,
  ) async => calls.add([
    'setOfflineMaxConcurrentRequests',
    maxRequests,
    maxRequestsPerHost,
  ]);

  @override
  Future<void> pauseOfflineRegionDownload(int id) async =>
      calls.add(['pauseOfflineRegionDownload', id]);

  @override
  Future<void> resumeOfflineRegionDownload(int id) async =>
      calls.add(['resumeOfflineRegionDownload', id]);

  @override
  Future<String> getOfflineRegionStatus(int id) async {
    calls.add(['getOfflineRegionStatus', id]);
    return _statusJson;
  }

  @override
  Future<void> setOfflineTileCountLimit(int limit) async =>
      calls.add(['setOfflineTileCountLimit', limit]);

  @override
  Future<void> deleteOfflineRegion(int id) async =>
      calls.add(['deleteOfflineRegion', id]);

  @override
  Future<void> clearAmbientCache() async => calls.add(['clearAmbientCache']);

  @override
  Future<void> setMaximumAmbientCacheSize(int bytes) async =>
      calls.add(['setMaximumAmbientCacheSize', bytes]);

  @override
  Future<void> resetOfflineDatabase() async =>
      calls.add(['resetOfflineDatabase']);

  @override
  Future<String> downloadOfflineRegion(
    int downloadId,
    Map<String, Object?> definition,
    Map<String, Object?> metadata,
  ) async {
    calls.add(['downloadOfflineRegion', downloadId, definition, metadata]);
    lastDownloadId = downloadId;
    if (downloadError != null) throw downloadError!;
    return regionJson;
  }
}
