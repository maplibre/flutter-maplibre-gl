import 'dart:typed_data';

import 'vsync_pulse.dart';

/// Per-frame render statistics collection (benchmark instrumentation) for
/// one engine session.
///
/// Armed by `SetFrameStatsEnabledCommand` and drained by
/// `TakeFrameStatsQuery`. It lives in the engine core so both hosts (the
/// single-isolate widget ticker and the isolate frame driver) measure the
/// exact same code path.
///
/// Samples are stamped with the shim's `CLOCK_MONOTONIC` reader when it is
/// available, so they share an epoch with the display thread's samples and
/// the two sides can be merged into one series (see [mergeStats]). Without a
/// shim (not Android, stale build) a [Stopwatch] stands in and merging still
/// works, because only one side can be producing samples then.
class FrameStatsCollector {
  FrameStatsCollector();

  /// Microsecond clock shared with the shim's samples when possible.
  static final int Function() _clockUs = () {
    final nanos = VsyncPulser.monotonicNanos;
    if (nanos != null) return () => nanos() ~/ 1000;
    final stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsedMicroseconds;
  }();

  final List<int> _timestampsUs = <int>[];
  final List<int> _durationsUs = <int>[];

  /// Runs [render] recording its start time and wall duration (CPU command
  /// encoding + submit; GPU completion is not observable from here).
  void measure(void Function() render) {
    final startUs = _clockUs();
    render();
    _timestampsUs.add(startUs);
    _durationsUs.add(_clockUs() - startUs);
  }

  /// Drains the collected samples without stopping the collection.
  Map<String, dynamic> take() {
    final stats = <String, dynamic>{
      'source': 'isolate',
      'clockUs': _clockUs(),
      'timestampsUs': Int64List.fromList(_timestampsUs),
      'durationsUs': Int64List.fromList(_durationsUs),
    };
    _timestampsUs.clear();
    _durationsUs.clear();
    return stats;
  }

  /// The shape [take] would reply with when collection was never armed.
  static Map<String, dynamic> emptyStats() => <String, dynamic>{
    'source': 'none',
    'clockUs': 0,
    'timestampsUs': Int64List(0),
    'durationsUs': Int64List(0),
  };

  /// Merges the display thread's drain with this isolate's into one series.
  ///
  /// Which side draws is decided at pacing time and can flip mid-scenario
  /// (pulses going stale hands drawing back to the isolate), so a drain must
  /// return BOTH sides' samples or silently lose one. The two share a clock
  /// epoch by construction, so merging is a sort; `source` says who drew
  /// (`displayThread`, `isolate`, or `mixed` after a flip).
  static Map<String, dynamic> mergeStats(
    Map<String, dynamic>? a,
    Map<String, dynamic>? b,
  ) {
    bool hasSamples(Map<String, dynamic>? stats) =>
        stats != null && (stats['timestampsUs'] as Int64List).isNotEmpty;
    if (!hasSamples(a)) return hasSamples(b) ? b! : (a ?? b ?? emptyStats());
    if (!hasSamples(b)) return a!;

    final pairs = <(int, int)>[
      for (var i = 0; i < (a!['timestampsUs'] as Int64List).length; i++)
        ((a['timestampsUs'] as Int64List)[i], (a['durationsUs'] as Int64List)[i]),
      for (var i = 0; i < (b!['timestampsUs'] as Int64List).length; i++)
        ((b['timestampsUs'] as Int64List)[i], (b['durationsUs'] as Int64List)[i]),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    final aClock = a['clockUs'] as int;
    final bClock = b['clockUs'] as int;
    return <String, dynamic>{
      'source': 'mixed',
      'clockUs': aClock > bClock ? aClock : bClock,
      'timestampsUs': Int64List.fromList([for (final p in pairs) p.$1]),
      'durationsUs': Int64List.fromList([for (final p in pairs) p.$2]),
    };
  }
}
