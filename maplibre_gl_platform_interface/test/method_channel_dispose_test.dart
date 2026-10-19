import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel dispose', () {
    test('before initPlatform does not throw (#1048)', () {
      // A map widget removed before its platform view exists disposes a
      // platform whose channel was never created.
      final platform = MapLibreMethodChannel();
      var callbackCalls = 0;
      platform.onMapStyleLoadedPlatform.add((_) => callbackCalls++);

      expect(platform.dispose, returnsNormally);

      // The callbacks are still cleared.
      platform.onMapStyleLoadedPlatform.call(null);
      expect(callbackCalls, 0);
    });

    test('before initPlatform, other calls fail with a StateError', () {
      final platform = MapLibreMethodChannel();
      expect(() => platform.getLayerIds(), throwsStateError);
    });

    test('after initPlatform removes the channel handler', () async {
      const channel = MethodChannel('plugins.flutter.io/maplibre_gl_0');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (methodCall) async => null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final platform = MapLibreMethodChannel();
      await platform.initPlatform(0);
      var styleLoads = 0;
      platform.onMapStyleLoadedPlatform.add((_) => styleLoads++);

      platform.dispose();

      ByteData? reply;
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('map#onStyleLoaded'),
        ),
        (data) => reply = data,
      );
      expect(styleLoads, 0);
      expect(reply, isNull);
    });
  });
}
