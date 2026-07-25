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
            toRoot.send(QueryFailure(id, '$error'));
          }
        case final EngineCommand command:
          core.handleCommand(command);
        default:
          debugPrint('[maplibre_gl_native] unexpected root message: $message');
      }
    } catch (error, stackTrace) {
      debugPrint(
        '[maplibre_gl_native] engine command failed '
        '(${message.runtimeType}): $error\n$stackTrace',
      );
    }
    driver.wake();
  });
  toRoot.send(commands.sendPort);
}
