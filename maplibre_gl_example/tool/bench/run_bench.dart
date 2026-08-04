// Benchmark orchestrator: builds the bench APK once, then drives the full
// (engine x scenario x iteration) matrix on a connected Android device,
// collecting each run's results from logcat into JSON files.
//
//   dart run tool/bench/run_bench.dart --help
//
// The measurement protocol follows the MapLibre Native world-tour benchmark:
// one discarded warm-up pass over every configuration (which also fills the
// tile caches), then N recorded iterations with the engine order rotated per
// iteration, a thermal gate plus fixed cooldown between runs, and metadata
// (git revision, transport, thermal status) attached to every result file.
// docs/benchmarks/ffi-benchmarks.md explains the methodology and how to read
// the report.

import 'dart:convert';
import 'dart:io';

const String appId = 'org.maplibre.example';
const String activity = 'io.flutter.embedding.android.FlutterActivity';

String get usage => '''
Runs the engine benchmark matrix on a connected Android device.

  dart run tool/bench/run_bench.dart [options]

What to run:
  --engines a,b            engine variants (default: ${allEngines.join(',')})
  --scenarios a,b          scenario subset (default: all, see below)
  --iterations N           measured iterations per pair (default: 3)
  --only e:s:i,e:s:i       run exactly these engine:scenario:iteration tuples
                           (hole filling: no warm-up, appends to an existing
                           results dir passed with --out)
  --no-warmup              skip the discarded cache-warming pass
  --online                 keep the network on during measured runs
                           (default: offline, served from the warmed cache)

Device and pacing:
  --serial S               adb device serial (default: the only one connected)
  --cooldown S             seconds between runs (default: 60)
  --thermal-max N          highest thermal status allowed to start (default: 1)
  --leg-ms MS              world-tour: duration of one fly-to leg (default: 20000)
  --step-s S               duration of one measured step (default: 10)
  --style URL              style to load (default: OpenFreeMap Liberty)

Output and dry runs:
  --out DIR                results dir (default: build/bench_results/<timestamp>)
  --skip-build             reuse the APK already built and installed
  --dry-run                print the matrix, the run count and the estimate,
                           then exit without touching the device
  -h, --help               this message

Scenarios: ${allScenarios.join(', ')}

Results land in the output dir: one JSON per run, plus report.md and
summary.json written by tool/bench/aggregate.dart. A full default matrix is
${allEngines.length * allScenarios.length * 3} measured runs and takes a few hours; start with
  --engines ${allEngines.join(',')} --scenarios gestures --iterations 1 --no-warmup
to check the setup end to end in a few minutes.''';

const List<String> allEngines = ['stable', 'ffi'];
const List<String> allScenarios = [
  'style_load',
  'world_tour',
  'tracking',
  'gestures',
  'stress_ramp',
  'dynamic_data',
  'api_latency',
];

late String adbSerial;
late Directory exampleDir;

/// Rough wall time of one run at default pacing, excluding the cooldown, used
/// only for the up-front estimate. The progress line replaces it with a
/// measured average as soon as the first run completes.
const int typicalRunSeconds = 120;

final Stopwatch suiteClock = Stopwatch();
int runsPlanned = 0;
int runsStarted = 0;

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    print(usage);
    return;
  }
  final _Options opts;
  try {
    opts = _Options.parse(args);
  } on UsageException catch (error) {
    stderr.writeln('${error.message}\n');
    stderr.writeln(usage);
    exit(2);
  }
  exampleDir = _findExampleDir();

  final warmupRuns =
      opts.only.isEmpty && opts.warmup
          ? opts.engines.length * opts.scenarios.length
          : 0;
  final measuredRuns =
      opts.only.isEmpty
          ? opts.engines.length * opts.scenarios.length * opts.iterations
          : opts.only.length;
  runsPlanned = warmupRuns + measuredRuns;
  // Warm-up runs use the capped cooldown, like _executeRun does.
  final warmupCooldown = opts.cooldown < 10 ? opts.cooldown : 10;
  final estimate = Duration(
    seconds:
        measuredRuns * (typicalRunSeconds + opts.cooldown) +
        warmupRuns * (typicalRunSeconds + warmupCooldown),
  );

  print('== flutter-maplibre-gl benchmark ==');
  print('engines:   ${opts.engines.join(', ')}');
  print('scenarios: ${opts.scenarios.join(', ')}');
  final pairs = opts.engines.length * opts.scenarios.length;
  print(
    'runs:      $runsPlanned total = $measuredRuns measured'
    '${opts.only.isEmpty ? ' ($pairs pairs x ${opts.iterations} iterations)' : ''}'
    '${warmupRuns > 0 ? ' + $warmupRuns warm-up' : ''}',
  );
  print(
    'estimate:  ~${_formatDuration(estimate)} (rough; each run then reports '
    'the remaining time from the measured average)',
  );
  print(
    'network:   ${opts.online ? 'online' : 'offline (needs a warmed cache)'}',
  );
  if (opts.dryRun) {
    print('\ndry run: nothing was built, installed, or measured.');
    return;
  }

  adbSerial = opts.serial ?? await _defaultSerial();
  final outDir = Directory(opts.outPath ?? _defaultOutPath())
    ..createSync(recursive: true);
  final rev = await _gitRevision();
  print('device:    $adbSerial  rev: $rev');
  print('results:   ${outDir.path}');
  suiteClock.start();

  if (!opts.skipBuild) {
    await _buildAndInstall();
  }
  await _prepareDevice();

  final runs = <Map<String, dynamic>>[];

  if (opts.only.isNotEmpty) {
    // Hole-filling mode: exactly the requested engine:scenario:iteration
    // tuples, no warm-up (caches are assumed warm from the original suite).
    for (final spec in opts.only) {
      final parts = spec.split(':');
      runs.add(
        await _executeRun(
          outDir: outDir,
          engine: parts[0],
          scenario: parts[1],
          iteration: int.parse(parts[2]),
          warmup: false,
          offline: !opts.online,
          opts: opts,
          rev: rev,
          legMs: opts.legMs,
          stepSeconds: opts.stepSeconds,
        ),
      );
    }
    await _retryFailed(runs, outDir, opts, rev);
    await _finish(outDir, runs, appendIndex: true);
    return;
  }

  if (opts.warmup) {
    print('\n-- warm-up pass (online, discarded) --');
    for (final engine in opts.engines) {
      for (final scenario in opts.scenarios) {
        runs.add(
          await _executeRun(
            outDir: outDir,
            engine: engine,
            scenario: scenario,
            iteration: 0,
            warmup: true,
            offline: false,
            opts: opts,
            rev: rev,
            // Short pacing: the warm-up only needs to touch every tile the
            // measured camera paths will visit.
            legMs: 8000,
            stepSeconds: opts.stepSeconds < 6 ? opts.stepSeconds : 6,
          ),
        );
      }
    }
  }

  for (var iteration = 1; iteration <= opts.iterations; iteration++) {
    print('\n-- iteration $iteration/${opts.iterations} --');
    // Rotate the engine order so no variant always runs on the coolest or
    // hottest device state.
    final rotated = [
      for (var i = 0; i < opts.engines.length; i++)
        opts.engines[(i + iteration - 1) % opts.engines.length],
    ];
    for (final engine in rotated) {
      for (final scenario in opts.scenarios) {
        runs.add(
          await _executeRun(
            outDir: outDir,
            engine: engine,
            scenario: scenario,
            iteration: iteration,
            warmup: false,
            offline: !opts.online,
            opts: opts,
            rev: rev,
            legMs: opts.legMs,
            stepSeconds: opts.stepSeconds,
          ),
        );
      }
    }
  }

  await _retryFailed(runs, outDir, opts, rev);
  await _finish(outDir, runs);
}

/// One automatic retry for every failed measured run (transient wedges,
/// e.g. a stuck export, should not leave holes in the matrix).
Future<void> _retryFailed(
  List<Map<String, dynamic>> runs,
  Directory outDir,
  _Options opts,
  String rev,
) async {
  final failed = [
    for (final run in runs)
      if (run['warmup'] != true && run['outcome'] != 'ok') run,
  ];
  if (failed.isEmpty) return;
  runsPlanned += failed.length;
  print('\n-- retrying ${failed.length} failed run(s) --');
  for (final run in failed) {
    final retried = await _executeRun(
      outDir: outDir,
      engine: run['engine'] as String,
      scenario: run['scenario'] as String,
      iteration: run['iteration'] as int,
      warmup: false,
      offline: run['offline'] as bool,
      opts: opts,
      rev: rev,
      legMs: opts.legMs,
      stepSeconds: opts.stepSeconds,
    );
    runs[runs.indexOf(run)] = retried;
  }
}

Future<void> _finish(
  Directory outDir,
  List<Map<String, dynamic>> runs, {
  bool appendIndex = false,
}) async {
  final indexFile = File('${outDir.path}/index.json');
  var all = runs;
  if (appendIndex && indexFile.existsSync()) {
    final previous =
        (jsonDecode(indexFile.readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    // Replace superseded entries of rerun ids, keep the rest.
    final rerunIds = {for (final run in runs) run['runId']};
    all = [
      for (final run in previous)
        if (!rerunIds.contains(run['runId'])) run,
      ...runs,
    ];
  }
  indexFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(all));
  await _restoreDevice();

  print('\nAggregating...');
  final aggregate = await Process.run(Platform.resolvedExecutable, [
    'run',
    'tool/bench/aggregate.dart',
    outDir.path,
  ], workingDirectory: exampleDir.path);
  stdout.write(aggregate.stdout);
  stderr.write(aggregate.stderr);
  print('Done. Report: ${outDir.path}/report.md');
}

// --- Run execution -----------------------------------------------------------

bool _firstRun = true;

Future<Map<String, dynamic>> _executeRun({
  required Directory outDir,
  required String engine,
  required String scenario,
  required int iteration,
  required bool warmup,
  required bool offline,
  required _Options opts,
  required String rev,
  required int legMs,
  required int stepSeconds,
}) async {
  final runId = '$engine-$scenario-i$iteration${warmup ? 'w' : ''}';
  // Warm-up runs are discarded, so they only need a token cooldown.
  final cooldown =
      warmup ? (opts.cooldown < 10 ? opts.cooldown : 10) : opts.cooldown;
  if (!_firstRun && cooldown > 0) {
    print('  cooldown $cooldown s...');
    await Future<void>.delayed(Duration(seconds: cooldown));
  }
  _firstRun = false;
  final thermalBefore = await _waitForThermal(opts.thermalMax);
  final route =
      '/bench?engine=$engine&scenario=$scenario&run=$runId'
      '&offline=${offline ? 1 : 0}&warmup=${warmup ? 1 : 0}'
      '&iteration=$iteration&leg_ms=$legMs&step_s=$stepSeconds&rev=$rev'
      '${opts.styleUrl == null ? '' : '&style=${Uri.encodeQueryComponent(opts.styleUrl!)}'}';

  await _wakeScreen();
  if (!await _screenAwake()) {
    print('[$runId] SKIPPED: screen is off and would not wake');
    return <String, dynamic>{
      'runId': runId,
      'engine': engine,
      'scenario': scenario,
      'iteration': iteration,
      'warmup': warmup,
      'offline': offline,
      'outcome': 'screen-off',
    };
  }
  runsStarted++;
  print('[$runsStarted/$runsPlanned] $runId thermal=$thermalBefore${_eta()}');
  await _adb(['logcat', '-c']);
  // -S force-stops any previous instance so every run is a cold start; the
  // route extra carries the whole configuration.
  await _adbShell("am start -S -W -n $appId/$activity --es route '$route'");

  final timeout = _runTimeout(scenario, legMs, stepSeconds);
  final deadline = DateTime.now().add(timeout);
  String? outcome;
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(seconds: 3));
    final dump = await _logcatDump();
    final done = RegExp(
      '^BENCH_DONE:$runId:(.*)\$',
      multiLine: true,
    ).firstMatch(dump);
    if (done != null) {
      outcome = done.group(1);
      break;
    }
  }
  outcome ??= 'timeout after ${timeout.inSeconds}s';

  final dump = await _logcatDump();
  final thermalAfter = await _thermalStatus();
  await _adbShell('am force-stop $appId');

  final record = <String, dynamic>{
    'runId': runId,
    'engine': engine,
    'scenario': scenario,
    'iteration': iteration,
    'warmup': warmup,
    'offline': offline,
    'outcome': outcome,
    'thermalBefore': thermalBefore,
    'thermalAfter': thermalAfter,
  };

  if (outcome != 'ok') {
    print('[$runId] FAILED: $outcome');
    File('${outDir.path}/$runId.log').writeAsStringSync(dump);
    return record;
  }

  try {
    final result = _decodeExport(dump, runId);
    result['host'] = record;
    final transport = (result['metadata'] as Map)['engineTransport'];
    final expected = switch (engine) {
      'ffi' => 'isolate',
      _ => 'platform-view',
    };
    if (transport != expected) {
      record['outcome'] =
          'transport-mismatch: expected $expected, ran $transport';
      print('[$runId] TRANSPORT MISMATCH: $transport (expected $expected)');
    }
    final frames = ((result['flutterFrames'] as Map)['buildUs'] as List).length;
    // A paused/blanked activity produces a handful of frames at most; such
    // a run measured nothing and must not enter the aggregate.
    if (frames < 30 && record['outcome'] == 'ok') {
      record['outcome'] = 'too-few-frames:$frames';
      print('[$runId] REJECTED: only $frames flutter frames (screen off?)');
    }
    File('${outDir.path}/$runId.json').writeAsStringSync(jsonEncode(result));
    if (record['outcome'] == 'ok') {
      print('[$runId] ok, $frames flutter frames, thermal $thermalAfter');
    }
  } on Exception catch (error) {
    record['outcome'] = 'export-decode-failed: $error';
    File('${outDir.path}/$runId.log').writeAsStringSync(dump);
    print('[$runId] export decode FAILED: $error');
  }
  return record;
}

/// Reassembles and unpacks the gzip+base64 chunked export of one run.
Map<String, dynamic> _decodeExport(String dump, String runId) {
  final begin = RegExp(
    '^BENCHV1:BEGIN:$runId:(\\d+):(\\d+)\\s*\$',
    multiLine: true,
  ).firstMatch(dump);
  if (begin == null) throw const FormatException('no BENCHV1 BEGIN marker');
  final expected = int.parse(begin.group(1)!);
  final totalLength = int.parse(begin.group(2)!);
  final chunks = <int, String>{};
  for (final match in RegExp(
    '^BENCHV1:CHUNK:$runId:(\\d+):([A-Za-z0-9+/=]*)',
    multiLine: true,
  ).allMatches(dump)) {
    chunks[int.parse(match.group(1)!)] = match.group(2)!;
  }
  final encoded = StringBuffer();
  for (var i = 0; i < expected; i++) {
    final chunk = chunks[i];
    if (chunk == null) throw FormatException('missing chunk $i/$expected');
    encoded.write(chunk);
  }
  if (encoded.length != totalLength) {
    throw FormatException(
      'payload length mismatch: got ${encoded.length}, expected $totalLength '
      '(truncated logcat line?)',
    );
  }
  final bytes = gzip.decode(base64Decode(encoded.toString()));
  return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
}

Duration _runTimeout(String scenario, int legMs, int stepSeconds) {
  final seconds = switch (scenario) {
    'style_load' => 150,
    'world_tour' => 4 * legMs ~/ 1000 + 120,
    'tracking' => 3 * stepSeconds + 120,
    'gestures' => 240,
    'stress_ramp' => 6 * (stepSeconds + 8) + 180,
    'dynamic_data' => 3 * stepSeconds + 180,
    'api_latency' => 400,
    _ => 300,
  };
  return Duration(seconds: (seconds * 1.5).round());
}

// --- Device management -------------------------------------------------------

Future<void> _buildAndInstall() async {
  print('\nBuilding profile APK (lib/main_bench.dart)...');
  final build = await Process.run('flutter', [
    'build',
    'apk',
    '--profile',
    '-t',
    'lib/main_bench.dart',
  ], workingDirectory: exampleDir.path);
  if (build.exitCode != 0) {
    stderr.write(build.stdout);
    stderr.write(build.stderr);
    throw Exception('flutter build failed');
  }
  final apk = File(
    '${exampleDir.path}/build/app/outputs/flutter-apk/app-profile.apk',
  );
  print('Installing ${apk.path}...');
  await _adb(['install', '-r', '-d', apk.path], check: true);
}

String? _previousScreenTimeout;

Future<void> _prepareDevice() async {
  // Bigger logcat buffer: one run's chunked export must survive until the
  // final dump.
  await _adb(['logcat', '-G', '16M']);
  // Belt and braces against OEM power management (MIUI turned the screen
  // off mid-suite despite stayon): keep-awake on any power source AND a
  // 30-minute screen timeout, restored at the end of the suite. A paused
  // activity renders no frames, which silently voids a run.
  await _adbShell('svc power stayon true');
  _previousScreenTimeout =
      (await _adbShell('settings get system screen_off_timeout')).trim();
  await _adbShell('settings put system screen_off_timeout 1800000');
  await _wakeScreen();
}

Future<void> _restoreDevice() async {
  await _adbShell('svc power stayon false');
  final timeout = _previousScreenTimeout;
  if (timeout != null && int.tryParse(timeout) != null) {
    await _adbShell('settings put system screen_off_timeout $timeout');
  }
  await _adbShell('am force-stop $appId');
}

Future<void> _wakeScreen() async {
  await _adbShell('input keyevent KEYCODE_WAKEUP');
  await _adbShell('wm dismiss-keyguard');
  await Future<void>.delayed(const Duration(seconds: 1));
}

Future<bool> _screenAwake() async {
  final out = await _adbShell('dumpsys power');
  return out.contains('mWakefulness=Awake');
}

Future<int> _thermalStatus() async {
  final out = await _adbShell('dumpsys thermalservice');
  final match = RegExp(r'Thermal Status:\s*(\d+)').firstMatch(out);
  return match == null ? -1 : int.parse(match.group(1)!);
}

/// Cooldown plus thermal gate: waits until the device reports a thermal
/// status at or below [maxStatus] (NONE=0, LIGHT=1, MODERATE=2...).
Future<int> _waitForThermal(int maxStatus) async {
  final deadline = DateTime.now().add(const Duration(minutes: 12));
  var status = await _thermalStatus();
  while (status > maxStatus && DateTime.now().isBefore(deadline)) {
    print('  thermal status $status > $maxStatus, cooling down 30 s...');
    await Future<void>.delayed(const Duration(seconds: 30));
    status = await _thermalStatus();
  }
  return status;
}

Future<String> _logcatDump() async {
  final result = await Process.run('adb', [
    '-s',
    adbSerial,
    'logcat',
    '-d',
    '-v',
    'raw',
    '-s',
    'flutter:I',
  ]);
  return result.stdout as String;
}

Future<String> _adbShell(String command) async {
  final result = await Process.run('adb', ['-s', adbSerial, 'shell', command]);
  return result.stdout as String;
}

Future<void> _adb(List<String> args, {bool check = false}) async {
  final result = await Process.run('adb', ['-s', adbSerial, ...args]);
  if (check && result.exitCode != 0) {
    throw Exception('adb ${args.join(' ')} failed: ${result.stderr}');
  }
}

Future<String> _defaultSerial() async {
  final result = await Process.run('adb', ['devices']);
  final devices = [
    for (final line in (result.stdout as String).split('\n'))
      if (line.trim().endsWith('device') && !line.startsWith('List'))
        line.split(RegExp(r'\s+')).first,
  ];
  if (devices.isEmpty) throw Exception('no adb device connected');
  if (devices.length > 1) {
    throw Exception('multiple devices, pass --serial: $devices');
  }
  return devices.first;
}

Future<String> _gitRevision() async {
  final result = await Process.run('git', [
    'rev-parse',
    '--short',
    'HEAD',
  ], workingDirectory: exampleDir.path);
  return (result.stdout as String).trim();
}

Directory _findExampleDir() {
  // tool/bench/run_bench.dart lives inside the example package.
  final script = File.fromUri(Platform.script).absolute;
  return script.parent.parent.parent;
}

String _defaultOutPath() {
  final ts =
      DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
  return '${exampleDir.path}/build/bench_results/$ts';
}

// --- Options -----------------------------------------------------------------

/// A bad command line: reported with the usage text instead of a stack trace.
class UsageException implements Exception {
  UsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _Options {
  _Options({
    required this.engines,
    required this.scenarios,
    required this.iterations,
    required this.warmup,
    required this.online,
    required this.skipBuild,
    required this.cooldown,
    required this.thermalMax,
    required this.legMs,
    required this.stepSeconds,
    required this.serial,
    required this.outPath,
    required this.styleUrl,
    required this.only,
    required this.dryRun,
  });

  /// Options that take a value, and boolean switches. Listed so that a typo
  /// ("--iteration 1") is an error instead of a silently ignored argument that
  /// would quietly run the full three-hour default matrix.
  static const _valueOptions = <String>{
    'engines',
    'scenarios',
    'iterations',
    'only',
    'serial',
    'cooldown',
    'thermal-max',
    'leg-ms',
    'step-s',
    'style',
    'out',
  };
  static const _switches = <String>{
    'no-warmup',
    'online',
    'skip-build',
    'dry-run',
    'help',
  };

  factory _Options.parse(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (!arg.startsWith('--')) {
        throw UsageException('unexpected argument "$arg"');
      }
      final name = arg.substring(2);
      if (_valueOptions.contains(name)) {
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          throw UsageException('--$name needs a value');
        }
        i++;
      } else if (!_switches.contains(name)) {
        throw UsageException('unknown option "$arg"');
      }
    }

    String? value(String name) {
      final index = args.indexOf('--$name');
      return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
    }

    bool flag(String name) => args.contains('--$name');

    int number(String name, String fallback) {
      final raw = value(name) ?? fallback;
      final parsed = int.tryParse(raw);
      if (parsed == null) {
        throw UsageException('--$name expects a number, got "$raw"');
      }
      return parsed;
    }

    final engines = value('engines')?.split(',') ?? allEngines;
    final scenarios = value('scenarios')?.split(',') ?? allScenarios;
    for (final engine in engines) {
      if (!allEngines.contains(engine)) {
        throw UsageException(
          'unknown engine "$engine"; available: ${allEngines.join(', ')}',
        );
      }
    }
    for (final scenario in scenarios) {
      if (!allScenarios.contains(scenario)) {
        throw UsageException(
          'unknown scenario "$scenario"; available: '
          '${allScenarios.join(', ')}',
        );
      }
    }
    final only = value('only')?.split(',') ?? const <String>[];
    for (final spec in only) {
      final parts = spec.split(':');
      if (parts.length != 3 ||
          !allEngines.contains(parts[0]) ||
          !allScenarios.contains(parts[1]) ||
          int.tryParse(parts[2]) == null) {
        throw UsageException(
          '--only expects engine:scenario:iteration, got "$spec"',
        );
      }
    }
    return _Options(
      engines: engines,
      scenarios: scenarios,
      iterations: number('iterations', '3'),
      warmup: !flag('no-warmup'),
      online: flag('online'),
      skipBuild: flag('skip-build'),
      cooldown: number('cooldown', '60'),
      thermalMax: number('thermal-max', '1'),
      legMs: number('leg-ms', '20000'),
      stepSeconds: number('step-s', '10'),
      serial: value('serial'),
      outPath: value('out'),
      styleUrl: value('style'),
      only: only,
      dryRun: flag('dry-run'),
    );
  }

  final List<String> engines;
  final List<String> scenarios;
  final int iterations;
  final bool warmup;
  final bool online;
  final bool skipBuild;
  final int cooldown;
  final int thermalMax;
  final int legMs;
  final int stepSeconds;
  final String? serial;
  final String? outPath;
  final String? styleUrl;

  /// Hole-filling reruns: engine:scenario:iteration tuples.
  final List<String> only;

  /// Print what would run, then exit without touching the device.
  final bool dryRun;
}

/// Elapsed time and remaining estimate for the run about to start, based on
/// the average of the runs already done (so it self-corrects; empty for the
/// first run, which has nothing to average yet).
String _eta() {
  final done = runsStarted - 1;
  if (done <= 0 || !suiteClock.isRunning) return '';
  final perRun = suiteClock.elapsed ~/ done;
  final remaining = perRun * (runsPlanned - done);
  return ', elapsed ${_formatDuration(suiteClock.elapsed)}'
      ', left ~${_formatDuration(remaining)}';
}

/// `1 h 47 m` / `12 m 30 s`, for estimates and elapsed times.
String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours > 0) return '$hours h $minutes m';
  return '$minutes m ${duration.inSeconds % 60} s';
}
