import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Language', () {
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

    test('setMapLanguage sends correct method and arguments', () async {
      await platform.setMapLanguage('zh-Hant');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#setMapLanguage');
      final args = methodCalls[0].arguments as Map;
      expect(args['language'], 'zh-Hant');
    });

    test('setMapLanguage forwards each locale code unchanged', () async {
      for (final language in const ['en', 'zh-Hans', 'zh-Hant', 'ja', 'fr']) {
        methodCalls.clear();
        await platform.setMapLanguage(language);

        expect(methodCalls.length, 1);
        final args = methodCalls[0].arguments as Map;
        expect(args['language'], language);
      }
    });

    test('matchMapLanguageWithDeviceDefault sends correct method', () async {
      await platform.matchMapLanguageWithDeviceDefault();

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'map#matchMapLanguageWithDeviceDefault');
      expect(methodCalls[0].arguments, isNull);
    });
  });
}
