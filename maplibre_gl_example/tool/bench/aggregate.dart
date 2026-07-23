// Benchmark aggregator: turns the per-run JSON files produced by
// run_bench.dart into a comparison report.
//
//   dart run tool/bench/aggregate.dart <results-dir>
//
// Skips warm-up runs and runs whose engine transport mismatched. For every
// scenario phase it reports, per engine (averaged across iterations):
// Flutter frame stats (fps, p50/p90/p99 total span, jank rates, worst-1%
// mean), engine render stats (fps, p50/p99 render duration), API latency
// percentiles, counters, and memory peaks, plus the percent delta of every
// FFI variant against the stable baseline.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// Frame budgets of the 90 Hz target device (Xiaomi 11 Lite 5G NE) and the
// universal 60 Hz reference.
const double budget90Ms = 1000 / 90;
const double budget60Ms = 1000 / 60;

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/bench/aggregate.dart <results-dir>');
    exit(2);
  }
  final dir = Directory(args.first);
  final runs = <Map<String, dynamic>>[];
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json') ||
        file.path.endsWith('index.json') ||
        file.path.endsWith('summary.json')) {
      continue;
    }
    final run = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final host = (run['host'] as Map?)?.cast<String, dynamic>();
    if (host == null || host['outcome'] != 'ok' || host['warmup'] == true) {
      continue;
    }
    runs.add(run);
  }
  if (runs.isEmpty) {
    stderr.writeln('no valid measured runs in ${dir.path}');
    exit(1);
  }

  // scenario -> phase -> engine -> per-iteration metric maps.
  final table =
      <String, Map<String, Map<String, List<Map<String, num>>>>>{};
  final meta = <String, Map<String, dynamic>>{};
  for (final run in runs) {
    final host = (run['host'] as Map).cast<String, dynamic>();
    final engine = host['engine'] as String;
    final scenario = host['scenario'] as String;
    meta[engine] = (run['metadata'] as Map).cast<String, dynamic>();
    for (final entry in _analyzeRun(run).entries) {
      table
          .putIfAbsent(scenario, () => {})
          .putIfAbsent(entry.key, () => {})
          .putIfAbsent(engine, () => [])
          .add(entry.value);
    }
  }

  final engines = [
    for (final engine in const ['stable', 'ffi', 'ffi_isolate'])
      if (meta.containsKey(engine)) engine,
  ]; // 'ffi' only appears in pre-consolidation result sets.
  final report = _renderReport(table, engines, meta, runs.length);
  File('${dir.path}/report.md').writeAsStringSync(report);
  File('${dir.path}/summary.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'runs': runs.length,
      'engines': engines,
      'scenarios': {
        for (final scenario in table.entries)
          scenario.key: {
            for (final phase in scenario.value.entries)
              phase.key: {
                for (final engine in phase.value.entries)
                  engine.key: _averageIterations(engine.value),
              },
          },
      },
    }),
  );
  stdout.writeln(report);
}

// --- Per-run analysis ----------------------------------------------------------

/// Computes metric maps per phase (plus a synthetic `_run` phase with marks,
/// latencies, counters, and memory).
Map<String, Map<String, num>> _analyzeRun(Map<String, dynamic> run) {
  final out = <String, Map<String, num>>{};
  final frames = (run['flutterFrames'] as Map).cast<String, dynamic>();
  final vsync = (frames['vsyncStartUs'] as List).cast<num>();
  final build = (frames['buildUs'] as List).cast<num>();
  final raster = (frames['rasterUs'] as List).cast<num>();
  final span = (frames['totalSpanUs'] as List).cast<num>();

  for (final rawPhase in run['phases'] as List) {
    final phase = (rawPhase as Map).cast<String, dynamic>();
    final name = phase['name'] as String;
    final startUs = phase['startUs'] as num;
    final endUs = (phase['endUs'] as num?) ?? startUs;
    final durationS = (endUs - startUs) / 1e6;
    if (durationS <= 0) continue;
    final metrics = <String, num>{'phase_s': durationS};

    // Flutter frames whose vsync falls inside the phase (both timestamp
    // sources use the Dart timeline clock).
    final spans = <num>[];
    final builds = <num>[];
    final rasters = <num>[];
    for (var i = 0; i < vsync.length; i++) {
      if (vsync[i] >= startUs && vsync[i] < endUs) {
        spans.add(span[i]);
        builds.add(build[i]);
        rasters.add(raster[i]);
      }
    }
    if (spans.isNotEmpty) {
      metrics
        ..['ui_fps'] = spans.length / durationS
        ..['ui_span_p50_ms'] = _percentile(spans, 50) / 1000
        ..['ui_span_p90_ms'] = _percentile(spans, 90) / 1000
        ..['ui_span_p99_ms'] = _percentile(spans, 99) / 1000
        ..['ui_span_low1p_ms'] = _worstMean(spans, 0.01) / 1000
        ..['ui_build_p90_ms'] = _percentile(builds, 90) / 1000
        ..['ui_raster_p90_ms'] = _percentile(rasters, 90) / 1000
        ..['ui_jank90hz_pct'] =
            spans.where((s) => s / 1000 > budget90Ms).length /
            spans.length *
            100
        ..['ui_jank60hz_pct'] =
            spans.where((s) => s / 1000 > budget60Ms).length /
            spans.length *
            100;
    }

    final engineStats = (phase['engineStats'] as Map?)?.cast<String, dynamic>();
    if (engineStats != null) {
      final timestamps = (engineStats['timestampsUs'] as List?)?.cast<num>();
      if (timestamps != null && timestamps.length > 1) {
        final spanS =
            (timestamps.last - timestamps.first).toDouble() / 1e6;
        if (spanS > 0) metrics['map_fps'] = (timestamps.length - 1) / spanS;
        // FFI reports renderUpdate wall time; the stable SDK reports the
        // encoding+rendering split. Normalize to one "render cost" series.
        final durations = (engineStats['durationsUs'] as List?)?.cast<num>();
        final renderMs = durations != null
            ? [for (final d in durations) d / 1000]
            : _summedRenderMs(engineStats);
        if (renderMs.isNotEmpty) {
          metrics
            ..['map_render_p50_ms'] = _percentile(renderMs, 50)
            ..['map_render_p99_ms'] = _percentile(renderMs, 99)
            ..['map_render_low1p_ms'] = _worstMean(renderMs, 0.01);
        }
      }
    }
    out[name] = metrics;
  }

  // Run-scoped extras.
  final extras = <String, num>{};
  final marks = (run['marks'] as Map).cast<String, dynamic>();
  final appInit = marks['appInit'] as num?;
  if (appInit != null) {
    for (final mark in const ['mapCreated', 'styleLoaded', 'firstIdle']) {
      final value = marks[mark] as num?;
      if (value != null) extras['${mark}_ms'] = (value - appInit) / 1000;
    }
  }
  for (final entry
      in (run['latencyUs'] as Map).cast<String, dynamic>().entries) {
    final samples = (entry.value as List).cast<num>();
    if (samples.isEmpty) continue;
    extras
      ..['lat_${entry.key}_p50_ms'] = _percentile(samples, 50) / 1000
      ..['lat_${entry.key}_p99_ms'] = _percentile(samples, 99) / 1000;
  }
  for (final entry
      in (run['counters'] as Map).cast<String, dynamic>().entries) {
    extras['ctr_${entry.key}'] = entry.value as num;
  }
  final rss = (run['rssSamplesBytes'] as List).cast<num>();
  if (rss.isNotEmpty) {
    extras['rss_peak_mb'] = rss.reduce(math.max) / (1024 * 1024);
  }
  final cpu = run['cpuJiffies'] as num?;
  final startUs = run['startUs'] as num?;
  final endUs = run['endUs'] as num?;
  if (cpu != null && startUs != null && endUs != null && endUs > startUs) {
    // Jiffies are 10 ms on Android; expressed as % of one core.
    extras['cpu_avg_pct'] = cpu * 10000 / (endUs - startUs) * 100;
  }
  out['_run'] = extras;
  return out;
}

List<num> _summedRenderMs(Map<String, dynamic> engineStats) {
  final encoding = (engineStats['encodingMs'] as List?)?.cast<num>();
  final rendering = (engineStats['renderingMs'] as List?)?.cast<num>();
  if (encoding == null || rendering == null) return const [];
  return [
    for (var i = 0; i < encoding.length; i++) encoding[i] + rendering[i],
  ];
}

// --- Statistics ----------------------------------------------------------------

num _percentile(List<num> values, int p) {
  final sorted = [...values]..sort();
  final index = (p / 100 * (sorted.length - 1)).round();
  return sorted[index];
}

/// Mean of the worst [fraction] of samples (upstream's "low1p" metric).
num _worstMean(List<num> values, double fraction) {
  final sorted = [...values]..sort();
  final count = math.max(1, (sorted.length * fraction).floor());
  final worst = sorted.sublist(sorted.length - count);
  return worst.reduce((a, b) => a + b) / worst.length;
}

Map<String, num> _averageIterations(List<Map<String, num>> iterations) {
  final keys = <String>{for (final m in iterations) ...m.keys};
  return {
    for (final key in keys)
      key: _mean([
        for (final m in iterations)
          if (m[key] != null) m[key]!,
      ]),
  };
}

num _mean(List<num> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

// --- Report rendering ----------------------------------------------------------

String _renderReport(
  Map<String, Map<String, Map<String, List<Map<String, num>>>>> table,
  List<String> engines,
  Map<String, Map<String, dynamic>> meta,
  int runCount,
) {
  final buffer = StringBuffer()
    ..writeln('# flutter-maplibre-gl engine benchmark')
    ..writeln();
  final anyMeta = meta.values.first;
  buffer
    ..writeln(
      '- Device: ${anyMeta['deviceBrand']} ${anyMeta['deviceModel']} '
      '(Android API ${anyMeta['androidSdk']}, '
      '${(anyMeta['displayRefreshRate'] as num?)?.toStringAsFixed(0)} Hz)',
    )
    ..writeln(
      '- Revision: ${(anyMeta['config'] as Map)['gitRevision']}  |  '
      'profile mode: ${anyMeta['profileMode']}  |  measured runs: $runCount',
    )
    ..writeln('- Engines: ${engines.join(', ')}')
    ..writeln(
      '- Renderer caveat: the FFI engine uses the Vulkan backend of MapLibre '
      'Native, the stable engine uses OpenGL ES; deltas mix transport and '
      'renderer effects.',
    )
    ..writeln();

  for (final scenario in table.entries) {
    buffer
      ..writeln('## ${scenario.key}')
      ..writeln();
    final phases = scenario.value.keys.toList()..sort();
    for (final phaseName in phases) {
      final byEngine = scenario.value[phaseName]!;
      final metricKeys = <String>{
        for (final iterations in byEngine.values)
          for (final m in iterations) ...m.keys,
      }.toList()..sort();
      if (metricKeys.isEmpty) continue;
      buffer
        ..writeln('### ${phaseName == '_run' ? 'run-level metrics' : phaseName}')
        ..writeln();
      final header = StringBuffer('| metric |');
      final divider = StringBuffer('|---|');
      for (final engine in engines) {
        header.write(' $engine |');
        divider.write('---|');
        if (engine != 'stable') {
          header.write(' vs stable |');
          divider.write('---|');
        }
      }
      buffer
        ..writeln(header)
        ..writeln(divider);
      final averaged = {
        for (final entry in byEngine.entries)
          entry.key: _averageIterations(entry.value),
      };
      for (final key in metricKeys) {
        final row = StringBuffer('| $key |');
        final baseline = averaged['stable']?[key];
        for (final engine in engines) {
          final value = averaged[engine]?[key];
          row.write(value == null ? ' - |' : ' ${_format(value)} |');
          if (engine != 'stable') {
            if (value == null || baseline == null || baseline == 0) {
              row.write(' - |');
            } else {
              final delta = (value - baseline) / baseline * 100;
              row.write(
                ' ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% |',
              );
            }
          }
        }
        buffer.writeln(row);
      }
      buffer.writeln();
    }
  }
  return buffer.toString();
}

String _format(num value) {
  if (value == value.roundToDouble() && value.abs() < 1e6) {
    return value.round().toString();
  }
  return value.abs() >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}
