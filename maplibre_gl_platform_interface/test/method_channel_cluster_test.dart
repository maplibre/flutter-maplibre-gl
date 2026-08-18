import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannel Cluster inspection', () {
    late MapLibreMethodChannel platform;
    late List<MethodCall> methodCalls;

    /// What the mocked native side replies to `source#getClusterExpansionZoom`.
    Object? expansionZoomReply;

    /// What the mocked native side replies to the two feature-list methods.
    Object? featuresReply;

    setUp(() async {
      platform = MapLibreMethodChannel();
      methodCalls = [];
      expansionZoomReply = 0;
      featuresReply = <Object?, Object?>{'features': <Object?>[]};

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'source#getClusterExpansionZoom':
                  return expansionZoomReply;
                case 'source#getClusterChildren':
                case 'source#getClusterLeaves':
                  return featuresReply;
                default:
                  return null;
              }
            },
          );

      await platform.initPlatform(0);
      methodCalls.clear();
    });

    /// A cluster feature as the native sides serialize it, one JSON string per
    /// feature so nested properties survive the channel.
    Map<Object?, Object?> featuresReplyOf(List<Map<String, dynamic>> features) {
      return <Object?, Object?>{'features': features.map(jsonEncode).toList()};
    }

    test('getClusterExpansionZoom sends the source and cluster id', () async {
      expansionZoomReply = 9;

      final zoom = await platform.getClusterExpansionZoom('events', 42);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#getClusterExpansionZoom');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'events');
      expect(args['clusterId'], 42);
      expect(zoom, 9);
    });

    test('getClusterChildren decodes the features', () async {
      final children = [
        {
          'type': 'Feature',
          'properties': {'cluster_id': 7, 'point_count': 3},
          'geometry': {
            'type': 'Point',
            'coordinates': [2.35, 48.85],
          },
        },
        {
          'type': 'Feature',
          'properties': {'id': 12},
          'geometry': {
            'type': 'Point',
            'coordinates': [2.36, 48.86],
          },
        },
      ];
      featuresReply = featuresReplyOf(children);

      final result = await platform.getClusterChildren('events', 42);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#getClusterChildren');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'events');
      expect(args['clusterId'], 42);
      expect(result, children);
      // The nested maps must be usable without a cast at every level.
      expect(result.first['properties']['point_count'], 3);
    });

    test('getClusterLeaves defaults limit to 10 and offset to 0', () async {
      await platform.getClusterLeaves('events', 42);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'source#getClusterLeaves');
      final args = methodCalls[0].arguments as Map;
      expect(args['sourceId'], 'events');
      expect(args['clusterId'], 42);
      expect(args['limit'], 10);
      expect(args['offset'], 0);
    });

    test('getClusterLeaves forwards limit and offset', () async {
      final leaves = [
        {
          'type': 'Feature',
          'properties': {'id': 3},
          'geometry': {
            'type': 'Point',
            'coordinates': [2.35, 48.85],
          },
        },
      ];
      featuresReply = featuresReplyOf(leaves);

      final result = await platform.getClusterLeaves(
        'events',
        42,
        limit: 100,
        offset: 25,
      );

      expect(methodCalls.length, 1);
      final args = methodCalls[0].arguments as Map;
      expect(args['limit'], 100);
      expect(args['offset'], 25);
      expect(result, leaves);
    });

    // A source that is not clustered answers 0 and an empty list on Android and
    // iOS rather than failing, so the empty reply must decode instead of
    // throwing on the missing entries.
    test('an empty features reply decodes to an empty list', () async {
      featuresReply = <Object?, Object?>{'features': <Object?>[]};

      expect(await platform.getClusterChildren('events', 42), isEmpty);
      expect(await platform.getClusterLeaves('events', 42), isEmpty);
    });

    test('a reply with no features entry decodes to an empty list', () async {
      featuresReply = <Object?, Object?>{};

      expect(await platform.getClusterChildren('events', 42), isEmpty);
    });

    test('a platform error is surfaced to the caller', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl_0'),
            (methodCall) async =>
                throw PlatformException(
                  code: 'SOURCE_NOT_FOUND',
                  message:
                      "Source 'events' does not exist in the current style.",
                ),
          );

      await expectLater(
        platform.getClusterExpansionZoom('events', 42),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'SOURCE_NOT_FOUND',
          ),
        ),
      );
    });
  });
}
