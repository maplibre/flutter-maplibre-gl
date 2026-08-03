/// Events the engine pushes to the presentation side.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

/// Base type of everything the engine pushes to the presentation side.
///
/// Split in two because the engine has two scopes: most events belong to one
/// map session, while the offline database belongs to the engine itself. The
/// distinction used to be a sessionId of 0, which only worked because ids
/// start at 1; now it is a type, so an engine-scoped event cannot claim a
/// session by accident.
sealed class EngineEvent {
  const EngineEvent();
}

/// An event about one live map session.
sealed class SessionEvent extends EngineEvent {
  const SessionEvent(this.sessionId);

  final int sessionId;
}

/// An event about the engine itself, not bound to any session, so it carries
/// no session id.
sealed class EngineScopedEvent extends EngineEvent {
  const EngineScopedEvent();
}

/// The style finished loading.
class StyleLoadedEvent extends SessionEvent {
  const StyleLoadedEvent(super.sessionId);
}

/// A camera transition is about to start.
class CameraWillChangeEvent extends SessionEvent {
  const CameraWillChangeEvent(super.sessionId);
}

/// The camera moved this frame (already coalesced to one event per pump).
class CameraIsChangingEvent extends SessionEvent {
  const CameraIsChangingEvent(super.sessionId, this.camera);

  final CameraSnapshot camera;
}

/// The map became idle (tiles loaded, no transitions running).
class MapIdleEvent extends SessionEvent {
  const MapIdleEvent(super.sessionId, this.camera);

  final CameraSnapshot camera;
}

/// The map failed to load a resource or the style.
class MapLoadingFailedEvent extends SessionEvent {
  const MapLoadingFailedEvent(super.sessionId, this.message);

  final String message;
}

/// Work arrived for a session whose driver may be idle-parked; the
/// presentation side should resume ticking.
class RenderPendingEvent extends SessionEvent {
  const RenderPendingEvent(super.sessionId);
}

/// The engine hit an error it survived: a command handler, a frame-loop
/// turn, or the idle pump threw outside any query's reply path, so no Future
/// on the presentation side would ever have carried it. Without this event a
/// failed AttachSurfaceCommand is a black map with the reason buried in the
/// engine isolate's log.
///
/// Not fatal by definition: the engine keeps running (the command loop and
/// the frame loop both survive the throw). A dead engine is [EngineDiedEvent].
class EngineErrorEvent extends EngineScopedEvent {
  const EngineErrorEvent(this.context, this.message);

  /// What failed: the runtime type name of the command, or the loop that
  /// threw (`frame loop`, `idle pump`).
  final String context;

  /// Stringified engine-side exception; the exception itself may hold native
  /// handles and cannot cross the port.
  final String message;
}

/// The engine isolate died. Terminal: nothing respawns it, every pending
/// query has already been completed with an error, and later sends and
/// queries throw. Listeners get it so a live map can tell the app why it
/// just froze.
///
/// The one event never constructed on the engine side: the host synthesizes
/// it on the root isolate when the isolate's error/exit port fires, because
/// a dead isolate can no longer announce anything itself.
class EngineDiedEvent extends EngineScopedEvent {
  const EngineDiedEvent(this.reason);

  final String reason;
}

/// Reply to an offline region command, correlated by [requestId].
class OfflineResultEvent extends EngineScopedEvent {
  const OfflineResultEvent(
    this.requestId, {
    this.regions,
    this.status,
    this.error,
  });

  final int requestId;

  /// Plain region maps: {id, definition: {...}, metadata: Uint8List}.
  final List<Map<String, dynamic>>? regions;

  /// Plain status map (download counters).
  final Map<String, dynamic>? status;
  final String? error;
}

/// Download progress of an observed offline region.
class OfflineRegionProgressEvent extends EngineScopedEvent {
  const OfflineRegionProgressEvent(this.regionId, this.status);

  final int regionId;
  final Map<String, dynamic> status;
}

/// A resource error (or the tile-count limit) hit by an observed region.
class OfflineRegionErrorEvent extends EngineScopedEvent {
  const OfflineRegionErrorEvent(this.regionId, this.message);

  final int regionId;
  final String message;
}

/// Result of a [TakeSnapshotCommand]: tightly correlated by [requestId],
/// carrying premultiplied RGBA8 pixels at physical size, or an error.
class SnapshotResultEvent extends SessionEvent {
  const SnapshotResultEvent(
    super.sessionId,
    this.requestId, {
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.stride = 0,
    this.error,
  });

  final int requestId;
  final Uint8List? rgba;
  final int width;
  final int height;

  /// Bytes per pixel row (may exceed width * 4).
  final int stride;
  final String? error;
}
