import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show debugPrint;

import 'engine_core.dart';
import 'engine_protocol.dart';
import '../io/texture_bridge.dart';
import 'vsync_pulse.dart';

/// The engine host: owns the dedicated engine isolate and is the only door
/// through which the presentation side (widget, gestures, the
/// `MapLibrePlatform` adapter, the offline API) talks to the engine core.
///
/// Mutations go down as fire-and-forget [send]s, reads as [query]s with a
/// reply, and engine events come back through [addEventListener]; every
/// message crosses a SendPort to the isolate that owns all MapLibre Native
/// handles and drives its own frame loop ([_EngineDriver]), so a heavy
/// `renderUpdate` (tile integration) never stalls the UI isolate.
///
/// MapLibre Native handles are OS-thread affine and the Dart VM does not
/// guarantee isolate-to-thread pinning (dart-lang/sdk#46943): the engine
/// keeps a `gettid` watchdog and rebinds the runtime on migration via the
/// local upstream patch `mln_runtime_rebind_thread` (see
/// docs/upstream-native-ffi-proposals.md).
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
    await MapLibreGlNativeBridge.init();
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
    commands.send(_QueryRequest(id, query));
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
    return await MapLibreGlNativeBridge.getCacheDir();
  } catch (error) {
    debugPrint(
      '[maplibre_gl_native] no platform cache directory, '
      'using an in-memory tile cache: $error',
    );
    return null;
  }
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
  final core = FfiEngineCore.ensure(cachePath: bootstrap.cachePath);
  final driver = _EngineDriver(
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
  _EngineDriver(this._core, {double displayRefreshRate = 0})
    : _tid = _currentTid(),
      _fallbackInterval = displayRefreshRate >= 30
          ? Duration(microseconds: (1e6 / displayRefreshRate).round())
          : _frameInterval,
      _vsyncPeriodUs = displayRefreshRate >= 30
          ? (1e6 / displayRefreshRate).round()
          : 11111 {
    _pulser = VsyncPulser(_onPulse);
  }

  /// Timer pacing when neither the display refresh rate nor vsync pulses are
  /// available (pre-consolidation default).
  static const _frameInterval = Duration(milliseconds: 8);
  static const _idlePumpInterval = Duration(milliseconds: 100);
  static const _idleFrameLimit = 30;

  /// AChoreographer stops delivering with the screen off; without pulses a
  /// pulse-driven loop would wedge with work pending, so staleness parks it
  /// (the idle pump then keeps draining runtime work).
  static const _pulseStaleAfter = Duration(milliseconds: 500);

  final FfiEngineCore _core;
  final Duration _fallbackInterval;
  final int _vsyncPeriodUs;
  late final VsyncPulser _pulser;
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _frameTimer;
  Timer? _idlePump;
  Timer? _pulseWatchdog;
  int _idleFrames = 0;
  bool _inFrame = false;
  // Born parked so the very first wake renders immediately.
  bool _parked = true;
  bool _fallbackLogged = false;
  bool _pulsesLogged = false;
  int _lastFrameStartUs = 0;
  int _lastPulseUs = 0;
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
    final wasParked = _parked;
    _parked = false;
    _startPacing();
    if (_inFrame) return;
    if (_pulser.running) {
      // Pulses pace the loop. Render immediately only when waking from
      // park, so the first frame does not wait one vsync; while active,
      // scheduling here on every command would run the loop faster than
      // the display (observed 167 fps on a 90 Hz panel).
      if (wasParked && _frameTimer == null) {
        _frameTimer = Timer(Duration.zero, _frame);
      }
      return;
    }
    // Timer fallback: immediate first frame, then _frame self-schedules.
    _frameTimer ??= Timer(Duration.zero, _frame);
  }

  void _startPacing() {
    if (_pulser.start()) {
      if (!_pulsesLogged) {
        _pulsesLogged = true;
        debugPrint('[maplibre_gl_native] vsync pulses active');
      }
      _pulseWatchdog ??= Timer.periodic(_pulseStaleAfter, (_) {
        if (_clock.elapsedMicroseconds - _lastPulseUs >
            _pulseStaleAfter.inMicroseconds) {
          // Screen off / vsync gated: park rather than wedge; the idle pump
          // keeps runtime work moving and wake() re-arms the pulses.
          _park();
        }
      });
    } else if (!_fallbackLogged) {
      _fallbackLogged = true;
      debugPrint(
        '[maplibre_gl_native] vsync pulses unavailable; timer pacing at '
        '${_fallbackInterval.inMicroseconds} us',
      );
    }
  }

  void _park() {
    _parked = true;
    _pulser.stop();
    _pulseWatchdog?.cancel();
    _pulseWatchdog = null;
    _frameTimer?.cancel();
    _frameTimer = null;
    // Park: keep draining runtime events (network responses, tile loads) at
    // low frequency and resume frame pacing as soon as work shows up.
    _idlePump ??= Timer.periodic(_idlePumpInterval, (_) {
      ensureThread();
      if (_core.pumpAndCheckAnyRenderPending()) wake();
    });
  }

  /// Floor between frame starts: the [SetMaximumFpsCommand] cap when set,
  /// otherwise half a vsync period (drains the burst of pulses that queued
  /// behind a long frame without skipping a healthy cadence).
  int get _minFrameIntervalUs {
    final fps = _core.maxFps;
    final half = _vsyncPeriodUs ~/ 2;
    if (fps == null || fps <= 0) return half;
    final capUs = (1e6 / fps).round() - half;
    return capUs > half ? capUs : half;
  }

  /// One display frame elapsed; render if it is our cadence to do so.
  void _onPulse(int frameTimeNanos) {
    _lastPulseUs = _clock.elapsedMicroseconds;
    // Trailing pulse after park, or re-entrant during a long frame: drop.
    if (_parked || _inFrame) return;
    if (_lastPulseUs - _lastFrameStartUs < _minFrameIntervalUs) return;
    _frameTimer?.cancel();
    _frameTimer = null;
    _frame();
  }

  /// Timer pacing for the no-pulses path: display-refresh-matched when the
  /// rate is known, with the [SetMaximumFpsCommand] cap on top.
  Duration get _paceInterval {
    final fps = _core.maxFps;
    if (fps == null) return _fallbackInterval;
    final micros = (1000000 / fps).round();
    return micros < 4000
        ? const Duration(microseconds: 4000)
        : Duration(microseconds: micros);
  }

  void _frame() {
    _frameTimer = null;
    _inFrame = true;
    _lastFrameStartUs = _clock.elapsedMicroseconds;
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
      // Pulse mode: the next vsync pulse paces us. Fallback: self-schedule.
      if (!_pulser.running) {
        _frameTimer ??= Timer(_paceInterval, _frame);
      }
      return;
    }
    _park();
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
