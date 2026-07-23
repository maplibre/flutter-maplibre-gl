import 'dart:typed_data';

/// Per-frame render statistics collection (benchmark instrumentation) for
/// one engine session.
///
/// Armed by `SetFrameStatsEnabledCommand` and drained by
/// `TakeFrameStatsQuery`. It lives in the engine core so both hosts (the
/// single-isolate widget ticker and the isolate frame driver) measure the
/// exact same code path.
class FrameStatsCollector {
  FrameStatsCollector();

  final Stopwatch _clock = Stopwatch()..start();
  final List<int> _timestampsUs = <int>[];
  final List<int> _durationsUs = <int>[];

  /// Runs [render] recording its start time and wall duration (CPU command
  /// encoding + submit; GPU completion is not observable from here).
  void measure(void Function() render) {
    final startUs = _clock.elapsedMicroseconds;
    render();
    _timestampsUs.add(startUs);
    _durationsUs.add(_clock.elapsedMicroseconds - startUs);
  }

  /// Drains the collected samples without stopping the collection.
  Map<String, dynamic> take() {
    final stats = <String, dynamic>{
      'clockUs': _clock.elapsedMicroseconds,
      'timestampsUs': Int64List.fromList(_timestampsUs),
      'durationsUs': Int64List.fromList(_durationsUs),
    };
    _timestampsUs.clear();
    _durationsUs.clear();
    return stats;
  }

  /// The shape [take] would reply with when collection was never armed.
  static Map<String, dynamic> emptyStats() => <String, dynamic>{
    'clockUs': 0,
    'timestampsUs': Int64List(0),
    'durationsUs': Int64List(0),
  };
}
