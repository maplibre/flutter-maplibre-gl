// Offline-region operations of the engine core.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

extension EngineOfflineOps on FfiEngineCore {
  /// Starts an async offline operation. Its runtime completion event resolves
  /// it: [take] builds the reply (consuming the handle's result); a null
  /// [take] means fire-and-forget (the handle is just discarded).
  void _startOfflineOp(
    int? requestId,
    mln.OfflineOperationHandle Function() start,
    OfflineResultEvent Function(mln.OfflineOperationHandle)? take,
  ) {
    mln.OfflineOperationHandle handle;
    try {
      handle = start();
    } catch (error) {
      if (requestId != null) {
        _emit(OfflineResultEvent(requestId, error: '$error'));
      }
      return;
    }
    _offlineOps[handle.id] = _PendingOfflineOp(requestId, handle, take);
  }

  /// Routes offline runtime events; returns whether the event was consumed.
  bool _handleOfflineEvent(mln.RuntimeEvent event) {
    final payload = event.payload;
    switch (event.eventType) {
      case mln.RuntimeEventType.offlineOperationCompleted:
        if (payload is! mln.RuntimeEventOfflineOperationCompleted) return true;
        final pending = _offlineOps.remove(payload.operationId);
        if (pending == null) return true;
        final take = pending.take;
        final requestId = pending.requestId;
        try {
          if (take == null || requestId == null) {
            pending.handle.discard();
          } else if (payload.resultStatus != mln.MaplibreStatus.ok) {
            pending.handle.discard();
            _emit(
              OfflineResultEvent(
                requestId,
                error: 'offline operation failed: ${payload.resultStatus.name}',
              ),
            );
          } else {
            _emit(take(pending.handle));
          }
        } catch (error) {
          if (requestId != null) {
            _emit(OfflineResultEvent(requestId, error: '$error'));
          }
        }
        return true;
      case mln.RuntimeEventType.offlineRegionStatusChanged:
        if (payload is mln.RuntimeEventOfflineRegionStatus) {
          _emit(
            OfflineRegionProgressEvent(
              payload.regionId,
              _statusToMap(payload.status),
            ),
          );
        }
        return true;
      case mln.RuntimeEventType.offlineRegionResponseError:
        if (payload is mln.RuntimeEventOfflineRegionResponseError) {
          _emit(
            OfflineRegionErrorEvent(
              payload.regionId,
              'resource error: ${payload.reason.name}',
            ),
          );
        }
        return true;
      default:
        return false;
    }
  }
}

// Top level (not extension statics): called unqualified from the command
// dispatch in another part of this library.
Map<String, dynamic> _regionToMap(mln.OfflineRegionInfo info) {
  final definition = info.definition;
  // Geometry-defined regions (creatable by non-Flutter consumers) are
  // reported through their bounding box equivalent when possible.
  final (
    styleUrl,
    bounds,
    minZoom,
    maxZoom,
    includeIdeographs,
  ) = switch (definition) {
    mln.OfflineTilePyramidRegionDefinition d => (
      d.styleUrl,
      d.bounds,
      d.minZoom,
      d.maxZoom,
      d.includeIdeographs,
    ),
    mln.OfflineGeometryRegionDefinition d => (
      d.styleUrl,
      null,
      d.minZoom,
      d.maxZoom,
      d.includeIdeographs,
    ),
  };
  return <String, dynamic>{
    'id': info.id,
    'definition': <String, dynamic>{
      'styleUrl': styleUrl,
      if (bounds != null)
        'bounds': <double>[
          bounds.southwest.latitude,
          bounds.southwest.longitude,
          bounds.northeast.latitude,
          bounds.northeast.longitude,
        ],
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'includeIdeographs': includeIdeographs,
    },
    'metadata': info.metadata,
  };
}

Map<String, dynamic> _statusToMap(mln.OfflineRegionStatus status) {
  return <String, dynamic>{
    'downloadActive':
        status.downloadState == mln.OfflineRegionDownloadState.active,
    'completedResourceCount': status.completedResourceCount,
    'completedResourceSize': status.completedResourceSize,
    'completedTileCount': status.completedTileCount,
    'requiredTileCount': status.requiredTileCount,
    'completedTileSize': status.completedTileSize,
    'requiredResourceCount': status.requiredResourceCount,
    'requiredResourceCountIsPrecise': status.requiredResourceCountIsPrecise,
    'complete': status.complete,
  };
}
