// Offline-region operations of the engine core.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

extension EngineOfflineOps on EngineCore {
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
    _offlineOps[handle] = _PendingOfflineOp(requestId, handle, take);
  }

  /// A completion event arrived that cannot be matched to its entry (a
  /// degenerate payload; see the callers). Without this the entry would sit in
  /// [_offlineOps] forever and the caller would only learn from its timeout.
  ///
  /// With exactly one operation in flight the completion can only be its, so
  /// that one is failed and released. With several the match is ambiguous:
  /// resolving any of them could fail an operation that is still running, so
  /// the event is only logged (the other entries still resolve normally when
  /// their own events arrive).
  void _resolveUnmatchedOfflineCompletion(String reason) {
    if (_offlineOps.isEmpty) return;
    if (_offlineOps.length > 1) {
      debugPrint(
        '[maplibre_gl_native] unmatched offline completion ($reason) with '
        '${_offlineOps.length} operations in flight; none resolved',
      );
      return;
    }
    debugPrint(
      '[maplibre_gl_native] unmatched offline completion ($reason); failing '
      'the single operation in flight',
    );
    final pending = _offlineOps.values.single;
    _offlineOps.clear();
    try {
      pending.handle.discard();
    } on mln.MaplibreException {
      // Expected when the runtime already dropped the operation; discarding
      // was only a courtesy for the case where it still holds the result.
    }
    final requestId = pending.requestId;
    if (requestId != null) {
      _emit(
        OfflineResultEvent(requestId, error: 'offline operation lost: $reason'),
      );
    }
  }

  /// Routes offline runtime events; returns whether the event was consumed.
  bool _handleOfflineEvent(mln.RuntimeEvent event) {
    final payload = event.payload;
    switch (event.eventType) {
      case mln.RuntimeEventType.offlineOperationCompleted:
        if (payload is! mln.RuntimeEventOfflineOperationCompleted) {
          // Version-skew payload we cannot decode. Any completion on this
          // runtime belongs to an operation this core started, so one of
          // _offlineOps just finished and cannot be matched.
          _resolveUnmatchedOfflineCompletion('undecodable completion payload');
          return true;
        }
        final operation = payload.operation;
        if (operation == null) {
          // The event names no live handle (the runtime no longer tracks the
          // operation), so the completion cannot be matched to its entry.
          _resolveUnmatchedOfflineCompletion(
            'completion for an operation the runtime no longer tracks',
          );
          return true;
        }
        final pending = _offlineOps.remove(operation);
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
    // A definition type this binding version does not understand, which can
    // only come from another consumer writing to the same cache database.
    // The region is still listed, with the fields we cannot read left empty.
    mln.UnknownOfflineRegionDefinition() => ('', null, 0.0, 0.0, false),
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
