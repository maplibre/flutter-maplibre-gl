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

  /// The spawn in flight. [ensure] memoizes it because it is async and two
  /// maps mounted in the same frame would otherwise race it into two engine
  /// isolates: two SQLite writers on the same tile cache database, with the
  /// losing isolate leaking a whole runtime nobody talks to. Cleared when
  /// the spawn fails so a later call can retry.
  static Future<EngineHost>? _starting;

  /// Process-global HTTP headers for engine resource requests
  /// (`MapLibreGlNative.setGlobalHttpHeaders`): applied at bootstrap, kept
  /// in sync by the setter afterwards.
  static Map<String, String> globalHttpHeaders = const {};

  /// Every engine query answers in milliseconds, so this deadline is
  /// deliberate overkill: a hit means the engine is truly gone or wedged,
  /// never that the deadline was too tight.
  static const Duration _defaultQueryTimeout = Duration(seconds: 15);

  SendPort? _commands;
  RawReceivePort? _fromEngine;
  RawReceivePort? _errors;
  RawReceivePort? _exit;
  Completer<SendPort>? _ready;

  /// Why the engine isolate died; null while it is alive. Death is terminal
  /// by design (no automatic respawn), so the reason doubles as the dead
  /// flag: every later [send] and [query] throws it instead of writing to a
  /// port nobody reads.
  String? _deathReason;

  final List<void Function(EngineEvent)> _listeners =
      <void Function(EngineEvent)>[];
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextRequestId = 1;

  /// Initializes the Android services, spawns the engine isolate, and waits
  /// for its command port. Concurrent callers share the one spawn in flight.
  ///
  /// Throws a [StateError] when the engine isolate cannot be bootstrapped:
  /// the FFI backend has no other engine to fall back to, and failing loudly
  /// beats rendering nothing.
  static Future<EngineHost> ensure() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _starting ??= _start();
  }

  static Future<EngineHost> _start() async {
    try {
      // mln_android_init must run before the engine isolate creates the
      // runtime; the method channel lives on the root isolate.
      await NativeBridge.init();
      final cacheDir = await _resolveCacheDir();
      final host = EngineHost._();
      await host._spawn(cacheDir);
      _instance = host;
      if (globalHttpHeaders.isNotEmpty) {
        host.send(SetHttpHeadersCommand(globalHttpHeaders));
      }
      return host;
    } catch (_) {
      // Nothing started: forget the memoized future so a later ensure() can
      // retry from a clean slate (unlike a death after startup, which is
      // terminal; see _onEngineDeath).
      _starting = null;
      rethrow;
    }
  }

  Future<void> _spawn(String? cacheDir) async {
    final fromEngine = _fromEngine = RawReceivePort();
    final ready = _ready = Completer<SendPort>();
    fromEngine.handler = (message) {
      if (message is SendPort && !ready.isCompleted) {
        ready.complete(message);
        return;
      }
      _onEngineMessage(message);
    };
    // Without these two ports an uncaught engine error kills the isolate in
    // silence: sends land in a dead port without an exception and every
    // pending query hangs forever. The error port fires first, with an
    // [error, stackTrace] string pair (the only form an arbitrary error can
    // cross in); the exit port also covers an exit without an error.
    final errors = _errors = RawReceivePort();
    errors.handler = (message) {
      final description = message is List && message.length >= 2
          ? '${message[0]}\n${message[1]}'
          : '$message';
      _onEngineDeath('uncaught error: $description');
    };
    final exit = _exit = RawReceivePort();
    exit.handler = (_) => _onEngineDeath('the isolate exited');
    try {
      await Isolate.spawn(
        engineIsolateMain,
        EngineIsolateBootstrap(
          fromEngine.sendPort,
          cachePath: cacheDir,
          displayRefreshRate: _displayRefreshRate(),
        ),
        onError: errors.sendPort,
        onExit: exit.sendPort,
        debugName: 'maplibre-engine',
      );
      _commands = await ready.future.timeout(const Duration(seconds: 10));
    } catch (error, stackTrace) {
      _closePorts();
      Error.throwWithStackTrace(
        StateError('The MapLibre FFI engine isolate failed to start: $error'),
        stackTrace,
      );
    }
  }

  /// The engine isolate is gone. Terminal by design (respawning would need
  /// every session, surface, and style to be rebuilt, which is the app's
  /// call, not this layer's): make the death loud and immediate everywhere
  /// instead of letting the app discover it as a collection of hangs.
  void _onEngineDeath(String reason) {
    // The exit port always fires after the error port: keep the real reason.
    if (_deathReason != null) return;
    _deathReason = reason;
    _commands = null;
    debugPrint('[maplibre_gl_native] the engine isolate DIED: $reason');
    _closePorts();
    // A spawn still waiting on the command port fails now, not at its
    // 10-second timeout.
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(
        StateError('The engine isolate died during startup: $reason'),
      );
    }
    // Every in-flight query completes with the reason instead of hanging
    // until its timeout.
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(
        StateError('The MapLibre FFI engine isolate died: $reason'),
      );
    }
    for (final listener in List.of(_listeners)) {
      listener(EngineDiedEvent(reason));
    }
  }

  void _closePorts() {
    _fromEngine?.close();
    _fromEngine = null;
    _errors?.close();
    _errors = null;
    _exit?.close();
    _exit = null;
  }

  void _onEngineMessage(Object? message) {
    switch (message) {
      case QueryReply(:final id, :final result):
        _pending.remove(id)?.complete(result);
      case QueryFailure(:final id, :final error, :final errorType):
        _pending
            .remove(id)
            ?.completeError(
              EngineQueryException(error, engineErrorType: errorType),
            );
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
  ///
  /// Throws a [StateError] when the engine isolate is not running or has
  /// died: a send into a dead port would disappear without a trace.
  void send(EngineCommand command) {
    final commands = _commands;
    if (commands == null) {
      throw StateError(_notRunningMessage());
    }
    commands.send(command);
  }

  /// Executes a read and completes with its reply.
  ///
  /// [timeout] bounds the wait: an engine that never answers (wedged in
  /// native code, killed mid-query) must surface as a [TimeoutException]
  /// naming the query, not as a Future that never completes.
  Future<R> query<R>(
    EngineQuery<R> query, {
    Duration timeout = _defaultQueryTimeout,
  }) {
    final commands = _commands;
    if (commands == null) {
      throw StateError(_notRunningMessage());
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send(QueryRequest(id, query));
    return completer.future
        .timeout(
          timeout,
          onTimeout: () {
            _pending.remove(id);
            throw TimeoutException(
              'engine query ${query.runtimeType} got no reply',
              timeout,
            );
          },
        )
        .then((value) => value as R);
  }

  String _notRunningMessage() {
    final reason = _deathReason;
    return reason == null
        ? 'The engine isolate is not running'
        : 'The MapLibre FFI engine isolate died: $reason';
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
