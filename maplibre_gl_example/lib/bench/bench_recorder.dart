/// Measurement collection for one benchmark run.
///
/// Collects three signal layers:
/// - Flutter frame timings ([SchedulerBinding.addTimingsCallback]): what the
///   UI isolate and raster thread actually spent per frame;
/// - engine frame stats drained per phase from the map backend
///   (`controller.takeFrameStats()`): what the map renderer spent per frame;
/// - process counters (RSS, CPU jiffies) sampled around the run.
///
/// Results leave the device as gzip+base64 chunks on logcat (see [export]),
/// so no storage permissions or run-as access are needed on a profile build.
library;

import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:io';
import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';

class BenchPhase {
  BenchPhase(this.name, this.startUs);

  final String name;
  final int startUs;
  int? endUs;
  Map<String, dynamic>? engineStats;

  Map<String, dynamic> toJson() => {
    'name': name,
    'startUs': startUs,
    'endUs': endUs,
    'engineStats':
        engineStats == null
            ? null
            : {
              for (final entry in engineStats!.entries)
                entry.key:
                    entry.value is List
                        ? List<num>.from(entry.value as List)
                        : entry.value,
            },
  };
}

class BenchRecorder {
  BenchRecorder();

  // Flutter frame timings, on the Timeline.now clock.
  final List<int> _vsyncStartUs = <int>[];
  final List<int> _buildUs = <int>[];
  final List<int> _rasterUs = <int>[];
  final List<int> _totalSpanUs = <int>[];

  final List<BenchPhase> phases = <BenchPhase>[];
  final Map<String, int> marks = <String, int>{};
  final Map<String, List<int>> latencySeries = <String, List<int>>{};
  final Map<String, num> counters = <String, num>{};

  final List<int> _rssSamplesBytes = <int>[];
  TimingsCallback? _timingsCallback;
  int? _startUs;
  int? _cpuJiffiesStart;

  /// Timestamp on the same clock as the recorded frame timings.
  int get nowUs => Timeline.now;

  void start() {
    if (_timingsCallback != null) return;
    _startUs = nowUs;
    _cpuJiffiesStart = _readOwnCpuJiffies();
    _timingsCallback = (timings) {
      for (final t in timings) {
        _vsyncStartUs.add(t.timestampInMicroseconds(FramePhase.vsyncStart));
        _buildUs.add(t.buildDuration.inMicroseconds);
        _rasterUs.add(t.rasterDuration.inMicroseconds);
        _totalSpanUs.add(t.totalSpan.inMicroseconds);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  void stop() {
    final callback = _timingsCallback;
    if (callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
      _timingsCallback = null;
    }
  }

  void mark(String name) => marks[name] = nowUs;

  void count(String name, num value) => counters[name] = value;

  void recordLatency(String series, int micros) =>
      latencySeries.putIfAbsent(series, () => <int>[]).add(micros);

  BenchPhase startPhase(String name) {
    final phase = BenchPhase(name, nowUs);
    phases.add(phase);
    return phase;
  }

  void endPhase(BenchPhase phase, {Map<String, dynamic>? engineStats}) {
    phase.endUs = nowUs;
    phase.engineStats = engineStats;
  }

  void sampleRss() => _rssSamplesBytes.add(ProcessInfo.currentRss);

  /// utime+stime of this process in clock ticks, from /proc/self/stat.
  int? _readOwnCpuJiffies() {
    try {
      final stat = File('/proc/self/stat').readAsStringSync();
      // Fields after the parenthesized comm; utime and stime are fields 14
      // and 15 of the full line (1-based).
      final tail = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
      return int.parse(tail[11]) + int.parse(tail[12]);
    } on Exception {
      return null;
    }
  }

  Map<String, dynamic> toJson(Map<String, dynamic> metadata) {
    final cpuStart = _cpuJiffiesStart;
    final cpuEnd = _readOwnCpuJiffies();
    return {
      'metadata': metadata,
      'startUs': _startUs,
      'endUs': nowUs,
      'cpuJiffies':
          cpuStart == null || cpuEnd == null ? null : cpuEnd - cpuStart,
      'rssSamplesBytes': _rssSamplesBytes,
      'maxRssBytes': ProcessInfo.maxRss,
      'marks': marks,
      'counters': counters,
      'latencyUs': latencySeries,
      'phases': [for (final phase in phases) phase.toJson()],
      'flutterFrames': {
        'vsyncStartUs': _vsyncStartUs,
        'buildUs': _buildUs,
        'rasterUs': _rasterUs,
        'totalSpanUs': _totalSpanUs,
      },
    };
  }

  /// Prints the result JSON to logcat as gzip+base64 chunks framed by
  /// BEGIN/END markers the orchestrator reassembles.
  Future<void> export(String runId, Map<String, dynamic> metadata) async {
    final bytes = gzip.encode(utf8.encode(jsonEncode(toJson(metadata))));
    final encoded = base64Encode(bytes);
    // Android splits log lines around 1 KB; stay well below so a chunk is
    // never truncated. The BEGIN marker carries the total payload length so
    // the orchestrator can verify the reassembly.
    const chunkSize = 700;
    final chunkCount = (encoded.length + chunkSize - 1) ~/ chunkSize;
    // print (not debugPrint): debugPrint throttles output and the tail of a
    // large payload would be dropped by the orchestrator's timeout.
    print('BENCHV1:BEGIN:$runId:$chunkCount:${encoded.length}');
    for (var i = 0; i < chunkCount; i++) {
      final end = (i + 1) * chunkSize;
      print(
        'BENCHV1:CHUNK:$runId:$i:'
        '${encoded.substring(i * chunkSize, end > encoded.length ? encoded.length : end)}',
      );
      // Pace the dump to ~300 lines/s: an unthrottled burst wedged the
      // stdout-to-logcat pipe once (process frozen mid-dump at 0% CPU) and
      // made logd drop chunks of the two largest world-tour exports
      // ("missing chunk N/M" on the host).
      await Future<void>.delayed(const Duration(milliseconds: 3));
    }
    print('BENCHV1:END:$runId');
  }
}
