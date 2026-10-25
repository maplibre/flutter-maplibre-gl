// The Android and iOS path of the global functions down to the platform
// channels: the Pigeon-generated MapLibreGlobalHostApi and
// MapLibreOfflineDownloadFlutterApi run as they do in an app, and the tests
// play the native side with the same codec and the same reply envelopes as the
// generated Kotlin and Swift code. global_test.dart covers the Dart logic above
// the generated client with a fake. Web has no Pigeon channel, hence vm only.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl/src/native/messages.g.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show MapLibreGlobalPlatform;

const _hostApi = 'dev.flutter.pigeon.maplibre_gl.MapLibreGlobalHostApi';
const _onDownloadEvent =
    'dev.flutter.pigeon.maplibre_gl.MapLibreOfflineDownloadFlutterApi'
    '.onDownloadEvent';
const MessageCodec<Object?> _codec = MapLibreGlobalHostApi.pigeonChannelCodec;

TestDefaultBinaryMessenger get _messenger =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeHost host;
  // The default, as no registrant runs in tests.
  final unregistered = MapLibreGlobalPlatform.instance;

  setUp(() => host = _FakeHost());

  tearDown(() {
    host.dispose();
    MapLibreOfflineDownloadFlutterApi.setUp(null);
    MapLibreGlobalPlatform.instance = unregistered;
  });

  final regionJson = json.encode({
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
    'metadata': {'name': 'x'},
  });

  final statusJson = json.encode({
    'completedResourceCount': 150,
    'requiredResourceCount': 300,
    'completedResourceSize': 2048000,
    'isComplete': false,
    'downloadProgress': 50.0,
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

  final theRegion = isA<OfflineRegion>().having((r) => r.id, 'id', 1).having(
    (r) => r.metadata,
    'metadata',
    {'name': 'x'},
  );

  group('MapLibreGlobalHostApi', () {
    // Above 2^32, to show the int goes over as 64 bits.
    const cacheBytes = 5 * 1024 * 1024 * 1024;

    final calls = [
      _HostCall('preWarm', (api) => api.preWarm()),
      _HostCall(
        'installOfflineMapTiles',
        (api) => api.installOfflineMapTiles('assets/cache.db'),
        args: ['assets/cache.db'],
      ),
      _HostCall(
        'setOffline',
        (api) => api.setOffline(true),
        args: [true],
      ),
      _HostCall(
        'setHttpHeaders',
        (api) => api.setHttpHeaders({'Authorization': 'Bearer token'}),
        args: [
          {'Authorization': 'Bearer token'},
        ],
      ),
      _HostCall(
        'mergeOfflineRegions',
        (api) => api.mergeOfflineRegions('/data/other.db'),
        args: ['/data/other.db'],
        result: '[$regionJson]',
        nonNullResult: true,
      ),
      _HostCall(
        'getOfflineDatabasePath',
        (api) => api.getOfflineDatabasePath(),
        result: '/data/offline.db',
      ),
      _HostCall(
        'getListOfRegions',
        (api) => api.getListOfRegions(),
        result: '[$regionJson]',
        nonNullResult: true,
      ),
      _HostCall(
        'updateOfflineRegionMetadata',
        (api) => api.updateOfflineRegionMetadata(1, {
          'name': 'x',
          'tags': ['a', 'b'],
        }),
        args: [
          1,
          {
            'name': 'x',
            'tags': ['a', 'b'],
          },
        ],
        result: regionJson,
        nonNullResult: true,
      ),
      _HostCall(
        'setOfflineTileCountLimit',
        (api) => api.setOfflineTileCountLimit(6000),
        args: [6000],
      ),
      _HostCall(
        'setOfflineMaxConcurrentRequests',
        (api) => api.setOfflineMaxConcurrentRequests(null, 4),
        args: [null, 4],
      ),
      _HostCall(
        'pauseOfflineRegionDownload',
        (api) => api.pauseOfflineRegionDownload(7),
        args: [7],
      ),
      _HostCall(
        'resumeOfflineRegionDownload',
        (api) => api.resumeOfflineRegionDownload(7),
        args: [7],
      ),
      _HostCall(
        'getOfflineRegionStatus',
        (api) => api.getOfflineRegionStatus(7),
        args: [7],
        result: statusJson,
        nonNullResult: true,
      ),
      _HostCall(
        'deleteOfflineRegion',
        (api) => api.deleteOfflineRegion(7),
        args: [7],
      ),
      _HostCall('clearAmbientCache', (api) => api.clearAmbientCache()),
      _HostCall(
        'setMaximumAmbientCacheSize',
        (api) => api.setMaximumAmbientCacheSize(cacheBytes),
        args: [cacheBytes],
      ),
      _HostCall('resetOfflineDatabase', (api) => api.resetOfflineDatabase()),
      _HostCall(
        'downloadOfflineRegion',
        (api) => api.downloadOfflineRegion(3, definition.toMap(), {
          'name': 'x',
        }),
        args: [
          3,
          definition.toMap(),
          {'name': 'x'},
        ],
        result: regionJson,
        nonNullResult: true,
      ),
    ];

    for (final call in calls) {
      group(call.method, () {
        test('sends its arguments and returns the answer', () async {
          host.answer(call.method, result: call.result);

          expect(await call.send(MapLibreGlobalHostApi()), call.result);
          expect(host.received, [
            [call.method, call.args],
          ]);
        });

        test('fails with channel-error when nothing answers', () async {
          await expectLater(
            call.send(MapLibreGlobalHostApi()),
            throwsA(
              isA<PlatformException>()
                  .having((e) => e.code, 'code', 'channel-error')
                  .having(
                    (e) => e.message,
                    'message',
                    contains('"$_hostApi.${call.method}"'),
                  ),
            ),
          );
        });

        test('throws the error native answers', () async {
          host.answer(
            call.method,
            error: PlatformException(
              code: 'nativeFailure',
              message: 'it broke',
              details: {'method': call.method},
            ),
          );

          await expectLater(
            call.send(MapLibreGlobalHostApi()),
            throwsA(
              isA<PlatformException>()
                  .having((e) => e.code, 'code', 'nativeFailure')
                  .having((e) => e.message, 'message', 'it broke')
                  .having((e) => e.details, 'details', {
                    'method': call.method,
                  }),
            ),
          );
        });

        if (call.nonNullResult) {
          test('fails with null-error when native answers null', () async {
            host.answer(call.method);

            await expectLater(
              call.send(MapLibreGlobalHostApi()),
              throwsA(
                isA<PlatformException>().having(
                  (e) => e.code,
                  'code',
                  'null-error',
                ),
              ),
            );
          });
        }
      });
    }

    test('getOfflineDatabasePath accepts null as an answer', () async {
      host.answer('getOfflineDatabasePath');

      expect(await MapLibreGlobalHostApi().getOfflineDatabasePath(), isNull);
    });
  });

  group('global functions', () {
    setUp(MapLibreNativePlugin.registerWith);

    final calls = [
      _GlobalCall(
        'installOfflineMapTiles',
        () => installOfflineMapTiles('assets/cache.db'),
        args: ['assets/cache.db'],
      ),
      _GlobalCall('setOffline', () => setOffline(true), args: [true]),
      _GlobalCall(
        'setHttpHeaders',
        () => setHttpHeaders({'Authorization': 'Bearer token'}),
        args: [
          {'Authorization': 'Bearer token'},
        ],
      ),
      _GlobalCall(
        'mergeOfflineRegions',
        () => mergeOfflineRegions('/data/other.db'),
        args: ['/data/other.db'],
        answer: '[$regionJson]',
        returns: [theRegion],
      ),
      _GlobalCall(
        'getOfflineDatabasePath',
        getOfflineDatabasePath,
        answer: '/data/offline.db',
        returns: '/data/offline.db',
      ),
      _GlobalCall(
        'getListOfRegions',
        getListOfRegions,
        answer: '[$regionJson]',
        returns: [theRegion],
      ),
      _GlobalCall(
        'updateOfflineRegionMetadata',
        () => updateOfflineRegionMetadata(1, {'name': 'x'}),
        args: [
          1,
          {'name': 'x'},
        ],
        answer: regionJson,
        returns: theRegion,
      ),
      _GlobalCall(
        'setOfflineTileCountLimit',
        () => setOfflineTileCountLimit(6000),
        args: [6000],
      ),
      _GlobalCall(
        'setOfflineMaxConcurrentRequests',
        () => setOfflineMaxConcurrentRequests(maxRequestsPerHost: 4),
        args: [null, 4],
      ),
      _GlobalCall(
        'pauseOfflineRegionDownload',
        () => pauseOfflineRegionDownload(7),
        args: [7],
      ),
      _GlobalCall(
        'resumeOfflineRegionDownload',
        () => resumeOfflineRegionDownload(7),
        args: [7],
      ),
      _GlobalCall(
        'getOfflineRegionStatus',
        () => getOfflineRegionStatus(7),
        args: [7],
        answer: statusJson,
        returns: isA<OfflineRegionStatus>()
            .having((s) => s.completedResourceCount, 'completed', 150)
            .having((s) => s.requiredResourceCount, 'required', 300)
            .having((s) => s.downloadProgress, 'progress', 50.0),
      ),
      _GlobalCall(
        'deleteOfflineRegion',
        () => deleteOfflineRegion(7),
        args: [7],
      ),
      _GlobalCall('clearAmbientCache', clearAmbientCache),
      _GlobalCall(
        'setMaximumAmbientCacheSize',
        () => setMaximumAmbientCacheSize(1024),
        args: [1024],
      ),
      _GlobalCall('resetOfflineDatabase', resetOfflineDatabase),
      _GlobalCall(
        'downloadOfflineRegion',
        () => downloadOfflineRegion(definition, metadata: {'name': 'x'}),
        args: [
          isA<int>(),
          definition.toMap(),
          {'name': 'x'},
        ],
        answer: regionJson,
        returns: theRegion,
      ),
      _GlobalCall('preWarm', MapLibreMap.preWarm),
    ];

    for (final call in calls) {
      test('${call.method} goes over its Pigeon channel', () async {
        host.answer(call.method, result: call.answer);

        expect(await call.send(), call.returns);
        expect(host.received, [
          [call.method, call.args],
        ]);
      });
    }

    test('an error native answers reaches the app unchanged', () async {
      host.answer(
        'updateOfflineRegionMetadata',
        error: PlatformException(
          code: 'REGION_NOT_FOUND',
          message: 'There is no offline region with id 9.',
          details: {'id': 9},
        ),
      );

      await expectLater(
        updateOfflineRegionMetadata(9, {'name': 'x'}),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'REGION_NOT_FOUND')
              .having(
                (e) => e.message,
                'message',
                'There is no offline region with id 9.',
              )
              .having((e) => e.details, 'details', {'id': 9}),
        ),
      );
    });

    group('download events from native', () {
      late List<DownloadRegionStatus> statuses;
      late int downloadId;

      setUp(() async {
        host.answer('downloadOfflineRegion', result: regionJson);
        statuses = [];
        await downloadOfflineRegion(definition, onEvent: statuses.add);
        downloadId = (host.received.single[1]! as List<Object?>)[0]! as int;
      });

      test('start, progress and success reach onEvent', () async {
        final replies = [
          await _sendDownloadEvent(
            downloadId,
            PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
          ),
          await _sendDownloadEvent(
            downloadId,
            PgOfflineDownloadEvent(
              status: PgOfflineDownloadStatus.progress,
              progress: 50.0,
              completedResourceCount: 100,
              requiredResourceCount: 200,
              completedResourceSize: 1024000,
            ),
          ),
          await _sendDownloadEvent(
            downloadId,
            PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.success),
          ),
        ];

        // An empty list is the reply of a handler that returns nothing.
        expect(replies, [isEmpty, isEmpty, isEmpty]);
        expect(statuses, [
          isA<InProgress>().having((s) => s.progress, 'progress', 0.0),
          isA<InProgress>()
              .having((s) => s.progress, 'progress', 50.0)
              .having((s) => s.completedResourceCount, 'completed', 100)
              .having((s) => s.requiredResourceCount, 'required', 200)
              .having((s) => s.completedResourceSize, 'size', 1024000),
          isA<Success>(),
        ]);
      });

      test(
        'an error reaches onEvent with its code, message and details',
        () async {
          await _sendDownloadEvent(
            downloadId,
            PgOfflineDownloadEvent(
              status: PgOfflineDownloadStatus.error,
              errorCode: 'TILE_COUNT_LIMIT_EXCEEDED',
              errorMessage: 'too many tiles',
              errorDetails: {'limit': 6000},
            ),
          );

          expect(statuses, [
            isA<Error>().having(
              (s) => s.cause,
              'cause',
              isA<PlatformException>()
                  .having((e) => e.code, 'code', 'TILE_COUNT_LIMIT_EXCEEDED')
                  .having((e) => e.message, 'message', 'too many tiles')
                  .having((e) => e.details, 'details', {'limit': 6000}),
            ),
          ]);
        },
      );

      test('an event for another download is ignored', () async {
        final reply = await _sendDownloadEvent(
          downloadId + 1,
          PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
        );

        expect(reply, isEmpty);
        expect(statuses, isEmpty);
      });
    });
  });

  group('MapLibreOfflineDownloadFlutterApi', () {
    test('hands the id and the decoded event to the handler', () async {
      final api = _RecordingDownloadApi();
      MapLibreOfflineDownloadFlutterApi.setUp(api);
      final event = PgOfflineDownloadEvent(
        status: PgOfflineDownloadStatus.error,
        errorCode: 'httpError',
        errorMessage: 'HTTP 503',
        errorDetails: ['https://example.com/1/2/3.pbf', 503],
      );

      await _sendDownloadEvent(5, event);

      expect(api.received, [
        [5, event],
      ]);
    });

    test('replies with the PlatformException the handler throws', () async {
      MapLibreOfflineDownloadFlutterApi.setUp(
        _ThrowingDownloadApi(
          PlatformException(code: 'listenerFailed', message: 'no', details: 42),
        ),
      );

      final reply = await _sendDownloadEvent(
        1,
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );

      expect(reply, ['listenerFailed', 'no', 42]);
    });

    test('replies with code error for any other exception', () async {
      MapLibreOfflineDownloadFlutterApi.setUp(
        _ThrowingDownloadApi(StateError('gone')),
      );

      final reply = await _sendDownloadEvent(
        1,
        PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
      );

      expect(reply, ['error', 'Bad state: gone', null]);
    });

    test('stops listening once set up with null', () async {
      final api = _RecordingDownloadApi();
      MapLibreOfflineDownloadFlutterApi.setUp(api);
      MapLibreOfflineDownloadFlutterApi.setUp(null);

      final reply = await _messenger.handlePlatformMessage(
        _onDownloadEvent,
        _codec.encodeMessage(<Object?>[
          1,
          PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.start),
        ]),
        null,
      );

      expect(reply, isNull);
      expect(api.received, isEmpty);
    });
  });

  group('PgOfflineDownloadEvent', () {
    PgOfflineDownloadEvent fullEvent() => PgOfflineDownloadEvent(
      status: PgOfflineDownloadStatus.progress,
      progress: 42.5,
      completedResourceCount: 10,
      requiredResourceCount: 20,
      // Above 2^32, as a large region can be.
      completedResourceSize: 6 * 1024 * 1024 * 1024,
      errorCode: 'code',
      errorMessage: 'message',
      errorDetails: {
        'urls': ['a', 'b'],
        'retry': true,
      },
    );

    test('goes through the codec unchanged', () {
      final decoded = _codec.decodeMessage(_codec.encodeMessage(fullEvent()));

      expect(decoded, isA<PgOfflineDownloadEvent>());
      expect(decoded, fullEvent());
      expect((decoded! as PgOfflineDownloadEvent).errorDetails, {
        'urls': ['a', 'b'],
        'retry': true,
      });
    });

    test('every status goes through the codec unchanged', () {
      for (final status in PgOfflineDownloadStatus.values) {
        expect(_codec.decodeMessage(_codec.encodeMessage(status)), status);
      }
    });

    test('decode reads what encode writes', () {
      expect(PgOfflineDownloadEvent.decode(fullEvent().encode()), fullEvent());
    });

    group('equality', () {
      test('events with the same fields are equal and hash alike', () {
        final event = fullEvent();

        expect(event == event, isTrue);
        expect(fullEvent(), fullEvent());
        expect(fullEvent().hashCode, fullEvent().hashCode);
      });

      test('is never equal to something that is not an event', () {
        // The same fields, as the list the codec writes.
        final fields = fullEvent().encode();

        expect(fullEvent() == fields, isFalse);
      });

      final changes = <String, void Function(PgOfflineDownloadEvent)>{
        'another status': (e) => e.status = PgOfflineDownloadStatus.error,
        'another progress': (e) => e.progress = 42.6,
        'another completedResourceCount': (e) => e.completedResourceCount = 11,
        'another requiredResourceCount': (e) => e.requiredResourceCount = 21,
        'another completedResourceSize': (e) => e.completedResourceSize = 1,
        'another errorCode': (e) => e.errorCode = 'other',
        'another errorMessage': (e) => e.errorMessage = 'other',
        'another value in errorDetails':
            (e) =>
                e.errorDetails = {
                  'urls': ['a', 'c'],
                  'retry': true,
                },
        'a shorter list in errorDetails':
            (e) =>
                e.errorDetails = {
                  'urls': ['a'],
                  'retry': true,
                },
        'another key in errorDetails':
            (e) =>
                e.errorDetails = {
                  'urls': ['a', 'b'],
                  'retries': true,
                },
        'fewer entries in errorDetails':
            (e) =>
                e.errorDetails = {
                  'urls': ['a', 'b'],
                },
      };

      for (final MapEntry(key: field, value: change) in changes.entries) {
        test('$field makes events differ', () {
          final event = fullEvent();
          change(event);

          expect(event, isNot(fullEvent()));
        });
      }

      test('any two NaN progress values are equal and hash alike', () {
        // A NaN with other bits than double.nan, so the two are not
        // identical and the comparison has to look at the values.
        final otherNaN = (ByteData(8)
              ..setUint32(0, 0x7FF80000)
              ..setUint32(4, 1))
            .getFloat64(0);
        final a = PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.progress,
          progress: double.nan,
        );
        final b = PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.progress,
          progress: otherNaN,
        );

        expect(otherNaN.isNaN, isTrue);
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('0.0 and -0.0 progress are equal and hash alike', () {
        final a = PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.start,
          progress: 0.0,
        );
        final b = PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.start,
          progress: -0.0,
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });
    });

    test('toString names every field', () {
      expect(
        PgOfflineDownloadEvent(
          status: PgOfflineDownloadStatus.error,
          errorCode: 'httpError',
          errorMessage: 'HTTP 503',
          errorDetails: 503,
        ).toString(),
        'PgOfflineDownloadEvent(status: PgOfflineDownloadStatus.error, '
        'progress: null, completedResourceCount: null, '
        'requiredResourceCount: null, completedResourceSize: null, '
        'errorCode: httpError, errorMessage: HTTP 503, errorDetails: 503)',
      );
    });
  });

  test('wrapResponse builds the reply envelopes', () {
    expect(wrapResponse(result: 'value'), ['value']);
    expect(wrapResponse(empty: true), isEmpty);
    expect(
      wrapResponse(
        error: PlatformException(code: 'c', message: 'm', details: 'd'),
      ),
      ['c', 'm', 'd'],
    );
  });
}

/// Sends [event] for [downloadId] the way native does and returns the decoded
/// reply, or null when nothing listens.
Future<Object?> _sendDownloadEvent(
  int downloadId,
  PgOfflineDownloadEvent event,
) async {
  final reply = await _messenger.handlePlatformMessage(
    _onDownloadEvent,
    MapLibreOfflineDownloadFlutterApi.pigeonChannelCodec.encodeMessage(
      <Object?>[downloadId, event],
    ),
    null,
  );
  return MapLibreOfflineDownloadFlutterApi.pigeonChannelCodec.decodeMessage(
    reply,
  );
}

/// The native side of [MapLibreGlobalHostApi]: decodes what each method
/// receives and replies with the envelopes of the generated host code,
/// `[result]` on success and `[code, message, details]` on error.
class _FakeHost {
  /// Each message received, as the method name and its decoded arguments.
  final List<List<Object?>> received = [];
  final Set<String> _methods = {};

  /// Answers [method] with [result], or with [error] when given.
  void answer(String method, {Object? result, PlatformException? error}) {
    _methods.add(method);
    _messenger.setMockMessageHandler('$_hostApi.$method', (message) async {
      received.add([method, _codec.decodeMessage(message)]);
      return _codec.encodeMessage(
        error == null
            ? <Object?>[result]
            : <Object?>[error.code, error.message, error.details],
      );
    });
  }

  void dispose() {
    for (final method in _methods) {
      _messenger.setMockMessageHandler('$_hostApi.$method', null);
    }
  }
}

/// A [MapLibreGlobalHostApi] method called with set arguments.
class _HostCall {
  _HostCall(
    this.method,
    this.send, {
    this.args,
    this.result,
    this.nonNullResult = false,
  });

  final String method;
  final Future<Object?> Function(MapLibreGlobalHostApi api) send;

  /// The arguments native decodes, null for a method that takes none.
  final Object? args;

  /// What native answers and the call returns.
  final Object? result;

  /// Whether the method declares a return value that cannot be null.
  final bool nonNullResult;
}

/// A global function called with set arguments.
class _GlobalCall {
  _GlobalCall(this.method, this.send, {this.args, this.answer, this.returns});

  /// The [MapLibreGlobalHostApi] method the function lands on.
  final String method;
  final Future<Object?> Function() send;

  /// The arguments native decodes, null for a method that takes none.
  final Object? args;

  /// What native answers.
  final Object? answer;

  /// What the function returns, or a matcher for it.
  final Object? returns;
}

class _RecordingDownloadApi implements MapLibreOfflineDownloadFlutterApi {
  final List<List<Object?>> received = [];

  @override
  Future<void> onDownloadEvent(
    int downloadId,
    PgOfflineDownloadEvent event,
  ) async => received.add([downloadId, event]);
}

class _ThrowingDownloadApi implements MapLibreOfflineDownloadFlutterApi {
  _ThrowingDownloadApi(this.error);

  final Object error;

  @override
  Future<void> onDownloadEvent(int downloadId, PgOfflineDownloadEvent event) =>
      Future.error(error);
}
