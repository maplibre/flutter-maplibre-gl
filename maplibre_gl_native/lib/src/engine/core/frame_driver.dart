import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ffi';

import 'package:flutter/foundation.dart' show debugPrint;

import 'engine_core.dart';
import 'vsync_pulse.dart';

/// Self-scheduling frame loop of the engine isolate.
///
/// Mirrors the widget-ticker policy of the local host: frame-paced while
/// work is pending, parked on a low-frequency event pump when idle, woken by
/// commands and runtime events. There is no vsync on a background isolate;
/// the frame timer approximates it and `eglSwapBuffers` provides natural
/// backpressure against the texture's buffer queue.
class FrameDriver {
  FrameDriver(this._core, {double displayRefreshRate = 0})
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

  final EngineCore _core;
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
