import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel rendering control', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async {
              methodCalls.add(methodCall);
              return null;
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    test('pauseMap invokes map#pause', () async {
      await platform.pauseMap();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#pause');
    });

    test('resumeMap invokes map#resume', () async {
      await platform.resumeMap();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#resume');
    });
  });
}
