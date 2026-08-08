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
