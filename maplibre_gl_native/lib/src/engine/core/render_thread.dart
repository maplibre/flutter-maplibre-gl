import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:ffi/ffi.dart' show calloc;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

import 'vsync_pulse.dart';

/// The shim's display-paced render thread, seen from the engine isolate.
///
/// The thread that owns the AChoreographer also owns the live render session
/// and calls `render_update` itself, so no Dart work can delay a display frame
/// (see `cpp/shim.c`). This class is the engine isolate's half of that: it
/// hands the session over, borrows it back for the calls that are still Dart's,
/// and reports whether the thread is the one drawing.
///
/// A render session's owner thread is checked on every entry point, and Dart
/// still needs several of them (feature queries, feature state, resize, surface
/// replace, detach). So ownership ping-pongs: [borrow] blocks the render thread,
/// rebinds the session here for the duration of one call, and hands it back.
/// Renders happen 60-90 times a second and borrows are rare, so in the common
/// case the render thread simply keeps it.
class RenderThread {
  RenderThread();

  /// Null when the shim exposes no render service (not Android, a stale build,
  /// or the debug knob), which means Dart draws exactly as it did before.
  static final _ShimBindings? _bindings = _ShimBindings._tryLoad();

  mln.RenderSessionHandle? _session;

  /// Whether the render thread is drawing [session] specifically.
  ///
  /// One thread draws one session, so a second live map keeps drawing on the
  /// engine isolate; answering this per session is what stops it going black.
  /// False also whenever the shim is missing or the choreographer turned out to
  /// be unavailable and the driver fell back to timer pacing.
  bool isDrivingSession(mln.RenderSessionHandle session) =>
      _driving && identical(_session, session);

  bool _driving = false;

  /// Frames the render thread has drawn since process start, or null when it is
  /// not the one drawing.
  ///
  /// The frame loop watches this move instead of reading the return value of a
  /// render it no longer performs, which is what tells "the map is still
  /// moving" from "nothing left to draw" for the idle-park decision.
  int? get frameCount => _driving ? _bindings?.frameCount() : null;

  /// Offers [session] to the render thread, replacing any previous one.
  ///
  /// Takes effect only once [enable] has confirmed the display is pacing us;
  /// until then the session is remembered but Dart keeps drawing.
  void bindSession(mln.RenderSessionHandle? session) {
    _session = session;
    if (_driving) _publish();
  }

  /// Lets the render thread draw, because display pulses are confirmed live.
  void enable() {
    if (_driving) return;
    if (_bindings == null) return;
    _driving = true;
    _publish();
    debugPrint('[maplibre_gl_native] rendering on the display pulse thread');
  }

  /// Takes drawing back, because pulses stopped (timer fallback, or parked).
  ///
  /// Withdrawing the session leaves its owner thread wherever it was; the next
  /// Dart call rebinds it, which every session call does anyway.
  void disable() {
    if (!_driving) return;
    _driving = false;
    final bindings = _bindings;
    if (bindings == null) return;
    final session = _session;
    final unbind = bindings.unbind;
    if (session != null && unbind != null) {
      // Conditional withdrawal: a no-op if another map's session has since
      // been bound, so tearing this map down cannot blank that one.
      unbind(session.nativeAddress);
    } else {
      bindings.bind(0);
    }
  }

  void _publish() {
    final bindings = _bindings;
    if (bindings == null) return;
    if (bindings.bind(_session?.nativeAddress ?? 0) != 0) return;
    // The shim gave up on its mutex (a borrow was never returned; hot restart
    // mid-borrow is the known way). The display service is gone for the rest
    // of this process: fall back to drawing on this isolate, loudly.
    _driving = false;
    debugPrint(
      '[maplibre_gl_native] display render service unavailable '
      '(render mutex unrecoverable); rendering on the engine isolate',
    );
  }

  /// Arms or disarms per-frame sample collection on the render thread.
  ///
  /// Only meaningful while it is drawing; the engine session keeps its own
  /// collector for the frames it draws itself.
  void setStatsEnabled(bool enabled) {
    _bindings?.statsEnable(enabled ? 1 : 0);
    if (!enabled) _statsBuffers?.free();
    _statsBuffers = null;
  }

  _StatsBuffers? _statsBuffers;

  /// Drains the render thread's samples, or null when [session] is not the
  /// bound one and the buffer therefore has nothing to say about it.
  ///
  /// Keyed on the bound session rather than on [isDrivingSession]: after a
  /// pacing flip (driving turned off mid-scenario) the buffer still holds
  /// frames it drew for this session, and a drain must not orphan them; the
  /// core merges this with the isolate collector's samples.
  ///
  /// Shape matches `FrameStatsCollector.take`, so the benchmark harness reads
  /// the display thread's frames exactly as it read the isolate's.
  Map<String, dynamic>? takeStats(mln.RenderSessionHandle session) {
    final bindings = _bindings;
    if (!identical(_session, session) || bindings == null) return null;
    final buffers = _statsBuffers ??= _StatsBuffers.allocate();
    final written = bindings.statsTake(
      buffers.startUs,
      buffers.durationUs,
      _StatsBuffers.capacity,
      buffers.dropped,
    );
    final dropped = buffers.dropped.value;
    if (dropped > 0) {
      debugPrint(
        '[maplibre_gl_native] render thread dropped $dropped frame samples '
        '(buffer full); the numbers below cover $written frames only',
      );
    }
    return <String, dynamic>{
      'source': 'displayThread',
      'clockUs': _monotonicMicros(),
      'timestampsUs': Int64List.fromList(buffers.startUs.asTypedList(written)),
      'durationsUs': Int64List.fromList(
        buffers.durationUs.asTypedList(written),
      ),
    };
  }

  /// The clock the render thread stamps its samples with, in microseconds, so
  /// `clockUs` and the timestamps come from the same epoch. The pulse bindings
  /// already expose that same reader.
  static int _monotonicMicros() =>
      (VsyncPulser.monotonicNanos?.call() ?? 0) ~/ 1000;

  /// Runs [body] with [session] owned by the calling thread for its duration.
  ///
  /// The rebind is unconditional, and it is not only about the render thread:
  /// the runtime rebind that follows this isolate between OS threads no longer
  /// touches sessions (it must not, or it would steal one from the thread
  /// drawing it), so a session is re-homed here or nowhere.
  ///
  /// The handover blocks until the frame in flight finishes, so where it applies
  /// this must wrap a single leaf call and never nest: the native side is a
  /// plain mutex.
  T borrow<T>(mln.RenderSessionHandle session, T Function() body) {
    final bindings = _bindings;
    if (!isDrivingSession(session) || bindings == null) {
      // Nobody else can be calling this session, so no handover is needed.
      session.rebindThread();
      return body();
    }
    if (bindings.acquire() == 0) {
      // The shim's mutex is unrecoverable, so its thread has stopped touching
      // the session (it gives up the same way). Draw and call from here on.
      _driving = false;
      debugPrint(
        '[maplibre_gl_native] session borrow failed '
        '(render mutex unrecoverable); rendering on the engine isolate',
      );
      session.rebindThread();
      return body();
    }
    try {
      session.rebindThread();
      return body();
    } finally {
      bindings.release();
    }
  }
}

/// Native scratch the render thread drains its samples into, allocated once and
/// reused: a drain happens per benchmark scenario, not per frame.
class _StatsBuffers {
  _StatsBuffers._(this.startUs, this.durationUs, this.dropped);

  /// Matches MLN_SHIM_STATS_CAPACITY in the shim, so one drain always empties it.
  static const capacity = 4096;

  factory _StatsBuffers.allocate() => _StatsBuffers._(
    calloc<Int64>(capacity),
    calloc<Int64>(capacity),
    calloc<Int64>(),
  );

  final Pointer<Int64> startUs;
  final Pointer<Int64> durationUs;
  final Pointer<Int64> dropped;

  void free() {
    calloc.free(startUs);
    calloc.free(durationUs);
    calloc.free(dropped);
  }
}

class _ShimBindings {
  _ShimBindings._(
    this.bind,
    this.unbind,
    this.acquire,
    this.release,
    this.frameCount,
    this.statsEnable,
    this.statsTake,
  );

  /// Both report failure (0) when the shim's render mutex could not be taken
  /// in time; see `render_mutex_lock_or_give_up` in `cpp/shim.c`.
  final int Function(int sessionAddress) bind;

  /// Withdraws the session only if it is still the bound one (returns 1),
  /// leaving another map's binding alone (returns 0). Null when the shim
  /// predates it; callers then fall back to the unconditional `bind(0)`.
  final int Function(int sessionAddress)? unbind;

  final int Function() acquire;
  final void Function() release;
  final int Function() frameCount;
  final void Function(int enabled) statsEnable;
  final int Function(
    Pointer<Int64> startUs,
    Pointer<Int64> durationUs,
    int capacity,
    Pointer<Int64> dropped,
  )
  statsTake;

  /// Debug knob: build with `--dart-define=MLN_RENDER_ON_ISOLATE=true` to keep
  /// drawing on the engine isolate, which is the shape the 2026-07 benchmarks
  /// measured. Used by the A/B run that justifies this thread existing.
  static const _renderOnIsolate = bool.fromEnvironment('MLN_RENDER_ON_ISOLATE');

  static _ShimBindings? _tryLoad() {
    if (!Platform.isAndroid) return null;
    if (_renderOnIsolate) {
      debugPrint(
        '[maplibre_gl_native] MLN_RENDER_ON_ISOLATE set; '
        'rendering on the engine isolate',
      );
      return null;
    }
    try {
      // Open by soname for the same reason as the pulse bindings: the shim is
      // already loaded and dlopen returns that handle.
      final lib = DynamicLibrary.open('libmaplibre_gl_native_shim.so');
      if (!lib.providesSymbol('mln_shim_render_bind')) {
        debugPrint(
          '[maplibre_gl_native] shim has no render service (stale build?); '
          'rendering on the engine isolate',
        );
        return null;
      }
      return _ShimBindings._(
        lib.lookupFunction<Int32 Function(Int64), int Function(int)>(
          'mln_shim_render_bind',
        ),
        lib.providesSymbol('mln_shim_render_unbind')
            ? lib.lookupFunction<Int32 Function(Int64), int Function(int)>(
                'mln_shim_render_unbind',
              )
            : null,
        lib.lookupFunction<Int32 Function(), int Function()>(
          'mln_shim_render_acquire',
        ),
        lib.lookupFunction<Void Function(), void Function()>(
          'mln_shim_render_release',
        ),
        lib.lookupFunction<Int64 Function(), int Function()>(
          'mln_shim_render_frame_count',
        ),
        lib.lookupFunction<Void Function(Int32), void Function(int)>(
          'mln_shim_render_stats_enable',
        ),
        lib.lookupFunction<
          Int32 Function(Pointer<Int64>, Pointer<Int64>, Int32, Pointer<Int64>),
          int Function(Pointer<Int64>, Pointer<Int64>, int, Pointer<Int64>)
        >('mln_shim_render_stats_take'),
      );
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] render service unavailable ($error); '
        'rendering on the engine isolate',
      );
      return null;
    }
  }
}
