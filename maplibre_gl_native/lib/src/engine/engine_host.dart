import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint;

import '../native_bridge.dart';
import '../protocol/protocol.dart';
import 'core/isolate_main.dart';

/// The engine host: owns the dedicated engine isolate and is the only door
/// through which the presentation side (widget, gestures, the
/// `MapLibrePlatform` adapter, the offline API) talks to the engine core.
///
/// Runs on the ROOT isolate. Mutations go down as fire-and-forget [send]s,
/// reads as [query]s with a reply, and engine events come back through
/// [addEventListener]; every message crosses a SendPort to the isolate that
/// owns all MapLibre Native handles and drives its own frame loop, so a heavy
/// `renderUpdate` (tile integration) never stalls the UI isolate.
///
/// MapLibre Native handles are OS-thread affine and the Dart VM does not
/// guarantee isolate-to-thread pinning (dart-lang/sdk#46943): the engine
/// keeps a `gettid` watchdog and rebinds the runtime on migration via the
/// local upstream patch `mln_runtime_rebind_thread` (see the package's
/// `upstream_patches/`).
///
/// A test double can still `implements EngineHost` thanks to Dart's implicit
/// interfaces.
class EngineHost {
  EngineHost._();

  static EngineHost? _instance;

  /// The live host, once [ensure] has completed.
  static EngineHost? get instance => _instance;

  /// Process-global HTTP headers for engine resource requests
  /// (`MapLibreGlNative.setGlobalHttpHeaders`): applied at bootstrap, kept
  /// in sync by the setter afterwards.
  static Map<String, String> globalHttpHeaders = const {};

  SendPort? _commands;
  final List<void Function(EngineEvent)> _listeners =
      <void Function(EngineEvent)>[];
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextRequestId = 1;

  /// Initializes the Android services, spawns the engine isolate, and waits
  /// for its command port.
  ///
  /// Throws a [StateError] when the engine isolate cannot be bootstrapped:
  /// the FFI backend has no other engine to fall back to, and failing loudly
  /// beats rendering nothing.
  static Future<EngineHost> ensure() async {
    final existing = _instance;
    if (existing != null) return existing;
    // mln_android_init must run before the engine isolate creates the
    // runtime; the method channel lives on the root isolate.
    await NativeBridge.init();
    final cacheDir = await _resolveCacheDir();
    final host = EngineHost._();
    final fromEngine = RawReceivePort();
    final ready = Completer<SendPort>();
    fromEngine.handler = (message) {
      if (message is SendPort && !ready.isCompleted) {
        ready.complete(message);
        return;
      }
      host._onEngineMessage(message);
    };
    try {
      await Isolate.spawn(
        engineIsolateMain,
        EngineIsolateBootstrap(
          fromEngine.sendPort,
          cachePath: cacheDir,
          displayRefreshRate: _displayRefreshRate(),
        ),
        debugName: 'maplibre-engine',
      );
      host._commands = await ready.future.timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      fromEngine.close();
      Error.throwWithStackTrace(
        StateError('The MapLibre FFI engine isolate failed to start: $error'),
        stackTrace,
      );
    }
    _instance = host;
    if (globalHttpHeaders.isNotEmpty) {
      host.send(SetHttpHeadersCommand(globalHttpHeaders));
    }
    return host;
  }

  void _onEngineMessage(Object? message) {
    switch (message) {
      case QueryReply(:final id, :final result):
        _pending.remove(id)?.complete(result);
      case QueryFailure(:final id, :final error):
        _pending.remove(id)?.completeError(StateError(error));
      case final EngineEvent event:
        for (final listener in List.of(_listeners)) {
          listener(event);
        }
      default:
        debugPrint('[maplibre_gl_native] unexpected engine message: $message');
    }
  }

  /// Registers a listener for events pushed by the engine.
  void addEventListener(void Function(EngineEvent event) listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered event listener.
  void removeEventListener(void Function(EngineEvent event) listener) {
    _listeners.remove(listener);
  }

  /// Sends a fire-and-forget mutation.
  void send(EngineCommand command) {
    final commands = _commands;
    if (commands == null) {
      throw StateError('The engine isolate is not running');
    }
    commands.send(command);
  }

  /// Executes a read and completes with its reply.
  Future<R> query<R>(EngineQuery<R> query) {
    final commands = _commands;
    if (commands == null) {
      throw StateError('The engine isolate is not running');
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send(QueryRequest(id, query));
    return completer.future.then((value) => value as R);
  }
}

/// Display refresh rate in Hz for the frame driver's timer fallback;
/// 0 when unknown (only the root isolate can read the displays).
double _displayRefreshRate() {
  final displays = PlatformDispatcher.instance.displays;
  if (displays.isEmpty) return 0;
  final rate = displays.first.refreshRate;
  return rate.isFinite && rate > 0 ? rate : 0;
}

/// Resolves the platform cache directory backing the persistent tile cache;
/// null selects an in-memory cache.
Future<String?> _resolveCacheDir() async {
  try {
    return await NativeBridge.getCacheDir();
  } catch (error) {
    debugPrint(
      '[maplibre_gl_native] no platform cache directory, '
      'using an in-memory tile cache: $error',
    );
    return null;
  }
}
