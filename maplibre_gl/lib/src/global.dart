// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

const _globalChannel = MethodChannel('plugins.flutter.io/maplibre_gl');

/// Retains active offline-download event-channel subscriptions so that Dart's
/// GC cannot tear them down during idle periods (e.g. while a download is
/// paused). If the subscription is collected, the native `EventSink` is
/// released and subsequent progress/success events are silently dropped,
/// causing the UI to appear stuck after resume.
final Map<String, StreamSubscription<dynamic>> _offlineDownloadSubscriptions =
    {};

/// Copy tiles db file passed in to the tiles cache directory (sideloaded) to
/// make tiles available offline.
Future<void> installOfflineMapTiles(String tilesDb) async {
  await _globalChannel.invokeMethod(
    'installOfflineMapTiles',
    <String, dynamic>{
      'tilesdb': tilesDb,
    },
  );
}

enum DragEventType { start, drag, end }

enum HoverEventType { enter, move, leave }

Future<dynamic> setOffline(bool offline) => _globalChannel.invokeMethod(
  'setOffline',
  <String, dynamic>{
    'offline': offline,
  },
);

Future<void> setHttpHeaders(Map<String, String> headers) {
  return _globalChannel.invokeMethod(
    'setHttpHeaders',
    <String, dynamic>{
      'headers': headers,
    },
  );
}

Future<List<OfflineRegion>> mergeOfflineRegions(String path) async {
  final String regionsJson = await _globalChannel.invokeMethod(
    'mergeOfflineRegions',
    <String, dynamic>{
      'path': path,
    },
  );
  final regions = List<Map<String, dynamic>>.from(json.decode(regionsJson));
  return regions.map(OfflineRegion.fromMap).toList();
}

Future<List<OfflineRegion>> getListOfRegions() async {
  final String regionsJson = await _globalChannel.invokeMethod(
    'getListOfRegions',
    <String, dynamic>{},
  );
  final regions = List<Map<String, dynamic>>.from(json.decode(regionsJson));
  return regions.map(OfflineRegion.fromMap).toList();
}

Future<OfflineRegion> updateOfflineRegionMetadata(
  int id,
  Map<String, dynamic> metadata,
) async {
  final regionJson = await _globalChannel.invokeMethod(
    'updateOfflineRegionMetadata',
    <String, dynamic>{
      'id': id,
      'metadata': metadata,
    },
  );

  return OfflineRegion.fromMap(json.decode(regionJson));
}

Future<dynamic> setOfflineTileCountLimit(int limit) =>
    _globalChannel.invokeMethod(
      'setOfflineTileCountLimit',
      <String, dynamic>{
        'limit': limit,
      },
    );

/// Sets the maximum number of concurrent HTTP requests for tile downloads.
///
/// [maxRequests] controls the total number of concurrent requests (Android
/// only). [maxRequestsPerHost] controls the per-host concurrency limit
/// (both platforms). Lowering these values can help avoid rate limiting from
/// tile servers (e.g. Cloudflare).
Future<void> setOfflineMaxConcurrentRequests({
  int? maxRequests,
  int? maxRequestsPerHost,
}) =>
    _globalChannel.invokeMethod(
      'setOfflineMaxConcurrentRequests',
      <String, dynamic>{
        if (maxRequests != null) 'maxRequests': maxRequests,
        if (maxRequestsPerHost != null) 'maxRequestsPerHost': maxRequestsPerHost,
      },
    );

/// Pauses an in-progress offline region download.
Future<void> pauseOfflineRegionDownload(int id) =>
    _globalChannel.invokeMethod(
      'pauseOfflineRegionDownload',
      <String, dynamic>{'id': id},
    );

/// Resumes a paused offline region download.
Future<void> resumeOfflineRegionDownload(int id) =>
    _globalChannel.invokeMethod(
      'resumeOfflineRegionDownload',
      <String, dynamic>{'id': id},
    );

/// Gets the current download status of an offline region.
Future<OfflineRegionStatus> getOfflineRegionStatus(int id) async {
  final String result = await _globalChannel.invokeMethod(
    'getOfflineRegionStatus',
    <String, dynamic>{'id': id},
  );
  return OfflineRegionStatus.fromMap(
    Map<String, dynamic>.from(json.decode(result)),
  );
}

Future<dynamic> deleteOfflineRegion(int id) => _globalChannel.invokeMethod(
  'deleteOfflineRegion',
  <String, dynamic>{
    'id': id,
  },
);

/// Removes all tiles from the shared ambient cache that are not associated
/// with any offline region. Call this after [deleteOfflineRegion] to fully
/// evict tiles that would otherwise be reused by a future download of the
/// same area.
Future<void> clearAmbientCache() =>
    _globalChannel.invokeMethod('clearAmbientCache');

/// Resets the entire offline database: deletes every offline region and
/// clears the ambient cache. Use with care — offline regions cannot be
/// recovered afterwards.
Future<void> resetOfflineDatabase() =>
    _globalChannel.invokeMethod('resetOfflineDatabase');

Future<OfflineRegion> downloadOfflineRegion(
  OfflineRegionDefinition definition, {
  Map<String, dynamic> metadata = const {},
  Function(DownloadRegionStatus event)? onEvent,
}) async {
  final channelName =
      'downloadOfflineRegion_${DateTime.now().microsecondsSinceEpoch}';

  await _globalChannel.invokeMethod(
    'downloadOfflineRegion#setup',
    <String, dynamic>{
      'channelName': channelName,
    },
  );

  if (onEvent != null) {
    void cleanup() {
      final sub = _offlineDownloadSubscriptions.remove(channelName);
      if (sub != null) unawaited(sub.cancel());
    }

    // Subscription is retained in _offlineDownloadSubscriptions and cancelled
    // in cleanup() on the terminal Success/Error event.
    // ignore: cancel_subscriptions
    final subscription = EventChannel(channelName)
        .receiveBroadcastStream()
        .handleError((error) {
          if (error is PlatformException) {
            onEvent(Error(error));
            cleanup();
            return Error(error);
          }
          final unknownError = Error(
            PlatformException(
              code: 'UnknowException',
              message:
                  'This error is unhandled by plugin. Please contact us if needed.',
              details: error,
            ),
          );
          onEvent(unknownError);
          cleanup();
          return unknownError;
        })
        .listen((data) {
          final Map<String, Object?> jsonData = json.decode(data);
          final status = switch (jsonData['status']) {
            'start' => InProgress(0.0),
            'progress' => InProgress(
                (jsonData['progress']! as num).toDouble(),
                completedResourceCount:
                    (jsonData['completedResourceCount'] as num?)?.toInt() ?? 0,
                requiredResourceCount:
                    (jsonData['requiredResourceCount'] as num?)?.toInt() ?? 0,
                completedResourceSize:
                    (jsonData['completedResourceSize'] as num?)?.toInt() ?? 0,
              ),
            'success' => Success(),
            _ => throw Exception('Invalid event status ${jsonData['status']}'),
          };
          onEvent(status);
          if (status is Success) cleanup();
        });

    _offlineDownloadSubscriptions[channelName] = subscription;
  }

  final result = await _globalChannel.invokeMethod(
    'downloadOfflineRegion',
    <String, dynamic>{
      'definition': definition.toMap(),
      'metadata': metadata,
    },
  );

  return OfflineRegion.fromMap(json.decode(result));
}
