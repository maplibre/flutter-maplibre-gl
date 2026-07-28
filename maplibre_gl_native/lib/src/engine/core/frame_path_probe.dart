import 'package:flutter/foundation.dart' show debugPrint;

import 'vsync_pulse.dart';

/// Why a display pulse did not turn into a frame.
enum PulseDrop {
  /// Trailing pulse delivered after the loop parked. Benign: nothing was
  /// pending, so there was no frame to be late for.
  parked,

  /// Arrived while the previous frame was still running. Structurally
  /// impossible while the isolate owns the render, because a port message
  /// cannot be delivered while another handler runs on the same isolate; it
  /// stops being impossible the day the render moves off the isolate.
  inFrame,

  /// Dropped by the cadence floor: an explicit fps cap, or the half-period
  /// floor that keeps two frames from running back to back. Deliberate.
  floor,
}

/// Measures where a display frame's time goes in the engine isolate, from the
/// display's own frame boundary to the end of `render_update`.
///
/// The path has three segments today, and the point of this probe is to size
/// them against each other:
///
/// ```text
///   vsync boundary --wake--> isolate --pump--> drained --render--> submitted
/// ```
///
/// - `wake` is the choreographer callback on its own thread, the post to this
///   isolate's port, and the VM getting round to running the handler.
/// - `pump` is the runtime drain: queued owner-thread work plus event dispatch.
/// - `render` is `render_update`, the CPU cost of encoding and submitting the
///   frame. The GPU finishes later and is not observable from here.
///
/// `wake` and `pump` are in the frame path only because Dart owns the render
/// session. If they are a large share of the total, moving that ownership to
/// the vsync thread buys real latency; if they are noise, the same change is
/// about correctness rather than speed. That is the decision this probe exists
/// to inform, so it reports the segments separately rather than one number.
///
/// Not to be confused with `FrameStatsCollector`, which samples render
/// durations per session for the benchmark app to drain over the protocol.
/// This one measures the isolate's whole frame loop and reports to the log.
///
/// Off unless the app is built with `--dart-define=MLN_FRAME_PATH_PROBE=true`,
/// since it reads the clock four times per frame and keeps a window of
/// samples: use [createIfArmed], and treat a null probe as the normal case.
class FramePathProbe {
  FramePathProbe._(this._nowNanos, this._budgetUs)
    : _windowStartNanos = _nowNanos();

  /// Build with `--dart-define=MLN_FRAME_PATH_PROBE=true` to arm the probe.
  static const bool armed = bool.fromEnvironment('MLN_FRAME_PATH_PROBE');

  /// How often the accumulated window is reported, matching the frame driver's
  /// own rolling log so the two lines can be read side by side.
  static const Duration _window = Duration(seconds: 3);

  /// Ceiling on samples kept per segment, in case a window somehow never
  /// closes. Three seconds at 120 Hz is ~360, so this is pure insurance.
  static const int _sampleCap = 4096;

  /// Returns a probe, or null when it is not armed or cannot measure: no
  /// Android shim, or a shim too old to carry the clock (a stale build).
  static FramePathProbe? createIfArmed({required int vsyncPeriodUs}) {
    if (!armed) return null;
    final clock = VsyncPulser.monotonicNanos;
    if (clock == null) {
      debugPrint(
        '[maplibre_gl_native] frame path probe armed but the shim clock is '
        'unavailable; not measuring',
      );
      return null;
    }
    debugPrint(
      '[maplibre_gl_native] frame path probe armed; budget $vsyncPeriodUs us',
    );
    return FramePathProbe._(clock, vsyncPeriodUs);
  }

  final int Function() _nowNanos;

  /// One display period: a frame whose total exceeds it is presented late.
  ///
  /// Seeded from the refresh rate the host read at startup, then re-derived
  /// from the pulses themselves at every report. The panel switches mode while
  /// the app runs (this hardware drops from 90 to 60 Hz on its own), and a
  /// budget frozen at startup would mark perfectly healthy frames late.
  int _budgetUs;

  // The pulse waiting to be attributed to a turn, or -1 when the next turn is
  // not pulse-driven (timer pacing, or the immediate frame on waking from
  // park). Every pulse is either dropped or consumed by the turn it starts, so
  // a stamp is never carried over to an unrelated turn.
  int _pendingVsyncNanos = -1;

  int _turnVsyncNanos = -1;
  int _turnStartNanos = 0;
  int _pumpEndNanos = 0;
  int _lastVsyncNanos = -1;

  // Window accumulators, all cleared by [_report].
  int _windowStartNanos;
  final List<int> _wakeUs = <int>[];
  final List<int> _pumpUs = <int>[];
  final List<int> _renderUs = <int>[];
  final List<int> _totalUs = <int>[];
  final List<int> _cadenceUs = <int>[];
  final Map<PulseDrop, int> _drops = <PulseDrop, int>{
    for (final reason in PulseDrop.values) reason: 0,
  };
  int _turns = 0;
  int _renders = 0;
  int _timerTurns = 0;
  int _late = 0;

  // Segment breakdown of the window's single worst frame. Percentiles say how
  // often the path is slow; this says which segment was to blame when it was
  // slowest, which the per-segment percentiles cannot (they are medians of
  // different frames).
  int _worstTotalUs = -1;
  int _worstWakeUs = 0;
  int _worstPumpUs = 0;
  int _worstRenderUs = 0;

  /// A display pulse arrived, stamped by the choreographer at [vsyncNanos].
  void pulse(int vsyncNanos) {
    _pendingVsyncNanos = vsyncNanos;
    if (_lastVsyncNanos >= 0) {
      _add(_cadenceUs, (vsyncNanos - _lastVsyncNanos) ~/ 1000);
    }
    _lastVsyncNanos = vsyncNanos;
  }

  /// The pulse just stamped by [pulse] will not produce a frame.
  void dropPulse(PulseDrop reason) {
    _drops[reason] = _drops[reason]! + 1;
    _pendingVsyncNanos = -1;
    // Parking stops the pulse stream, so the next interval would read as one
    // long gap rather than a display period.
    if (reason == PulseDrop.parked) _lastVsyncNanos = -1;
  }

  /// A frame turn is starting, whatever woke it.
  void beginTurn() {
    _turnVsyncNanos = _pendingVsyncNanos;
    _pendingVsyncNanos = -1;
    _turnStartNanos = _nowNanos();
  }

  /// The runtime drain is done; what follows is the draw.
  void pumped() => _pumpEndNanos = _nowNanos();

  /// The turn is over. [rendered] is whether anything was actually drawn.
  void endTurn({required bool rendered}) {
    final endNanos = _nowNanos();
    _turns += 1;
    if (rendered) _renders += 1;
    final vsyncNanos = _turnVsyncNanos;
    _turnVsyncNanos = -1;
    if (vsyncNanos < 0) {
      _timerTurns += 1;
    } else if (rendered) {
      // Only turns that drew carry a latency: an idle turn has no frame to be
      // late for, and averaging it in would flatter every segment.
      final totalUs = (endNanos - vsyncNanos) ~/ 1000;
      final wakeUs = (_turnStartNanos - vsyncNanos) ~/ 1000;
      final pumpUs = (_pumpEndNanos - _turnStartNanos) ~/ 1000;
      final renderUs = (endNanos - _pumpEndNanos) ~/ 1000;
      _add(_wakeUs, wakeUs);
      _add(_pumpUs, pumpUs);
      _add(_renderUs, renderUs);
      _add(_totalUs, totalUs);
      if (totalUs > _budgetUs) _late += 1;
      if (totalUs > _worstTotalUs) {
        _worstTotalUs = totalUs;
        _worstWakeUs = wakeUs;
        _worstPumpUs = pumpUs;
        _worstRenderUs = renderUs;
      }
    }
    if (endNanos - _windowStartNanos >= _window.inMicroseconds * 1000) {
      _report(endNanos);
    }
  }

  static void _add(List<int> samples, int value) {
    if (samples.length < _sampleCap) samples.add(value);
  }

  void _report(int nowNanos) {
    final elapsedUs = (nowNanos - _windowStartNanos) ~/ 1000;
    if (_renders > 0) {
      final droppedTotal = _drops.values.reduce((a, b) => a + b);
      final counts =
          'turns $_turns (rendered $_renders, no pulse $_timerTurns), '
          'late $_late (${_percent(_late, _renders)}), '
          'pulse cadence ${_median(_cadenceUs)} us';
      final worst =
          'worst frame us: wake $_worstWakeUs pump $_worstPumpUs '
          'render $_worstRenderUs total $_worstTotalUs';
      final dropped =
          'pulses dropped $droppedTotal: '
          '${_drops[PulseDrop.inFrame]} mid-frame, '
          '${_drops[PulseDrop.floor]} by the floor, '
          '${_drops[PulseDrop.parked]} after park';
      // Every line carries the tag: logcat has no notion of a multi-line
      // record, so an unprefixed continuation is unfindable and unattributable.
      debugPrint(
        <String>[
          'frame path over ${_seconds(elapsedUs)} s, budget $_budgetUs us',
          counts,
          _line('wake  ', _wakeUs),
          _line('pump  ', _pumpUs),
          _line('render', _renderUs),
          _line('total ', _totalUs),
          worst,
          dropped,
        ].map((line) => '[maplibre_gl_native] $line').join('\n'),
      );
    }
    // Follow the display rather than the startup refresh rate. Guarded to a
    // plausible period, and to a full window's worth of samples, so one odd
    // window cannot poison the yardstick for every window after it.
    final cadenceUs = _medianOrNull(_cadenceUs);
    if (cadenceUs != null &&
        _cadenceUs.length >= 20 &&
        cadenceUs >= 4000 &&
        cadenceUs <= 40000) {
      _budgetUs = cadenceUs;
    }
    _windowStartNanos = nowNanos;
    _wakeUs.clear();
    _pumpUs.clear();
    _renderUs.clear();
    _totalUs.clear();
    _cadenceUs.clear();
    for (final reason in PulseDrop.values) {
      _drops[reason] = 0;
    }
    _turns = 0;
    _renders = 0;
    _timerTurns = 0;
    _late = 0;
    _worstTotalUs = -1;
    _worstWakeUs = 0;
    _worstPumpUs = 0;
    _worstRenderUs = 0;
  }

  static String _seconds(int micros) => (micros / 1e6).toStringAsFixed(1);

  static String _percent(int part, int whole) =>
      whole == 0 ? '0%' : '${(100 * part / whole).toStringAsFixed(1)}%';

  static String _line(String name, List<int> samples) {
    if (samples.isEmpty) return '$name no samples';
    final sorted = List<int>.of(samples)..sort();
    return '$name us: p50 ${_at(sorted, 0.50)} p90 ${_at(sorted, 0.90)} '
        'p99 ${_at(sorted, 0.99)} max ${sorted.last} (n ${sorted.length})';
  }

  static int _at(List<int> sorted, double quantile) =>
      sorted[((sorted.length - 1) * quantile).round()];

  static int? _medianOrNull(List<int> samples) {
    if (samples.isEmpty) return null;
    final sorted = List<int>.of(samples)..sort();
    return _at(sorted, 0.50);
  }

  static String _median(List<int> samples) =>
      '${_medianOrNull(samples) ?? 'n/a'}';
}
