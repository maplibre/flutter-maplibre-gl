import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> methodCalls;

  /// Fake region JSON returned by the mock method channel.
  final fakeRegionJson = json.encode({
    'id': 1,
    'definition': {
      'bounds': [
        [10.0, 20.0],
        [30.0, 40.0],
      ],
      'mapStyleUrl': 'https://example.com/style.json',
      'minZoom': 5.0,
      'maxZoom': 15.0,
      'includeIdeographs': false,
    },
    'metadata': <String, dynamic>{},
  });

  final definition = OfflineRegionDefinition(
    bounds: LatLngBounds(
      southwest: const LatLng(10.0, 20.0),
      northeast: const LatLng(30.0, 40.0),
    ),
    mapStyleUrl: 'https://example.com/style.json',
    minZoom: 5.0,
    maxZoom: 15.0,
  );

  /// The channel name captured from the setup call.
  String? capturedChannelName;

  setUp(() {
    methodCalls = [];
    capturedChannelName = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/maplibre_gl'),
          (methodCall) async {
            methodCalls.add(methodCall);

            switch (methodCall.method) {
              case 'setOffline':
                return null;
              case 'deleteOfflineRegion':
                return null;
              case 'downloadOfflineRegion#setup':
                capturedChannelName =
                    (methodCall.arguments as Map)['channelName'] as String;
                return null;
              case 'downloadOfflineRegion':
                return fakeRegionJson;
              default:
                return null;
            }
          },
        );
  });

  group('setOffline', () {
    test('sends correct method and arguments', () async {
      await setOffline(true);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'setOffline');
      final args = methodCalls[0].arguments as Map;
      expect(args['offline'], true);
    });
  });

  group('deleteOfflineRegion', () {
    test('sends correct method and arguments', () async {
      await deleteOfflineRegion(42);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'deleteOfflineRegion');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 42);
    });
  });

  group('downloadOfflineRegion', () {
    test('calls setup then download and returns region', () async {
      final region = await downloadOfflineRegion(definition);

      expect(methodCalls.length, 2);
      expect(methodCalls[0].method, 'downloadOfflineRegion#setup');
      expect(methodCalls[1].method, 'downloadOfflineRegion');
      expect(region.id, 1);
    });

    test('forwards definition and metadata', () async {
      await downloadOfflineRegion(
        definition,
        metadata: {'name': 'test'},
      );

      final args = methodCalls[1].arguments as Map;
      expect(args['definition'], definition.toMap());
      expect(args['metadata'], {'name': 'test'});
    });

    test('onEvent receives start status from event channel', () async {
      final statuses = <DownloadRegionStatus>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'downloadOfflineRegion#setup':
                  capturedChannelName =
                      (methodCall.arguments as Map)['channelName'] as String;

                  // Mock the event channel to emit events.
                  _mockEventChannel(capturedChannelName!, [
                    json.encode({'status': 'start'}),
                    json.encode({'status': 'progress', 'progress': 0.5}),
                    json.encode({'status': 'success'}),
                  ]);
                  return null;
                case 'downloadOfflineRegion':
                  // Give time for events to be processed.
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  return fakeRegionJson;
                default:
                  return null;
              }
            },
          );

      await downloadOfflineRegion(
        definition,
        onEvent: statuses.add,
      );

      // Wait for event stream processing.
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, isNotEmpty);
      expect(statuses[0], isA<InProgress>());
      expect((statuses[0] as InProgress).progress, 0.0);
      expect(statuses[1], isA<InProgress>());
      expect((statuses[1] as InProgress).progress, 0.5);
      expect(statuses[2], isA<Success>());
    });

    test('onEvent receives progress with resource counts', () async {
      final statuses = <DownloadRegionStatus>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'downloadOfflineRegion#setup':
                  capturedChannelName =
                      (methodCall.arguments as Map)['channelName'] as String;

                  _mockEventChannel(capturedChannelName!, [
                    json.encode({
                      'status': 'progress',
                      'progress': 50.0,
                      'completedResourceCount': 100,
                      'requiredResourceCount': 200,
                      'completedResourceSize': 1024000,
                    }),
                  ]);
                  return null;
                case 'downloadOfflineRegion':
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  return fakeRegionJson;
                default:
                  return null;
              }
            },
          );

      await downloadOfflineRegion(
        definition,
        onEvent: statuses.add,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, isNotEmpty);
      expect(statuses[0], isA<InProgress>());
      final progress = statuses[0] as InProgress;
      expect(progress.progress, 50.0);
      expect(progress.completedResourceCount, 100);
      expect(progress.requiredResourceCount, 200);
      expect(progress.completedResourceSize, 1024000);
    });

    test('onEvent receives PlatformException as Error status', () async {
      final statuses = <DownloadRegionStatus>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl'),
            (methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'downloadOfflineRegion#setup':
                  capturedChannelName =
                      (methodCall.arguments as Map)['channelName'] as String;

                  // Mock the event channel to emit an error.
                  _mockEventChannelWithError(
                    capturedChannelName!,
                    PlatformException(
                      code: 'DOWNLOAD_ERROR',
                      message: 'failed',
                    ),
                  );
                  return null;
                case 'downloadOfflineRegion':
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                  return fakeRegionJson;
                default:
                  return null;
              }
            },
          );

      await downloadOfflineRegion(
        definition,
        onEvent: statuses.add,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(statuses, isNotEmpty);
      expect(statuses.first, isA<Error>());
      expect((statuses.first as Error).cause.code, 'DOWNLOAD_ERROR');
    });
  });

  group('pauseOfflineRegionDownload', () {
    test('sends correct method and arguments', () async {
      await pauseOfflineRegionDownload(99);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'pauseOfflineRegionDownload');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 99);
    });
  });

  group('resumeOfflineRegionDownload', () {
    test('sends correct method and arguments', () async {
      await resumeOfflineRegionDownload(99);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'resumeOfflineRegionDownload');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 99);
    });
  });

  group('setOfflineMaxConcurrentRequests', () {
    test('sends correct method and arguments with both params', () async {
      await setOfflineMaxConcurrentRequests(
        maxRequests: 32,
        maxRequestsPerHost: 4,
      );

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'setOfflineMaxConcurrentRequests');
      final args = methodCalls[0].arguments as Map;
      expect(args['maxRequests'], 32);
      expect(args['maxRequestsPerHost'], 4);
    });

    test('sends only provided params', () async {
      await setOfflineMaxConcurrentRequests(maxRequestsPerHost: 2);

      expect(methodCalls.length, 1);
      final args = methodCalls[0].arguments as Map;
      expect(args.containsKey('maxRequests'), false);
      expect(args['maxRequestsPerHost'], 2);
    });
  });

  group('getOfflineRegionStatus', () {
    test('returns parsed status', () async {
      final fakeStatusJson = json.encode({
        'completedResourceCount': 150,
        'requiredResourceCount': 300,
        'completedResourceSize': 2048000,
        'isComplete': false,
        'downloadProgress': 50.0,
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/maplibre_gl'),
            (methodCall) async {
              methodCalls.add(methodCall);
              if (methodCall.method == 'getOfflineRegionStatus') {
                return fakeStatusJson;
              }
              return null;
            },
          );

      final status = await getOfflineRegionStatus(42);

      expect(methodCalls.length, 1);
      expect(methodCalls[0].method, 'getOfflineRegionStatus');
      final args = methodCalls[0].arguments as Map;
      expect(args['id'], 42);
      expect(status.completedResourceCount, 150);
      expect(status.requiredResourceCount, 300);
      expect(status.completedResourceSize, 2048000);
      expect(status.isComplete, false);
      expect(status.downloadProgress, 50.0);
    });
  });
}

/// Mocks an EventChannel to emit the given data items as a stream.
void _mockEventChannel(String channelName, List<String> events) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
        EventChannel(channelName),
        _FakeStreamHandler(events),
      );
}

/// Mocks an EventChannel to emit an error.
void _mockEventChannelWithError(String channelName, PlatformException error) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
        EventChannel(channelName),
        _ErrorStreamHandler(error),
      );
}

class _FakeStreamHandler extends MockStreamHandler {
  final List<String> events;
  _FakeStreamHandler(this.events);

  @override
  void onListen(dynamic arguments, MockStreamHandlerEventSink events) {
    this.events.forEach(events.success);
  }

  @override
  void onCancel(dynamic arguments) {}
}

class _ErrorStreamHandler extends MockStreamHandler {
  final PlatformException error;
  _ErrorStreamHandler(this.error);

  @override
  void onListen(dynamic arguments, MockStreamHandlerEventSink events) {
    events.error(code: error.code, message: error.message);
  }

  @override
  void onCancel(dynamic arguments) {}
}
