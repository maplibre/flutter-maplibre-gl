import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint;

import 'engine_core.dart';
import 'engine_host.dart';
import 'engine_protocol.dart';
import 'texture_bridge.dart';

/// Phase-3 host: the engine core lives on a dedicated isolate and every
/// message crosses a SendPort.
///
/// The engine drives its own frame loop ([_EngineDriver]), so a heavy
/// `renderUpdate` (tile integration) no longer stalls the UI isolate; the
/// presentation side only owns the external texture and the gestures.
///
/// MapLibre Native handles are OS-thread affine and the Dart VM does not
/// guarantee isolate-to-thread pinning (dart-lang/sdk#46943): a device probe
/// showed the thread to be stable in practice, the engine keeps a `gettid`
/// watchdog to detect a migration deterministically, and the insurance plan
/// is an upstream `mln_runtime_rebind_thread` API (see
/// docs/upstream-native-ffi-proposals.md).
class IsolateEngineHost implements EngineHost {
  IsolateEngineHost._();

  static IsolateEngineHost? _instance;

  SendPort? _commands;
  final List<void Function(EngineEvent)> _listeners =
      <void Function(EngineEvent)>[];
  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextRequestId = 1;

  /// Initializes the Android services, spawns the engine isolate, and waits
  /// for its command port. Throws if the bootstrap fails.
  static Future<IsolateEngineHost> ensure() async {
    final existing = _instance;
    if (existing != null) return existing;
    // mln_android_init must run before the engine isolate creates the
    // runtime; the method channel lives on the root isolate.
    await MapLibreGlNativeBridge.init();
    final cacheDir = await FfiEngineConfig.resolveCacheDir();
    final host = IsolateEngineHost._();
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
        EngineIsolateBootstrap(fromEngine.sendPort, cachePath: cacheDir),
        debugName: 'maplibre-engine',
      );
      host._commands = await ready.future.timeout(const Duration(seconds: 10));
    } catch (error) {
      fromEngine.close();
      rethrow;
    }
    _instance = host;
    FfiEngineConfig.applyTo(host);
    return host;
  }

  void _onEngineMessage(Object? message) {
    switch (message) {
      case _QueryReply(:final id, :final result):
        _pending.remove(id)?.complete(result);
      case _QueryFailure(:final id, :final error):
        _pending.remove(id)?.completeError(StateError(error));
      case final EngineEvent event:
        for (final listener in List.of(_listeners)) {
          listener(event);
        }
      default:
        debugPrint('[maplibre_gl_native] unexpected engine message: $message');
    }
  }

  @override
  bool get drivesFrames => true;

  @override
  void addEventListener(void Function(EngineEvent event) listener) {
    _listeners.add(listener);
  }

  @override
  void removeEventListener(void Function(EngineEvent event) listener) {
    _listeners.remove(listener);
  }

  @override
  void send(EngineCommand command) {
    final commands = _commands;
    if (commands == null) {
      throw StateError('The engine isolate is not running');
    }
    commands.send(command);
  }

  @override
  Future<R> query<R>(EngineQuery<R> query) {
    final commands = _commands;
    if (commands == null) {
      throw StateError('The engine isolate is not running');
    }
    final id = _nextRequestId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    commands.send(_QueryRequest(id, query));
    return completer.future.then((value) => value as R);
  }

  // Frame driving lives inside the engine isolate; the widget never ticks.
  @override
  bool tick(int sessionId) => false;

  @override
  bool pumpAndCheckRenderPending(int sessionId) => false;
}

/// Query envelope with a correlation id for the reply.
class _QueryRequest {
  const _QueryRequest(this.id, this.query);

  final int id;
  final EngineQuery<Object?> query;
}

/// Successful query reply.
class _QueryReply {
  const _QueryReply(this.id, this.result);

  final int id;
  final Object? result;
}

/// Failed query reply; [error] is the stringified engine-side exception.
class _QueryFailure {
  const _QueryFailure(this.id, this.error);

  final int id;
  final String error;
}

/// Bootstraps (or returns) the process-wide engine host: the isolate-backed
/// one when [engineIsolate] is set (falling back to the single-isolate
/// engine on bootstrap failure), the local one otherwise. Shared by the map
/// widget and the offline API.
Future<EngineHost> ensureEngineHost({required bool engineIsolate}) async {
  if (engineIsolate) {
    try {
      return await IsolateEngineHost.ensure();
    } catch (error, stackTrace) {
      debugPrint(
        '[maplibre_gl_native] engine isolate bootstrap failed, '
        'falling back to the single-isolate engine: $error\n$stackTrace',
      );
    }
  }
  return LocalEngineHost.ensure();
}

/// Spawn payload of the engine isolate.
class EngineIsolateBootstrap {
  const EngineIsolateBootstrap(this.toRoot, {this.cachePath});

  final SendPort toRoot;

  /// Platform cache directory for the persistent tile cache database;
  /// resolved on the root isolate (the method channel lives there).
  final String? cachePath;
}

/// Entrypoint of the engine isolate. Public only because [Isolate.spawn]
/// requires a top-level function reachable from the spawning library.
void engineIsolateMain(EngineIsolateBootstrap bootstrap) {
  final toRoot = bootstrap.toRoot;
  final commands = ReceivePort();
  final core = FfiEngineCore.ensure(cachePath: bootstrap.cachePath);
  final driver = _EngineDriver(core);
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
        case _QueryRequest(:final id, :final query):
          try {
            toRoot.send(_QueryReply(id, core.handleQuery(query)));
          } catch (error) {
            toRoot.send(_QueryFailure(id, '$error'));
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

/// Self-scheduling frame loop of the engine isolate.
///
/// Mirrors the widget-ticker policy of the local host: frame-paced while
/// work is pending, parked on a low-frequency event pump when idle, woken by
/// commands and runtime events. There is no vsync on a background isolate;
/// the frame timer approximates it and `eglSwapBuffers` provides natural
/// backpressure against the texture's buffer queue.
class _EngineDriver {
  _EngineDriver(this._core) : _tid = _currentTid();

  static const _frameInterval = Duration(milliseconds: 8);
  static const _idlePumpInterval = Duration(milliseconds: 100);
  static const _idleFrameLimit = 30;

  final FfiEngineCore _core;
  Timer? _frameTimer;
  Timer? _idlePump;
  int _idleFrames = 0;
  bool _inFrame = false;
  int _tid;

  // Rolling stats, logged every few seconds while active (profile analysis).
  final Stopwatch _statsClock = Stopwatch()..start();
  int _statsFrames = 0;
  int _statsRenders = 0;
  int _statsRenderMicros = 0;
  int _statsMaxRenderMicros = 0;

  /// Switches to (or stays in) the frame-paced loop.
  ///
  /// Must never schedule extra frames while [_frame] is running: engine
  /// events emitted during the render (render-pending, camera) re-enter this
  /// method, and an extra zero-delay timer here would produce back-to-back
  /// frames that saturate the isolate and queue the gesture commands behind
  /// renders.
  void wake() {
    _idleFrames = 0;
    _idlePump?.cancel();
    _idlePump = null;
    if (_inFrame) return;
    _frameTimer ??= Timer(Duration.zero, _frame);
  }

  /// Frame pacing: the default interval, or the [SetMaximumFpsCommand] cap.
  Duration get _paceInterval {
    final fps = _core.maxFps;
    if (fps == null) return _frameInterval;
    final micros = (1000000 / fps).round();
    return micros < 4000
        ? const Duration(microseconds: 4000)
        : Duration(microseconds: micros);
  }

  void _frame() {
    _frameTimer = null;
    _inFrame = true;
    ensureThread();
    final renderClock = Stopwatch()..start();
    final rendered = developer.Timeline.timeSync('mln.frame', _core.frame);
    _inFrame = false;
    _statsFrames += 1;
    if (rendered) {
      _statsRenders += 1;
      final micros = renderClock.elapsedMicroseconds;
      _statsRenderMicros += micros;
      if (micros > _statsMaxRenderMicros) _statsMaxRenderMicros = micros;
    }
    _maybeLogStats();
    _idleFrames = rendered ? 0 : _idleFrames + 1;
    if (_idleFrames <= _idleFrameLimit) {
      _frameTimer ??= Timer(_paceInterval, _frame);
      return;
    }
    // Park: keep draining runtime events (network responses, tile loads) at
    // low frequency and resume frame pacing as soon as work shows up.
    _idlePump ??= Timer.periodic(_idlePumpInterval, (_) {
      ensureThread();
      if (_core.pumpAndCheckAnyRenderPending()) wake();
    });
  }

  void _maybeLogStats() {
    if (_statsClock.elapsedMilliseconds < 3000) return;
    if (_statsRenders > 0) {
      final seconds = _statsClock.elapsedMilliseconds / 1000;
      debugPrint(
        '[maplibre_gl_native] engine stats: '
        '${(_statsRenders / seconds).toStringAsFixed(1)} fps, '
        'frame avg ${(_statsRenderMicros / _statsRenders / 1000).toStringAsFixed(1)} ms, '
        'max ${(_statsMaxRenderMicros / 1000).toStringAsFixed(1)} ms, '
        'loop turns ${(_statsFrames / seconds).toStringAsFixed(0)}/s',
      );
    }
    _statsClock.reset();
    _statsFrames = 0;
    _statsRenders = 0;
    _statsRenderMicros = 0;
    _statsMaxRenderMicros = 0;
  }

  /// MapLibre Native handles are OS-thread affine and the VM does migrate
  /// this isolate across pool threads in practice (observed on device), so
  /// every entry into native code is preceded by this check: on a thread
  /// change the runtime and all its handles are rebound to the new thread
  /// via the local upstream patch (upstream_patches/0002).
  void ensureThread() {
    final tid = _currentTid();
    if (tid == _tid || tid == -1) return;
    try {
      _core.rebindThread();
      debugPrint(
        '[maplibre_gl_native] engine isolate resumed on OS thread '
        '$tid (was $_tid); runtime rebound',
      );
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] thread rebind failed ($_tid -> $tid): $error',
      );
    }
    _tid = tid;
  }

  static final int Function()? _gettid = () {
    final process = DynamicLibrary.process();
    if (!process.providesSymbol('gettid')) return null;
    return process.lookupFunction<Int32 Function(), int Function()>('gettid');
  }();

  /// Returns -1 when the platform has no `gettid` (watchdog disabled).
  static int _currentTid() => _gettid?.call() ?? -1;
}
