import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapLibreGlobalPlatform', () {
    late MapLibreGlobalPlatform unregistered;

    setUp(() => unregistered = MapLibreGlobalPlatform.instance);
    tearDown(() => MapLibreGlobalPlatform.instance = unregistered);

    test('is not registered until an instance is installed', () {
      expect(MapLibreGlobalPlatform.isRegistered, isFalse);

      MapLibreGlobalPlatform.instance = _PreWarmOnlyPlatform();
      expect(MapLibreGlobalPlatform.isRegistered, isTrue);

      MapLibreGlobalPlatform.instance = unregistered;
      expect(MapLibreGlobalPlatform.isRegistered, isFalse);
    });

    // App code awaits preWarm() and ensureWebLibraryLoaded() unconditionally,
    // so on a host where nothing registered both have to complete.
    test('the default completes preWarm and ensureLibraryLoaded', () async {
      await expectLater(unregistered.preWarm(), completes);
      await expectLater(unregistered.ensureLibraryLoaded(), completes);
    });

    test('the default fails the other calls', () async {
      await expectLater(
        unregistered.getListOfRegions(),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  // A platform written before the plugin-wide calls joined the class
  // overrides only preWarm and ensureLibraryLoaded. The rest must fail the
  // future they return, the way an unsupported call does, rather than throw
  // from the call itself.
  group('members a platform does not override', () {
    final platform = _PreWarmOnlyPlatform();
    final definition = OfflineRegionDefinition(
      bounds: LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      ),
      mapStyleUrl: 'https://example.com/style.json',
      minZoom: 5.0,
      maxZoom: 15.0,
    );
    final calls = <String, Future<Object?> Function()>{
      'installOfflineMapTiles': () => platform.installOfflineMapTiles('db'),
      'setOffline': () => platform.setOffline(true),
      'setHttpHeaders': () => platform.setHttpHeaders({}),
      'mergeOfflineRegions': () => platform.mergeOfflineRegions('path'),
      'getOfflineDatabasePath': platform.getOfflineDatabasePath,
      'getListOfRegions': platform.getListOfRegions,
      'updateOfflineRegionMetadata':
          () => platform.updateOfflineRegionMetadata(1, {}),
      'setOfflineTileCountLimit': () => platform.setOfflineTileCountLimit(1),
      'setOfflineMaxConcurrentRequests':
          () => platform.setOfflineMaxConcurrentRequests(maxRequestsPerHost: 1),
      'pauseOfflineRegionDownload':
          () => platform.pauseOfflineRegionDownload(1),
      'resumeOfflineRegionDownload':
          () => platform.resumeOfflineRegionDownload(1),
      'getOfflineRegionStatus': () => platform.getOfflineRegionStatus(1),
      'deleteOfflineRegion': () => platform.deleteOfflineRegion(1),
      'clearAmbientCache': platform.clearAmbientCache,
      'setMaximumAmbientCacheSize':
          () => platform.setMaximumAmbientCacheSize(0),
      'resetOfflineDatabase': platform.resetOfflineDatabase,
      'downloadOfflineRegion': () => platform.downloadOfflineRegion(definition),
    };

    for (final MapEntry(key: method, value: call) in calls.entries) {
      test('$method fails its future with UnimplementedError', () async {
        late Future<Object?> result;
        expect(() => result = call(), returnsNormally);

        await expectLater(
          result,
          throwsA(
            isA<UnimplementedError>().having(
              (e) => e.message,
              'message',
              '$method() is not implemented.',
            ),
          ),
        );
      });
    }

    test('catchError receives the error', () async {
      Object? caught;
      await platform.getListOfRegions().catchError((Object e) {
        caught = e;
        return <OfflineRegion>[];
      });

      expect(caught, isA<UnimplementedError>());
    });
  });

  group('MapLibreJsSource', () {
    test('cdn is the default shape with a 20 second timeout', () {
      const source = MapLibreJsSource.cdn();

      expect(source.scriptUrl, isNull);
      expect(source.styleUrl, isNull);
      expect(source.preloaded, isFalse);
      expect(source.timeout, const Duration(seconds: 20));
    });

    test('urls carries the given URLs', () {
      const source = MapLibreJsSource.urls(
        scriptUrl: 'https://example.com/maplibre-gl.js',
        styleUrl: 'https://example.com/maplibre-gl.css',
      );

      expect(source.scriptUrl, 'https://example.com/maplibre-gl.js');
      expect(source.styleUrl, 'https://example.com/maplibre-gl.css');
      expect(source.preloaded, isFalse);
    });

    test('preloaded injects nothing', () {
      const source = MapLibreJsSource.preloaded(timeout: Duration(seconds: 5));

      expect(source.scriptUrl, isNull);
      expect(source.styleUrl, isNull);
      expect(source.preloaded, isTrue);
      expect(source.timeout, const Duration(seconds: 5));
    });

    test('nothing is configured by default', () {
      expect(MapLibreJsSource.configured, isNull);
    });
  });
}

/// A platform that implements only the members the class started with.
class _PreWarmOnlyPlatform extends MapLibreGlobalPlatform {
  @override
  Future<void> preWarm() async {}

  @override
  Future<void> ensureLibraryLoaded() async {}
}
