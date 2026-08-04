import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show debugPrint;

import 'shim_library.dart';

/// Display-vsync pulses for the engine isolate's frame loop.
///
/// Bridges the shim's AChoreographer pulse thread (see `cpp/shim.c`) to
/// Dart: each display frame posts its timestamp to a [RawReceivePort]
/// created on the constructing isolate, so [onPulse] runs there. The port
/// mechanism is what makes hot restart safe: posting to a dead port is a
/// no-op and the native side parks itself.
///
/// When the shim (or the Dart API DL handshake) is unavailable, [start]
/// returns false and the caller must pace frames with a timer instead.
class VsyncPulser {
  VsyncPulser(this.onPulse);

  /// Invoked on the constructing isolate for every display frame while
  /// running (argument: choreographer frame time, nanoseconds).
  final void Function(int frameTimeNanos) onPulse;

  static final _VsyncBindings? _bindings = _VsyncBindings._tryLoad();

  /// Reads the clock the pulse timestamps are stamped with, in nanoseconds.
  ///
  /// A pulse timestamp only means something next to a reading of the same
  /// clock: it comes from `CLOCK_MONOTONIC` and Dart's [Stopwatch] has an
  /// unrelated epoch, so the age of a pulse cannot be worked out without this.
  /// The shim provides it, which makes the reader and the stamper the same
  /// library by construction.
  ///
  /// Null where no such clock is reachable: not Android, or a shim built
  /// before it existed. Callers must then do without an age. Resolved
  /// independently of [_bindings], because reading the clock needs neither the
  /// choreographer nor the Dart API DL handshake.
  static final int Function()? monotonicNanos = _lookupClock();

  RawReceivePort? _port;
  bool _running = false;

  bool get running => _running;

  /// Starts (or resumes) pulses; false means the caller must fall back to
  /// timer pacing.
  bool start() {
    final bindings = _bindings;
    if (bindings == null) return false;
    if (_running) return true;
    _port ??= RawReceivePort(_handleMessage, 'maplibre-vsync');
    if (bindings.start(_port!.sendPort.nativePort) != 1) return false;
    return _running = true;
  }

  /// Pauses pulses. At most one trailing pulse may still be delivered after
  /// this returns; the caller drops it via its own parked check.
  void stop() {
    if (!_running) return;
    _running = false;
    _bindings?.stop();
  }

  void _handleMessage(Object? message) {
    if (message is int && _running) onPulse(message);
  }

  static int Function()? _lookupClock() {
    // shimLibrary logs once when the shim itself cannot be opened.
    final lib = shimLibrary;
    if (lib == null) return null;
    if (!lib.providesSymbol('mln_shim_monotonic_nanos')) {
      debugPrint(
        '[maplibre_gl_native] shim has no monotonic clock (stale build?); '
        'pulse ages unavailable',
      );
      return null;
    }
    return lib.lookupFunction<Int64 Function(), int Function()>(
      'mln_shim_monotonic_nanos',
    );
  }
}

class _VsyncBindings {
  _VsyncBindings._(this.start, this.stop);

  final int Function(int nativePort) start;
  final void Function() stop;

  /// Debug knob: build with `--dart-define=MLN_FORCE_TIMER_PACING=true` to
  /// skip the choreographer pulses and exercise the refresh-rate-matched
  /// timer fallback instead (used by the vsync A/B benchmark).
  static const _forceTimerPacing = bool.fromEnvironment(
    'MLN_FORCE_TIMER_PACING',
  );

  static _VsyncBindings? _tryLoad() {
    if (_forceTimerPacing) {
      debugPrint(
        '[maplibre_gl_native] MLN_FORCE_TIMER_PACING set; '
        'using timer frame pacing',
      );
      return null;
    }
    // shimLibrary logs once when the shim itself cannot be opened; the
    // driver logs the timer fallback when start() then fails.
    final lib = shimLibrary;
    if (lib == null) return null;
    try {
      if (!lib.providesSymbol('mln_shim_vsync_start')) {
        debugPrint(
          '[maplibre_gl_native] shim has no vsync symbols (stale build?); '
          'falling back to timer frame pacing',
        );
        return null;
      }
      final dartInit = lib
          .lookupFunction<
            Int64 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('mln_shim_dart_init');
      if (dartInit(NativeApi.initializeApiDLData) != 0) {
        debugPrint(
          '[maplibre_gl_native] Dart API DL version mismatch; '
          'falling back to timer frame pacing',
        );
        return null;
      }
      return _VsyncBindings._(
        lib.lookupFunction<Int32 Function(Int64), int Function(int)>(
          'mln_shim_vsync_start',
        ),
        lib.lookupFunction<Void Function(), void Function()>(
          'mln_shim_vsync_stop',
        ),
      );
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] vsync shim unavailable ($error); '
        'falling back to timer frame pacing',
      );
      return null;
    }
  }
}
