// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

const _globalChannel = MethodChannel('plugins.flutter.io/maplibre_gl');

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
  final Iterable regions = json.decode(regionsJson);
  return regions.map((region) => OfflineRegion.fromMap(region)).toList();
}

Future<List<OfflineRegion>> getListOfRegions() async {
  final String regionsJson = await _globalChannel.invokeMethod(
    'getListOfRegions',
    <String, dynamic>{},
  );
  final Iterable regions = json.decode(regionsJson);
  return regions.map((region) => OfflineRegion.fromMap(region)).toList();
}

Future<OfflineRegion> updateOfflineRegionMetadata(
    int id, Map<String, dynamic> metadata) async {
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

Future<dynamic> deleteOfflineRegion(int id) => _globalChannel.invokeMethod(
      'deleteOfflineRegion',
      <String, dynamic>{
        'id': id,
      },
    );

Future<OfflineRegion> downloadOfflineRegion(
  OfflineRegionDefinition definition, {
  Map<String, dynamic> metadata = const {},
  Function(DownloadRegionStatus event)? onEvent,
}) async {
  final channelName =
      'downloadOfflineRegion_${DateTime.now().microsecondsSinceEpoch}';

  await _globalChannel
      .invokeMethod('downloadOfflineRegion#setup', <String, dynamic>{
    'channelName': channelName,
  });

  if (onEvent != null) {
    EventChannel(channelName).receiveBroadcastStream().handleError((error) {
      if (error is PlatformException) {
        onEvent(Error(error));
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
      return unknownError;
    }).listen((data) {
      final Map<String, Object?> jsonData = json.decode(data);
      final status = switch (jsonData['status']) {
        'start' => InProgress(0.0),
        'progress' => InProgress((jsonData['progress']! as num).toDouble()),
        'success' => Success(),
        _ => throw Exception('Invalid event status ${jsonData['status']}'),
      };
      onEvent(status);
    });
  }

  final result = await _globalChannel
      .invokeMethod('downloadOfflineRegion', <String, dynamic>{
    'definition': definition.toMap(),
    'metadata': metadata,
  });

  return OfflineRegion.fromMap(json.decode(result));
}
