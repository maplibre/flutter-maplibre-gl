import '../protocol/protocol.dart';
import 'engine_host.dart';

/// Handle to one live map session: the [EngineHost] plus the engine-assigned
/// session id.
///
/// Exists so the presentation side passes one object around instead of
/// threading a host and an id (or, worse, two closures) through every
/// collaborator and every call site.
///
/// Collaborators (the gesture handler, feature interaction, the location
/// component, snapshots) receive a `MapSession? Function()` rather than a
/// `MapSession`, because they are built with the widget while the session only
/// exists once the engine has created it, and it becomes null again on
/// dispose. Reading it per call is what keeps them from holding a stale one:
/// null means "no live map", which each collaborator answers for itself, by
/// skipping the work or by [requireSession].
class MapSession {
  const MapSession(this.host, this.id);

  final EngineHost host;

  /// Engine-assigned id, the `sessionId` every [SessionCommand] carries.
  final int id;

  void send(EngineCommand command) => host.send(command);

  Future<R> query<R>(EngineQuery<R> query) => host.query(query);
}

/// [session] or a loud failure, for the calls that cannot do anything without
/// a live map. Defined once so every caller fails with the same message.
MapSession requireSession(MapSession? session) {
  if (session == null) {
    throw StateError('The FFI map session is not ready yet');
  }
  return session;
}
