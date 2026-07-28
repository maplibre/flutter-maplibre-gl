/// Message protocol between the presentation layer (widget, gestures, the
/// `MapLibrePlatform` adapter) and the engine core that owns every MapLibre
/// Native handle.
///
/// This is the isolate boundary, and the rule that keeps it one: every field
/// in this file must stay isolate-sendable (numbers, strings, bools, lists,
/// maps, typed data), and this library must not import Flutter, `dart:ui`, or
/// `maplibre_native_ffi`; ARCHITECTURE.md explains why.
library;

import 'dart:typed_data';

part 'session.dart';
part 'camera.dart';
part 'style.dart';
part 'runtime.dart';
part 'queries.dart';
part 'events.dart';

/// Base type of everything the presentation side sends to the engine.
sealed class EngineMessage {
  const EngineMessage();
}

/// A mutation. Fire-and-forget: no reply value.
sealed class EngineCommand extends EngineMessage {
  const EngineCommand();
}

/// A read. Produces a reply of type [R].
sealed class EngineQuery<R> extends EngineMessage {
  const EngineQuery();
}

/// A command that targets one live map session.
sealed class SessionCommand extends EngineCommand {
  const SessionCommand(this.sessionId);

  final int sessionId;
}

/// A query that targets one live map session.
sealed class SessionQuery<R> extends EngineQuery<R> {
  const SessionQuery(this.sessionId);

  final int sessionId;
}

/// Query envelope with a correlation id for the reply. A command needs no
/// envelope: it is sent as-is because it has no reply to correlate.
class QueryRequest {
  const QueryRequest(this.id, this.query);

  final int id;
  final EngineQuery<Object?> query;
}

/// Successful reply to the [QueryRequest] with the same [id].
class QueryReply {
  const QueryReply(this.id, this.result);

  final int id;
  final Object? result;
}

/// Failed reply to the [QueryRequest] with the same [id]; [error] is the
/// stringified engine-side exception.
class QueryFailure {
  const QueryFailure(this.id, this.error);

  final int id;
  final String error;
}

/// Partial camera state; null fields are left unchanged by the engine.
class CameraSpec {
  const CameraSpec({
    this.latitude,
    this.longitude,
    this.zoom,
    this.bearing,
    this.pitch,
  });

  final double? latitude;
  final double? longitude;
  final double? zoom;
  final double? bearing;
  final double? pitch;
}

/// A geographic rectangle, in the south/west/north/east vocabulary the
/// maplibre_gl API itself uses.
///
/// Travels in both directions: as a camera constraint or a fit target on the
/// way down, as the visible region on the way up.
class BoundsSpec {
  const BoundsSpec({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Latitude of the southern edge.
  final double south;

  /// Longitude of the western edge.
  final double west;

  /// Latitude of the northern edge.
  final double north;

  /// Longitude of the eastern edge.
  final double east;
}

/// Where the camera center is allowed to go.
///
/// Three states, because the engine distinguishes them: absent means leave the
/// current constraint alone, [BoundsConstraintSpec.bounded] replaces it, and
/// [BoundsConstraintSpec.unbounded] removes it. Removing is not the same as
/// constraining to the whole world: world bounds still clamp longitude to
/// [-180, 180], which stops the map from panning across the antimeridian.
class BoundsConstraintSpec {
  /// Keeps the camera center inside [bounds].
  const BoundsConstraintSpec.bounded(BoundsSpec this.bounds);

  /// Lets the camera center go anywhere.
  const BoundsConstraintSpec.unbounded() : bounds = null;

  /// The box for a bounded constraint, null when unbounded.
  final BoundsSpec? bounds;
}

/// A geographic coordinate travelling back from the engine.
///
/// Deliberately not maplibre_gl's `LatLng`: the protocol stays free of the
/// plugin API and of Flutter. A record, so it costs nothing beyond the two
/// doubles it carries, and reads as `.latitude` instead of `[0]`.
typedef GeoPoint = ({double latitude, double longitude});

/// A screen-space point in logical pixels, travelling back from the engine.
///
/// Distinct from [GeoPoint] on purpose: they are both two doubles, and
/// the type is what stops a latitude from being read as an x.
typedef ScreenPoint = ({double x, double y});

/// Complete camera state pushed by the engine (events, [GetCameraQuery]).
class CameraSnapshot {
  const CameraSnapshot({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.bearing,
    required this.pitch,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;
  final double pitch;
}
