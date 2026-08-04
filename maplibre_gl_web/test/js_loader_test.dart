// These tests exercise dart:js_interop and the real browser global scope, so
// they only run under `flutter test --platform chrome`; the VM run skips them.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/global_web_platform.dart';
import 'package:maplibre_gl_web/src/js_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    MapLibreJsLoader.debugReset();
    MapLibreJsSource.configured = null;
    globalContext.delete('maplibregl'.toJS);
  });

  tearDown(() {
    MapLibreJsLoader.debugReset();
    MapLibreJsSource.configured = null;
    globalContext.delete('maplibregl'.toJS);
    MapLibreGlobalPlatform.instance = MapLibreGlobalMethodChannel();
  });

  group('MapLibreJsLoader.ensureLoaded', () {
    test('runs the work once for concurrent and repeated callers', () async {
      var calls = 0;
      final gate = Completer<void>();
      MapLibreJsLoader.loadResources = (source) {
        calls++;
        return gate.future;
      };

      final first = MapLibreJsLoader.ensureLoaded();
      final second = MapLibreJsLoader.ensureLoaded();
      gate.complete();
      await first;
      await second;
      // A call after completion must reuse the memo, not load again.
      await MapLibreJsLoader.ensureLoaded();

      expect(calls, 1);
    });

    test('a failure clears the memo so a later call retries', () async {
      var calls = 0;
      MapLibreJsLoader.loadResources = (source) async {
        calls++;
        throw MapLibreJsLoaderException('boom');
      };

      await expectLater(
        MapLibreJsLoader.ensureLoaded(),
        throwsA(isA<MapLibreJsLoaderException>()),
      );

      MapLibreJsLoader.loadResources = (source) async {
        calls++;
      };
      await MapLibreJsLoader.ensureLoaded();

      expect(calls, 2);
    });

    test('returns immediately when the global is already present', () async {
      globalContext.setProperty('maplibregl'.toJS, JSObject());
      MapLibreJsLoader.loadResources = (source) async {
        fail('loadResources must not run when maplibregl already exists');
      };

      await expectLater(MapLibreJsLoader.ensureLoaded(), completes);
    });

    test('defaults to the pinned CDN source', () async {
      MapLibreJsSource? seen;
      MapLibreJsLoader.loadResources = (source) async {
        seen = source;
      };

      await MapLibreJsLoader.ensureLoaded();

      expect(seen, isNotNull);
      expect(seen!.scriptUrl, isNull);
      expect(seen!.preloaded, isFalse);
      expect(seen!.timeout, const Duration(seconds: 20));
    });

    test('passes the configured source through unchanged', () async {
      const configured = MapLibreJsSource.urls(
        scriptUrl: 'assets/maplibre-gl.js',
        styleUrl: 'assets/maplibre-gl.css',
        timeout: Duration(seconds: 5),
      );
      MapLibreJsSource.configured = configured;
      MapLibreJsSource? seen;
      MapLibreJsLoader.loadResources = (source) async {
        seen = source;
      };

      await MapLibreJsLoader.ensureLoaded();

      expect(seen, same(configured));
    });

    test(
      'preloaded times out with a clear error, then retries clean',
      () async {
        // The preloaded path injects nothing, so this exercises the real
        // loadResources without touching the network.
        MapLibreJsSource.configured = const MapLibreJsSource.preloaded(
          timeout: Duration(milliseconds: 50),
        );

        await expectLater(
          MapLibreJsLoader.ensureLoaded(),
          throwsA(
            isA<MapLibreJsLoaderException>().having(
              (e) => e.message,
              'message',
              contains('preloaded'),
            ),
          ),
        );

        // The failure must not poison the session: once the page-provided
        // global appears, the next call succeeds.
        globalContext.setProperty('maplibregl'.toJS, JSObject());
        await expectLater(MapLibreJsLoader.ensureLoaded(), completes);
      },
    );
  });

  group('plugin registration', () {
    test('registerWith installs the web global platform, so preWarm from '
        'main() reaches the loader and not the method channel', () async {
      MapLibreMapPlugin.registerWith(webPluginRegistrar);

      expect(MapLibreGlobalPlatform.instance, isA<MapLibreGlobalWeb>());

      var loaderCalls = 0;
      var prewarmCalls = 0;
      MapLibreJsLoader.loadResources = (source) async {
        loaderCalls++;
        // Simulate the injected script having executed: the global appears,
        // exposing the prewarm() entry point.
        final fake = JSObject();
        fake.setProperty(
          'prewarm'.toJS,
          (() {
            prewarmCalls++;
          }).toJS,
        );
        globalContext.setProperty('maplibregl'.toJS, fake);
      };

      await MapLibreGlobalPlatform.instance.preWarm();

      expect(loaderCalls, 1);
      expect(prewarmCalls, 1);
    });

    test(
      'ensureLibraryLoaded on the web platform goes through the loader',
      () async {
        var loaderCalls = 0;
        MapLibreJsLoader.loadResources = (source) async {
          loaderCalls++;
        };

        await MapLibreGlobalWeb().ensureLibraryLoaded();

        expect(loaderCalls, 1);
      },
    );
  });
}
