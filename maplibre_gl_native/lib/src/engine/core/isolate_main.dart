import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../protocol/protocol.dart';
import 'engine_core.dart';
import 'frame_driver.dart';

/// Spawn payload of the engine isolate.
class EngineIsolateBootstrap {
  const EngineIsolateBootstrap(
    this.toRoot, {
    this.cachePath,
    this.displayRefreshRate = 0,
  });

  final SendPort toRoot;

  /// Platform cache directory for the persistent tile cache database;
  /// resolved on the root isolate (the method channel lives there).
  final String? cachePath;

  /// Display refresh rate in Hz, read on the root isolate; 0 when unknown.
  /// Only the timer FALLBACK of the frame driver needs it (vsync pulses
  /// self-adapt to the display).
  final double displayRefreshRate;
}

/// Entrypoint of the engine isolate. Public only because [Isolate.spawn]
/// requires a top-level function reachable from the spawning library.
void engineIsolateMain(EngineIsolateBootstrap bootstrap) {
  final toRoot = bootstrap.toRoot;
  final commands = ReceivePort();
  final core = EngineCore.ensure(cachePath: bootstrap.cachePath);
  final driver = FrameDriver(
    core,
    displayRefreshRate: bootstrap.displayRefreshRate,
  );
  core.onEvent = (event) {
    // The driver consumes render-pending wakes internally; everything else
    // is presentation-facing and crosses to the root isolate.
    if (event is RenderPendingEvent) {
      driver.wake();
    } else {
      toRoot.send(event);
    }
  };
  commands.listen((message) {
    driver.ensureThread();
    try {
      switch (message) {
        case QueryRequest(:final id, :final query):
          try {
            toRoot.send(QueryReply(id, core.handleQuery(query)));
          } catch (error) {
            // The exception itself may hold native handles and cannot cross
            // the port; its message and runtime type name can, which is
            // enough for the host to rebuild a typed failure.
            toRoot.send(
              QueryFailure(id, '$error', errorType: '${error.runtimeType}'),
            );
          }
        case final EngineCommand command:
          core.handleCommand(command);
        default:
          debugPrint('[maplibre_gl_native] unexpected root message: $message');
      }
    } catch (error, stackTrace) {
      // The command loop survives a failed command on purpose (one bad
      // command must not take the whole engine down), but surviving in
      // silence left the symptom on screen with the cause in a log nobody
      // reads (a failed AttachSurfaceCommand IS a black map): push the
      // failure to the root as an event too.
      debugPrint(
        '[maplibre_gl_native] engine command failed '
        '(${message.runtimeType}): $error\n$stackTrace',
      );
      toRoot.send(EngineErrorEvent('${message.runtimeType}', '$error'));
    }
    driver.wake();
  });
  toRoot.send(commands.sendPort);
}
