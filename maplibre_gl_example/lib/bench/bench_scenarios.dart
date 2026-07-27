/// Benchmark scenario implementations.
///
/// Every scenario is deterministic (fixed camera choreography, seeded data)
/// and runs unchanged on all engine variants; the only engine-dependent code
/// is behind the shared `MapLibreMapController` API.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:maplibre_gl/maplibre_gl.dart';

import 'bench_config.dart';
import 'bench_recorder.dart';
import 'gesture_driver.dart';

/// Everything a scenario needs to drive the map and record results.
class BenchContext {
  BenchContext({
    required this.controller,
    required this.recorder,
    required this.config,
    required this.size,
    required this.gestures,
  });

  final MapLibreMapController controller;
  final BenchRecorder recorder;
  final BenchConfig config;

  /// Logical size of the map viewport.
  final Size size;
  final GestureDriver gestures;

  Offset get center => Offset(size.width / 2, size.height / 2);

  /// Runs [body] as a named phase; the engine frame stats collected during
  /// the phase are drained and attached to it.
  Future<void> phase(String name, Future<void> Function() body) async {
    final phase = recorder.startPhase(name);
    await body();
    Map<String, dynamic>? engineStats;
    try {
      engineStats = await controller.takeFrameStats();
    } on Exception {
      engineStats = null; // Backend without instrumentation support.
    }
    recorder.endPhase(phase, engineStats: engineStats);
    recorder.sampleRss();
  }

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));
}

typedef BenchScenario = Future<void> Function(BenchContext ctx);

final Map<String, BenchScenario> benchScenarios = <String, BenchScenario>{
  'style_load': _styleLoad,
  'world_tour': _worldTour,
  'tracking': _tracking,
  'gestures': _gestures,
  'stress_ramp': _stressRamp,
  'dynamic_data': _dynamicData,
  'api_latency': _apiLatency,
};

const LatLng _milan = LatLng(45.4642, 9.19);

// Upstream world-tour cities (BenchmarkActivity), zoom 14.
const List<LatLng> _tourLegs = [
  LatLng(37.7749, -122.4194), // San Francisco
  LatLng(38.9072, -77.0369), // Washington DC
  LatLng(52.3676, 4.9041), // Amsterdam
  LatLng(60.1699, 24.9384), // Helsinki
];

/// Style load / time-to-first-frame: the interesting marks (mapCreated,
/// styleLoaded, firstIdle) are recorded by the bench shell; this scenario
/// only waits for the map to become fully idle.
Future<void> _styleLoad(BenchContext ctx) async {
  await ctx.phase('idle_wait', () async {
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (!ctx.recorder.marks.containsKey('firstIdle') &&
        DateTime.now().isBefore(deadline)) {
      await ctx.wait(100);
    }
  });
}

/// Upstream-style world tour: four fly-to legs at zoom 14 driven by the
/// engine's own camera animation.
Future<void> _worldTour(BenchContext ctx) async {
  for (var i = 0; i < _tourLegs.length; i++) {
    await ctx.phase('leg_$i', () async {
      unawaited(
        ctx.controller.animateCamera(
          CameraUpdate.newLatLngZoom(_tourLegs[i], 14),
          duration: Duration(milliseconds: ctx.config.legMs),
        ),
      );
      // Fixed wall-clock wait: animateCamera completion semantics must not
      // influence phase duration across engines.
      await ctx.wait(ctx.config.legMs + 500);
    });
  }
}

/// GPS-follow simulation: instant camera jumps at frame cadence along a
/// deterministic orbit (the API-heavy camera path real tracking apps use).
Future<void> _tracking(BenchContext ctx) async {
  await ctx.controller.moveCamera(CameraUpdate.newLatLngZoom(_milan, 15));
  await ctx.wait(2000);
  final total = Duration(seconds: 3 * ctx.config.stepSeconds);
  await ctx.phase('tracking', () async {
    await _drivePerFrameCamera(ctx, 'tracking', total, (t) {
      final angle = 2 * math.pi * 2 * t;
      return CameraPosition(
        target: LatLng(
          _milan.latitude + 0.012 * math.sin(angle),
          _milan.longitude + 0.017 * math.cos(angle),
        ),
        zoom: 15,
        bearing: (360 * 4 * t) % 360,
      );
    });
  });
}

/// Synthetic touch: continuous pans, flings with inertia, pinches, and
/// two-finger rotations.
Future<void> _gestures(BenchContext ctx) async {
  final c = ctx.center;
  final dx = ctx.size.width * 0.30;
  final dy = ctx.size.height * 0.18;
  await ctx.controller.moveCamera(CameraUpdate.newLatLngZoom(_milan, 14));
  await ctx.wait(2000);

  await ctx.phase('pan', () async {
    for (var i = 0; i < 8; i++) {
      final flip = i.isEven ? 1.0 : -1.0;
      await ctx.gestures.drag(
        from: c + Offset(flip * dx, flip * dy),
        to: c - Offset(flip * dx, flip * dy),
        duration: const Duration(milliseconds: 1200),
      );
      await ctx.wait(300);
    }
  });

  await ctx.phase('fling', () async {
    for (var i = 0; i < 4; i++) {
      final flip = i.isEven ? 1.0 : -1.0;
      await ctx.gestures.drag(
        from: c + Offset(flip * dx, 0),
        to: c - Offset(flip * dx, 0),
        duration: const Duration(milliseconds: 140),
      );
      await ctx.wait(1800); // Let the inertia animation play out.
    }
  });

  await ctx.phase('pinch', () async {
    for (var i = 0; i < 3; i++) {
      await ctx.gestures.twoFinger(
        center: c,
        fromRadius: 45,
        toRadius: 170,
        duration: const Duration(milliseconds: 1100),
      );
      await ctx.wait(400);
      await ctx.gestures.twoFinger(
        center: c,
        fromRadius: 170,
        toRadius: 45,
        duration: const Duration(milliseconds: 1100),
      );
      await ctx.wait(400);
    }
  });

  await ctx.phase('rotate', () async {
    for (var i = 0; i < 4; i++) {
      await ctx.gestures.twoFinger(
        center: c,
        fromRadius: 130,
        toRadius: 130,
        turnRadians: (i.isEven ? 1 : -1) * math.pi / 2,
        duration: const Duration(milliseconds: 1200),
      );
      await ctx.wait(400);
    }
  });
}

/// Static feature-count ramp: for each step N, replace the GeoJSON data with
/// N seeded points (timing the call), then orbit the camera over them.
Future<void> _stressRamp(BenchContext ctx) async {
  await ctx.controller.moveCamera(CameraUpdate.newLatLngZoom(_milan, 11));
  await _addBenchLayer(ctx);
  for (final n in ctx.config.stressSteps) {
    final data = _pointCollection(n, spreadDeg: 0.35);
    await ctx.phase('data_$n', () async {
      final clock = Stopwatch()..start();
      await ctx.controller.setGeoJsonSource(_benchSourceId, data);
      ctx.recorder.recordLatency('set_data_$n', clock.elapsedMicroseconds);
      await ctx.wait(2000); // Parse/upload settle before the orbit measures.
    });
    await ctx.phase('orbit_$n', () async {
      await _drivePerFrameCamera(
        ctx,
        'orbit_$n',
        Duration(seconds: ctx.config.stepSeconds),
        (t) => CameraPosition(target: _milan, zoom: 11.5, bearing: 360 * t),
      );
    });
  }
}

/// Live-data stress: rewrite every feature position as fast as the backend
/// sustains (30 Hz target), timing each `setGeoJsonSource` round trip.
Future<void> _dynamicData(BenchContext ctx) async {
  await ctx.controller.moveCamera(CameraUpdate.newLatLngZoom(_milan, 12));
  await _addBenchLayer(ctx);
  for (final n in ctx.config.dynamicSteps) {
    final bases = _pointGrid(n, spreadDeg: 0.18);
    await ctx.phase('dynamic_$n', () async {
      const targetInterval = Duration(milliseconds: 33);
      final phaseClock = Stopwatch()..start();
      final total = Duration(seconds: ctx.config.stepSeconds);
      var updates = 0;
      while (phaseClock.elapsed < total) {
        final angle = phaseClock.elapsedMilliseconds / 1000 * 2 * math.pi;
        final callClock = Stopwatch()..start();
        await ctx.controller.setGeoJsonSource(
          _benchSourceId,
          _orbitedCollection(bases, angle),
        );
        ctx.recorder.recordLatency('update_$n', callClock.elapsedMicroseconds);
        updates++;
        final leftover = targetInterval - callClock.elapsed;
        if (leftover > Duration.zero) await Future<void>.delayed(leftover);
      }
      ctx.recorder.count(
        'updates_per_s_$n',
        updates / phaseClock.elapsedMilliseconds * 1000,
      );
    });
  }
}

/// Round-trip latency of the hot query APIs, engine transport being the
/// variable under test (method channel vs direct FFI vs SendPort).
Future<void> _apiLatency(BenchContext ctx) async {
  await ctx.controller.moveCamera(CameraUpdate.newLatLngZoom(_milan, 12));
  await _addBenchLayer(ctx);
  await ctx.controller.setGeoJsonSource(
    _benchSourceId,
    _pointCollection(1000, spreadDeg: 0.18),
  );
  await ctx.wait(3000);

  final iters = ctx.config.apiIterations;
  final centerPoint = math.Point<double>(ctx.center.dx, ctx.center.dy);
  final batch = [
    for (var i = 0; i < 100; i++)
      LatLng(_milan.latitude + (i % 10) * 0.01, _milan.longitude + i * 0.001),
  ];

  Future<void> measure(
    String name,
    Future<Object?> Function() call,
  ) async {
    await ctx.phase('api_$name', () async {
      for (var i = 0; i < iters; i++) {
        final clock = Stopwatch()..start();
        await call();
        ctx.recorder.recordLatency(name, clock.elapsedMicroseconds);
      }
    });
  }

  await measure(
    'toScreenLocation',
    () => ctx.controller.toScreenLocation(_milan),
  );
  await measure('toLatLng', () => ctx.controller.toLatLng(centerPoint));
  await measure(
    'toScreenLocationBatch100',
    () => ctx.controller.toScreenLocationBatch(batch),
  );
  await measure(
    'queryRenderedFeatures',
    () => ctx.controller.queryRenderedFeatures(
      centerPoint,
      [_benchLayerId],
      null,
    ),
  );
}

// --- Shared helpers ----------------------------------------------------------

const String _benchSourceId = 'bench-source';
const String _benchLayerId = 'bench-circles';

Future<void> _addBenchLayer(BenchContext ctx) async {
  await ctx.controller.addGeoJsonSource(_benchSourceId, _emptyCollection());
  await ctx.controller.addCircleLayer(
    _benchSourceId,
    _benchLayerId,
    const CircleLayerProperties(
      circleRadius: 4.0,
      circleColor: '#e74c3c',
      circleOpacity: 0.85,
      circleStrokeWidth: 1.0,
      circleStrokeColor: '#ffffff',
    ),
  );
}

/// Instant camera jumps at ~60 Hz cadence; saturation is absorbed by
/// skipping ticks (recorded as a counter) instead of queueing, so a slow
/// backend does not accumulate an unbounded command backlog.
Future<void> _drivePerFrameCamera(
  BenchContext ctx,
  String counterKey,
  Duration total,
  CameraPosition Function(double t) positionAt,
) {
  const tick = Duration(milliseconds: 16);
  final clock = Stopwatch()..start();
  final done = Completer<void>();
  var pending = 0;
  var skipped = 0;
  var issued = 0;
  Timer.periodic(tick, (timer) {
    final t = clock.elapsedMicroseconds / total.inMicroseconds;
    if (t >= 1) {
      timer.cancel();
      ctx.recorder.count('camera_updates_$counterKey', issued);
      ctx.recorder.count('camera_skipped_$counterKey', skipped);
      done.complete();
      return;
    }
    if (pending > 3) {
      skipped++;
      return;
    }
    pending++;
    issued++;
    unawaited(
      ctx.controller
          .moveCamera(CameraUpdate.newCameraPosition(positionAt(t)))
          .whenComplete(() => pending--),
    );
  });
  return done.future;
}

Map<String, dynamic> _emptyCollection() => <String, dynamic>{
  'type': 'FeatureCollection',
  'features': const <Object>[],
};

/// N seeded random points around Milan.
Map<String, dynamic> _pointCollection(int n, {required double spreadDeg}) {
  final random = math.Random(42);
  return <String, dynamic>{
    'type': 'FeatureCollection',
    'features': [
      for (var i = 0; i < n; i++)
        <String, dynamic>{
          'type': 'Feature',
          'id': i,
          'properties': <String, dynamic>{'i': i},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': [
              _milan.longitude + (random.nextDouble() - 0.5) * 2 * spreadDeg,
              _milan.latitude + (random.nextDouble() - 0.5) * spreadDeg,
            ],
          },
        },
    ],
  };
}

/// Deterministic base positions reused by every dynamic-data frame.
List<Offset> _pointGrid(int n, {required double spreadDeg}) {
  final random = math.Random(1337);
  return [
    for (var i = 0; i < n; i++)
      Offset(
        _milan.longitude + (random.nextDouble() - 0.5) * 2 * spreadDeg,
        _milan.latitude + (random.nextDouble() - 0.5) * spreadDeg,
      ),
  ];
}

/// The bases orbiting their anchor by [angle]; rebuilt every update to
/// exercise the full serialize-transfer-parse pipeline.
Map<String, dynamic> _orbitedCollection(List<Offset> bases, double angle) {
  const radius = 0.0012;
  return <String, dynamic>{
    'type': 'FeatureCollection',
    'features': [
      for (var i = 0; i < bases.length; i++)
        <String, dynamic>{
          'type': 'Feature',
          'id': i,
          'properties': <String, dynamic>{'i': i},
          'geometry': <String, dynamic>{
            'type': 'Point',
            'coordinates': [
              bases[i].dx + radius * math.cos(angle + i),
              bases[i].dy + radius * math.sin(angle + i),
            ],
          },
        },
    ],
  };
}
