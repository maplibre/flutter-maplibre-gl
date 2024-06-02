// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

const _globalChannel = MethodChannel('plugins.flutter.io/mapbox_gl');

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
  String regionsJson = await _globalChannel.invokeMethod(
    'mergeOfflineRegions',
    <String, dynamic>{
      'path': path,
    },
  );
  Iterable regions = json.decode(regionsJson);
  return regions.map((region) => OfflineRegion.fromMap(region)).toList();
}

Future<List<OfflineRegion>> getListOfRegions() async {
  String regionsJson = await _globalChannel.invokeMethod(
    'getListOfRegions',
    <String, dynamic>{},
  );
  Iterable regions = json.decode(regionsJson);
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
  String channelName =
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
      var unknownError = Error(
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
      final Map<String, dynamic> jsonData = json.decode(data);
      DownloadRegionStatus? status;
      switch (jsonData['status']) {
        case 'start':
          status = InProgress(0.0);
          break;
        case 'progress':
          final dynamic value = jsonData['progress'];
          double progress = 0.0;

          if (value is int) {
            progress = value.toDouble();
          }

          if (value is double) {
            progress = value;
          }

          status = InProgress(progress);
          break;
        case 'success':
          status = Success();
          break;
      }
      onEvent(status ?? (throw 'Invalid event status ${jsonData['status']}'));
    });
  }

  final result = await _globalChannel
      .invokeMethod('downloadOfflineRegion', <String, dynamic>{
    'definition': definition.toMap(),
    'metadata': metadata,
  });

  return OfflineRegion.fromMap(json.decode(result));
}
