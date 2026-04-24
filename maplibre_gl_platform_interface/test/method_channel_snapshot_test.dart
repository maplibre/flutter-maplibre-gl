import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Snapshot', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    /// Fake PNG bytes returned by the mock method channel.
    final fakePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'map#takeSnapshot':
                  return fakePng;
                case 'map#update':
                  return <String, dynamic>{
                    'bearing': 0.0,
                    'target': <double>[0.0, 0.0],
                    'tilt': 0.0,
                    'zoom': 10.0,
                  };
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('takeSnapshot sends correct method without dimensions', () async {
      final result = await platform.takeSnapshot();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#takeSnapshot');
      final args = methodCalls[0].arguments as Map;
      expect(args.containsKey('width'), isFalse);
      expect(args.containsKey('height'), isFalse);
      expect(result, fakePng);
    });

    test('takeSnapshot sends width and height when provided', () async {
      final result = await platform.takeSnapshot(width: 800, height: 600);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#takeSnapshot');
      final args = methodCalls[0].arguments as Map;
      expect(args['width'], 800);
      expect(args['height'], 600);
      expect(result, fakePng);
    });

    test('takeSnapshot throws when platform returns null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async => null,
          );

      expect(
        () => platform.takeSnapshot(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
