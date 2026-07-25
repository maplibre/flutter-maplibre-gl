import '../protocol/protocol.dart';
import 'engine_host.dart';

/// Handle to one live map session: the [EngineHost] plus the engine-assigned
/// session id.
///
/// Exists so the presentation side passes one object around instead of
/// threading a host and an id (or, worse, two closures) through every
/// collaborator and every call site.
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
