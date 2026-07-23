/// Benchmark entrypoint: runs ONE scenario on ONE engine variant and exports
/// the measurements to logcat, then idles until the orchestrator force-stops
/// the app.
///
/// Launched by tool/bench/run_bench.dart as
///
/// ```sh
/// adb shell am start -n org.maplibre.example/io.flutter.embedding.android.FlutterActivity \
///   --es route '/bench?engine=ffi_isolate&scenario=world_tour&offline=1&run=<id>'
/// ```
///
/// (`FlutterActivity` exposes the `route` extra as the default route.)
/// Manual runs are possible with `flutter run --profile -t lib/main_bench.dart`.
library;

import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_native/maplibre_gl_native.dart';

import 'bench/bench_config.dart';
import 'bench/bench_recorder.dart';
import 'bench/bench_scenarios.dart';
import 'bench/gesture_driver.dart';

Future<void> main() async {
  final config = BenchConfig.fromRoute(
    PlatformDispatcher.instance.defaultRouteName,
  );
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      switch (config.engine) {
        case BenchEngine.stable:
          break;
        case BenchEngine.ffi:
          MapLibreGlNative.use(engineIsolate: false);
        case BenchEngine.ffiIsolate:
          MapLibreGlNative.use(engineIsolate: true);
      }
      if (config.offline) {
        // Engine-level network cut, set before the style loads: measured
        // runs must be served entirely from the warmed tile cache.
        if (config.engine == BenchEngine.stable) {
          await setOffline(true);
        } else {
          await MapLibreGlNativeOffline.setOffline(true);
        }
      }
      runApp(BenchApp(config));
    },
    (error, stackTrace) {
      // The orchestrator waits for this sentinel; a crash must not hang it.
      print('BENCH_DONE:${config.runId}:error:$error');
      debugPrint('$stackTrace');
    },
  );
}

class BenchApp extends StatelessWidget {
  const BenchApp(this.config, {super.key});

  final BenchConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BenchShell(config),
  );
}

class BenchShell extends StatefulWidget {
  const BenchShell(this.config, {super.key});

  final BenchConfig config;

  @override
  State<BenchShell> createState() => _BenchShellState();
}

class _BenchShellState extends State<BenchShell> {
  final BenchRecorder _recorder = BenchRecorder();
  late MapLibreMapController _controller;
  Timer? _rssTimer;
  String _status = 'waiting for map';
  bool _started = false;

  BenchConfig get config => widget.config;

  @override
  void initState() {
    super.initState();
    _recorder
      ..start()
      ..mark('appInit');
  }

  @override
  void dispose() {
    _rssTimer?.cancel();
    _recorder.stop();
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    _recorder.mark('mapCreated');
    setState(() => _status = 'map created');
  }

  void _onStyleLoaded() {
    _recorder.mark('styleLoaded');
    setState(() => _status = 'style loaded');
    if (!_started) {
      _started = true;
      unawaited(_run());
    }
  }

  void _onMapIdle() {
    _recorder.marks.putIfAbsent('firstIdle', () => _recorder.nowUs);
  }

  Future<void> _run() async {
    final controller = _controller;
    final viewportSize = MediaQuery.sizeOf(context);
    try {
      await controller.setFrameStatsEnabled(true);
    } on Exception {
      // Backend without instrumentation; Flutter timings still recorded.
    }
    _rssTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _recorder.sampleRss(),
    );
    final scenario = benchScenarios[config.scenario];
    setState(() => _status = 'running ${config.scenario}');
    var outcome = 'ok';
    try {
      if (scenario == null) {
        throw ArgumentError('unknown scenario "${config.scenario}"');
      }
      // Give every scenario a settled, fully loaded starting map, except the
      // one whose subject is the loading itself.
      if (config.scenario != 'style_load') {
        await _waitForFirstIdle(const Duration(seconds: 45));
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await scenario(
        BenchContext(
          controller: controller,
          recorder: _recorder,
          config: config,
          size: viewportSize,
          gestures: GestureDriver(),
        ),
      );
    } catch (error) {
      outcome = 'error:$error';
    }
    _rssTimer?.cancel();
    _recorder.stop();
    await _recorder.export(config.runId, await _metadata());
    setState(() => _status = 'done ($outcome)');
    print('BENCH_DONE:${config.runId}:$outcome');
  }

  Future<void> _waitForFirstIdle(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    while (!_recorder.marks.containsKey('firstIdle') &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<Map<String, dynamic>> _metadata() async {
    final android = await DeviceInfoPlugin().androidInfo;
    final display = PlatformDispatcher.instance.displays.firstOrNull;
    // The isolate bootstrap can silently fall back to the local engine; the
    // aggregator rejects runs whose actual transport mismatches the config.
    final transport = config.engine == BenchEngine.stable
        ? 'platform-view'
        : MapLibreGlNative.activeEngineTransport;
    return <String, dynamic>{
      'config': config.toJson(),
      'engineTransport': transport,
      'profileMode': kProfileMode,
      'deviceModel': android.model,
      'deviceBrand': android.brand,
      'androidSdk': android.version.sdkInt,
      'displayRefreshRate': display?.refreshRate,
      'devicePixelRatio': display?.devicePixelRatio,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        MapLibreMap(
          styleString: config.styleUrl,
          initialCameraPosition: const CameraPosition(
            target: LatLng(45.4642, 9.19),
            zoom: 11,
          ),
          annotationOrder: const [],
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapIdle: _onMapIdle,
        ),
        Positioned(
          left: 8,
          top: 8,
          child: SafeArea(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Text(
                  '${config.engine.id} | ${config.scenario} | '
                  'i${config.iteration}${config.warmup ? ' warmup' : ''} | '
                  '$_status',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
