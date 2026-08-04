import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:maplibre_gl/maplibre_gl.dart' as gl;

import '../engine/engine_host.dart';
import '../protocol/protocol.dart';

/// Offline region support over the FFI engine.
///
/// Mirrors the signatures of maplibre_gl's global offline functions
/// (`global.dart`), which talk to the method-channel backends over a global
/// platform channel that a Dart backend cannot intercept. Until that seam
/// moves behind `MapLibrePlatform` (a separate PR), apps running on the FFI
/// backend call
/// these package-level equivalents instead. Regions are stored in the
/// engine's persistent tile cache database.
class MapLibreGlNativeOffline {
  MapLibreGlNativeOffline._();

  static int _nextRequestId = 1;
  static final Map<int, Completer<OfflineResultEvent>> _pending =
      <int, Completer<OfflineResultEvent>>{};
  static final Map<int, void Function(gl.DownloadRegionStatus)>
  _downloadCallbacks = <int, void Function(gl.DownloadRegionStatus)>{};
  static EngineHost? _listeningHost;

  static Future<EngineHost> _ensureHost() async {
    final host = await EngineHost.ensure();
    if (!identical(_listeningHost, host)) {
      _listeningHost = host;
      host.addEventListener(_onEvent);
    }
    return host;
  }

  static void _onEvent(EngineEvent event) {
    switch (event) {
      case OfflineResultEvent():
        _pending.remove(event.requestId)?.complete(event);
      case OfflineRegionProgressEvent():
        final callback = _downloadCallbacks[event.regionId];
        if (callback == null) return;
        final status = event.status;
        final completed =
            (status['completedResourceCount'] as num?)?.toInt() ?? 0;
        final required =
            (status['requiredResourceCount'] as num?)?.toInt() ?? 0;
        if (status['complete'] == true) {
          _downloadCallbacks.remove(event.regionId);
          callback(gl.Success());
        } else {
          callback(
            gl.InProgress(
              required > 0 ? completed / required * 100 : 0,
              completedResourceCount: completed,
              requiredResourceCount: required,
              completedResourceSize:
                  (status['completedResourceSize'] as num?)?.toInt() ?? 0,
            ),
          );
        }
      case OfflineRegionErrorEvent():
        _downloadCallbacks
            .remove(event.regionId)
            ?.call(
              gl.Error(
                PlatformException(code: 'offline', message: event.message),
              ),
            );
      default:
        break;
    }
  }

  static Future<OfflineResultEvent> _request(
    EngineCommand Function(int requestId) build,
  ) async {
    final host = await _ensureHost();
    final requestId = _nextRequestId++;
    final completer = Completer<OfflineResultEvent>();
    _pending[requestId] = completer;
    host.send(build(requestId));
    final result = await completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException('offline operation timed out');
      },
    );
    final error = result.error;
    if (error != null) {
      throw PlatformException(code: 'offline', message: error);
    }
    return result;
  }

  static Uint8List _encodeMetadata(Map<String, dynamic> metadata) =>
      Uint8List.fromList(utf8.encode(jsonEncode(metadata)));

  static Map<String, dynamic> _decodeMetadata(Object? bytes) {
    if (bytes is! Uint8List || bytes.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map
          ? decoded.cast<String, dynamic>()
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static gl.OfflineRegion _regionFromMap(Map<String, dynamic> map) {
    final definition = (map['definition'] as Map).cast<String, dynamic>();
    final bounds = (definition['bounds'] as List?)?.cast<num>();
    return gl.OfflineRegion(
      id: map['id'] as int,
      definition: gl.OfflineRegionDefinition(
        bounds: gl.LatLngBounds(
          southwest: gl.LatLng(
            bounds?[0].toDouble() ?? 0,
            bounds?[1].toDouble() ?? 0,
          ),
          northeast: gl.LatLng(
            bounds?[2].toDouble() ?? 0,
            bounds?[3].toDouble() ?? 0,
          ),
        ),
        mapStyleUrl: definition['styleUrl'] as String? ?? '',
        minZoom: (definition['minZoom'] as num).toDouble(),
        maxZoom: (definition['maxZoom'] as num).toDouble(),
        includeIdeographs: definition['includeIdeographs'] as bool? ?? false,
      ),
      metadata: _decodeMetadata(map['metadata']),
    );
  }

  static List<gl.OfflineRegion> _regionsOf(OfflineResultEvent result) => [
    for (final region in result.regions ?? const <Map<String, dynamic>>[])
      _regionFromMap(region),
  ];

  /// Creates a region and starts downloading it; [onEvent] receives progress
  /// updates like the global API's `downloadOfflineRegion`.
  ///
  /// [onEvent] is retained until the download completes, errors, or the
  /// region is deleted. There is deliberately no release on pause: a paused
  /// download is resumable and must keep reporting progress afterwards, and
  /// no "abandoned for good" signal exists in the API. A download the app
  /// pauses and never touches again therefore keeps its callback until
  /// [deleteOfflineRegion]; one closure per region, bounded by the region
  /// count in the cache database.
  static Future<gl.OfflineRegion> downloadOfflineRegion(
    gl.OfflineRegionDefinition definition, {
    Map<String, dynamic> metadata = const {},
    void Function(gl.DownloadRegionStatus event)? onEvent,
  }) async {
    final result = await _request(
      (requestId) => CreateOfflineRegionCommand(
        requestId,
        styleUrl: definition.mapStyleUrl,
        bounds: BoundsSpec(
          south: definition.bounds.southwest.latitude,
          west: definition.bounds.southwest.longitude,
          north: definition.bounds.northeast.latitude,
          east: definition.bounds.northeast.longitude,
        ),
        minZoom: definition.minZoom,
        maxZoom: definition.maxZoom,
        includeIdeographs: definition.includeIdeographs,
        metadata: _encodeMetadata(metadata),
      ),
    );
    final region = _regionFromMap(result.regions!.first);
    if (onEvent != null) _downloadCallbacks[region.id] = onEvent;
    final host = await _ensureHost();
    host.send(
      SetOfflineRegionDownloadStateCommand(
        region.id,
        active: true,
        observed: true,
      ),
    );
    return region;
  }

  /// Lists the stored regions.
  static Future<List<gl.OfflineRegion>> getListOfRegions() async =>
      _regionsOf(await _request(ListOfflineRegionsCommand.new));

  /// Merges a side database of regions into the cache database.
  static Future<List<gl.OfflineRegion>> mergeOfflineRegions(
    String path,
  ) async => _regionsOf(
    await _request((requestId) => MergeOfflineRegionsCommand(requestId, path)),
  );

  /// Replaces the metadata of one region.
  static Future<gl.OfflineRegion> updateOfflineRegionMetadata(
    int id,
    Map<String, dynamic> metadata,
  ) async {
    final result = await _request(
      (requestId) => UpdateOfflineRegionMetadataCommand(
        requestId,
        id,
        _encodeMetadata(metadata),
      ),
    );
    return _regionFromMap(result.regions!.first);
  }

  /// Reads the download status of one region.
  static Future<gl.OfflineRegionStatus> getOfflineRegionStatus(int id) async {
    final result = await _request(
      (requestId) => GetOfflineRegionStatusCommand(requestId, id),
    );
    final status = result.status!;
    final completed = (status['completedResourceCount'] as num).toInt();
    final required = (status['requiredResourceCount'] as num).toInt();
    return gl.OfflineRegionStatus(
      completedResourceCount: completed,
      requiredResourceCount: required,
      completedResourceSize: (status['completedResourceSize'] as num).toInt(),
      isComplete: status['complete'] == true,
      downloadProgress: required > 0 ? completed / required * 100 : 0,
    );
  }

  /// Deletes one region.
  static Future<void> deleteOfflineRegion(int id) async {
    _downloadCallbacks.remove(id);
    await _request((requestId) => DeleteOfflineRegionCommand(requestId, id));
  }

  /// Pauses one region download. The progress callback registered by
  /// [downloadOfflineRegion] stays in place so a later resume keeps
  /// reporting; delete the region to release it for good.
  static Future<void> pauseOfflineRegionDownload(int id) async {
    final host = await _ensureHost();
    host.send(
      SetOfflineRegionDownloadStateCommand(id, active: false, observed: true),
    );
  }

  /// Resumes one region download.
  static Future<void> resumeOfflineRegionDownload(int id) async {
    final host = await _ensureHost();
    host.send(
      SetOfflineRegionDownloadStateCommand(id, active: true, observed: true),
    );
  }

  /// Global online/offline toggle (`setOffline` equivalent).
  static Future<void> setOffline(bool offline) async {
    final host = await _ensureHost();
    host.send(SetNetworkStatusCommand(online: !offline));
  }

  /// The C API has no tile-count-limit setter yet; documented no-op.
  static Future<void> setOfflineTileCountLimit(int limit) async {
    debugPrint(
      '[maplibre_gl_native] setOfflineTileCountLimit has no C API '
      'counterpart yet; ignored',
    );
  }
}
