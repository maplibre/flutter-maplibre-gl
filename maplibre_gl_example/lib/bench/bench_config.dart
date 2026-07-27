/// Benchmark run configuration, decoded from the initial route string.
///
/// The orchestrator launches each run with
/// `adb shell am start ... --es route '/bench?engine=...&scenario=...'` and
/// `FlutterActivity` exposes the extra as the default route, so no native
/// config channel is needed. Manual runs without a route fall back to the
/// defaults below.
library;

enum BenchEngine {
  stable('stable'),
  ffi('ffi');

  const BenchEngine(this.id);

  final String id;

  static BenchEngine parse(String? value) => values.firstWhere(
    (engine) => engine.id == value,
    orElse: () => BenchEngine.stable,
  );
}

class BenchConfig {
  const BenchConfig({
    required this.engine,
    required this.scenario,
    required this.runId,
    required this.styleUrl,
    required this.offline,
    required this.warmup,
    required this.iteration,
    required this.legMs,
    required this.stepSeconds,
    required this.stressSteps,
    required this.dynamicSteps,
    required this.apiIterations,
    required this.gitRevision,
  });

  factory BenchConfig.fromRoute(String route) {
    // The default route is "/" when no extra is passed.
    final uri = Uri.tryParse(route) ?? Uri(path: '/');
    final params = uri.queryParameters;
    List<int> intList(String key, List<int> fallback) {
      final raw = params[key];
      if (raw == null || raw.isEmpty) return fallback;
      return [for (final part in raw.split('-')) int.parse(part)];
    }

    return BenchConfig(
      engine: BenchEngine.parse(params['engine']),
      scenario: params['scenario'] ?? 'world_tour',
      runId: params['run'] ?? 'manual',
      styleUrl:
          params['style'] ?? 'https://tiles.openfreemap.org/styles/liberty',
      offline: params['offline'] == '1',
      warmup: params['warmup'] == '1',
      iteration: int.tryParse(params['iteration'] ?? '') ?? 0,
      legMs: int.tryParse(params['leg_ms'] ?? '') ?? 20000,
      stepSeconds: int.tryParse(params['step_s'] ?? '') ?? 10,
      stressSteps: intList('stress_steps', const [
        500,
        1000,
        2000,
        5000,
        10000,
        20000,
      ]),
      dynamicSteps: intList('dynamic_steps', const [500, 1000, 2000]),
      apiIterations: int.tryParse(params['api_iters'] ?? '') ?? 300,
      gitRevision: params['rev'] ?? 'unknown',
    );
  }

  final BenchEngine engine;

  /// Scenario key: style_load, world_tour, tracking, gestures, stress_ramp,
  /// dynamic_data, api_latency.
  final String scenario;

  /// Correlation id assigned by the orchestrator; tags every logcat line.
  final String runId;

  final String styleUrl;

  /// Cut the network (engine-level offline switch) before loading the style;
  /// requires a previously warmed tile cache.
  final bool offline;

  /// Warm-up run: executed and exported like any other, discarded host-side.
  final bool warmup;

  final int iteration;

  /// World-tour: duration of each fly-to leg.
  final int legMs;

  /// Duration of one measured step (orbit, tracking segment, dynamic-data
  /// stage) in seconds.
  final int stepSeconds;

  /// Feature counts of the stress ramp.
  final List<int> stressSteps;

  /// Feature counts of the dynamic-data scenario.
  final List<int> dynamicSteps;

  /// Iterations per API-latency micro-benchmark.
  final int apiIterations;

  final String gitRevision;

  Map<String, dynamic> toJson() => {
    'engine': engine.id,
    'scenario': scenario,
    'runId': runId,
    'styleUrl': styleUrl,
    'offline': offline,
    'warmup': warmup,
    'iteration': iteration,
    'legMs': legMs,
    'stepSeconds': stepSeconds,
    'stressSteps': stressSteps,
    'dynamicSteps': dynamicSteps,
    'apiIterations': apiIterations,
    'gitRevision': gitRevision,
  };
}
