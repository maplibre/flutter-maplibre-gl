import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/maplibre_gl'),
          (methodCall) async {
            methodCalls.add(methodCall);
            return null;
          },
        );
  });

  group('MapLibreGlobalPlatform', () {
    test('defaults to the method-channel implementation', () {
      expect(
        MapLibreGlobalPlatform.instance,
        isA<MapLibreGlobalMethodChannel>(),
      );
    });
  });

  group('MapLibreGlobalMethodChannel', () {
    test('preWarm sends the preWarm method call', () async {
      await MapLibreGlobalMethodChannel().preWarm();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'preWarm');
    });

    test('preWarm swallows MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl'),
            (methodCall) async {
              throw MissingPluginException('not implemented');
            },
          );

      await expectLater(MapLibreGlobalMethodChannel().preWarm(), completes);
    });

    // Android and iOS have nothing to load, so the default implementation
    // must stay an immediate no-op: app code awaits ensureWebLibraryLoaded()
    // unconditionally on every platform.
    test(
      'ensureLibraryLoaded completes without touching the channel',
      () async {
        await expectLater(
          MapLibreGlobalMethodChannel().ensureLibraryLoaded(),
          completes,
        );

        expect(methodCalls, isEmpty);
      },
    );
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
