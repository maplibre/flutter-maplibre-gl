import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Feature State', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    /// What the mocked native side replies to `source#getFeatureState`.
    Object? getFeatureStateReply;

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];
      getFeatureStateReply = null;

      // The channel implementation serves Android and iOS; these tests
      // exercise the Android path, the iOS group below overrides this.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'source#getFeatureState':
                  return getFeatureStateReply;
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('setFeatureState sends correct method and arguments', () async {
      await platform.setFeatureState('states', '42', {'hover': true});

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#setFeatureState');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'states');
      expect(args['featureId'], '42');
      expect(args['state'], {'hover': true});
      expect(args['sourceLayer'], isNull);
    });

    test('setFeatureState forwards the sourceLayer', () async {
      await platform.setFeatureState('terrain', '42', {
        'hover': true,
        'score': 3,
      }, sourceLayer: 'contour');

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#setFeatureState');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'terrain');
      expect(args['featureId'], '42');
      expect(args['state'], {'hover': true, 'score': 3});
      expect(args['sourceLayer'], 'contour');
    });

    // The native side picks the operation from which arguments are present:
    // featureId and stateKey remove one key, featureId alone removes that
    // feature's whole state, neither resets the whole source. Each shape must
    // therefore arrive with exactly the nulls the caller left unset.
    test('removeFeatureState with featureId and stateKey sends both', () async {
      await platform.removeFeatureState(
        'states',
        featureId: '42',
        stateKey: 'hover',
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#removeFeatureState');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'states');
      expect(args['featureId'], '42');
      expect(args['stateKey'], 'hover');
      expect(args['sourceLayer'], isNull);
    });

    test(
      'removeFeatureState with only featureId leaves stateKey null',
      () async {
        await platform.removeFeatureState(
          'terrain',
          featureId: '42',
          sourceLayer: 'contour',
        );

        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'source#removeFeatureState');
        final args = methodCalls[0].arguments as Map;
        expect(args['sourceId'], 'terrain');
        expect(args['featureId'], '42');
        expect(args['stateKey'], isNull);
        expect(args['sourceLayer'], 'contour');
      },
    );

    test(
      'removeFeatureState with only the sourceId leaves both null',
      () async {
        await platform.removeFeatureState('states');

        expect(methodCalls.length, 1);
        expect(methodCalls[0].method, 'source#removeFeatureState');
        final args = methodCalls[0].arguments as Map;
        expect(args['sourceId'], 'states');
        expect(args['featureId'], isNull);
        expect(args['stateKey'], isNull);
        expect(args['sourceLayer'], isNull);
      },
    );

    test('getFeatureState decodes the state the native side returns', () async {
      final state = {
        'hover': true,
        'score': 3,
        'nested': {'a': 1},
      };
      getFeatureStateReply = <Object?, Object?>{'state': jsonEncode(state)};

      final result = await platform.getFeatureState(
        'terrain',
        '42',
        sourceLayer: 'contour',
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#getFeatureState');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'terrain');
      expect(args['featureId'], '42');
      expect(args['sourceLayer'], 'contour');
      expect(result, state);
    });

    test(
      'getFeatureState returns null when the native side has none',
      () async {
        getFeatureStateReply = <Object?, Object?>{'state': null};

        final result = await platform.getFeatureState('states', '42');

        expect(methodCalls.length, 1);
        expect(result, isNull, reason: 'null must not be flattened to {}');
      },
    );
  });

  // Feature state has no iOS implementation because the MapLibre iOS SDK does
  // not expose the API yet. The failure must stay loud and name the platform,
  // and nothing may reach the channel where it would no-op or come back as an
  // unrelated MissingPluginException.
  group('MethodChannel Feature State on iOS', () {
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

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    Matcher throwsUnavailableOniOS(String methodName) => throwsA(
      isA<UnsupportedError>().having(
        (e) => e.message,
        'message',
        allOf(
          contains(methodName),
          contains('not available on iOS'),
          contains('MapLibre iOS SDK'),
        ),
      ),
    );

    test('setFeatureState throws and sends nothing', () async {
      await expectLater(
        platform.setFeatureState('states', '42', {'hover': true}),
        throwsUnavailableOniOS('setFeatureState'),
      );
      expect(methodCalls, isEmpty);
    });

    test('removeFeatureState throws and sends nothing', () async {
      await expectLater(
        platform.removeFeatureState('states', featureId: '42'),
        throwsUnavailableOniOS('removeFeatureState'),
      );
      expect(methodCalls, isEmpty);
    });

    test('getFeatureState throws and sends nothing', () async {
      await expectLater(
        platform.getFeatureState('states', '42'),
        throwsUnavailableOniOS('getFeatureState'),
      );
      expect(methodCalls, isEmpty);
    });
  });
}
