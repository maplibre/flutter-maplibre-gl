import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/engine/engine_host.dart';
import 'package:maplibre_gl_native/src/engine/map_session.dart';
import 'package:maplibre_gl_native/src/presentation/gestures/map_gestures.dart';
import 'package:maplibre_gl_native/src/presentation/platform/feature_interaction.dart';
import 'package:maplibre_gl_native/src/presentation/platform/map_options.dart';
import 'package:maplibre_gl_native/src/protocol/protocol.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show LatLng;

/// Records every command instead of crossing an isolate; queries are answered
/// by the test through [onQuery]. EngineHost's implicit interface is the
/// sanctioned seam for this (see its class doc).
class _RecordingHost implements EngineHost {
  final List<EngineCommand> commands = <EngineCommand>[];

  /// Answers queries; the default trips loudly so a test that triggers an
  /// unexpected round-trip fails instead of hanging on a bogus answer.
  Object? Function(EngineQuery<Object?> query) onQuery = (query) =>
      throw StateError('unexpected engine query: ${query.runtimeType}');

  @override
  void send(EngineCommand command) => commands.add(command);

  @override
  Future<R> query<R>(
    EngineQuery<R> query, {
    Duration timeout = const Duration(seconds: 15),
  }) async => onQuery(query) as R;

  @override
  void addEventListener(void Function(EngineEvent event) listener) {}

  @override
  void removeEventListener(void Function(EngineEvent event) listener) {}
}

/// One gesture handler wired exactly like MapView wires it, around the
/// recording host.
class _Harness {
  _Harness();

  final _RecordingHost host = _RecordingHost();
  late final MapSession session = MapSession(host, 1);
  final GestureConfig config = GestureConfig();
  double pitch = 0;
  int userPans = 0;
  final List<Map<String, dynamic>> longClicks = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> featureTaps = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> mapClicks = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> drags = <Map<String, dynamic>>[];

  late final FeatureInteraction features = FeatureInteraction(
    session: () => session,
    onFeatureTapped: featureTaps.add,
    onMapClick: mapClicks.add,
    onFeatureDragged: drags.add,
  );

  late final MapGestureHandler handler = MapGestureHandler(
    session: () => session,
    config: config,
    features: features,
    cameraPitch: () => pitch,
    mounted: () => true,
    onUserPan: () => userPans++,
    onMapLongClick: longClicks.add,
  );

  List<T> sent<T extends EngineCommand>() =>
      host.commands.whereType<T>().toList();
}

ScaleStartDetails start({int pointers = 1, Offset focal = Offset.zero}) =>
    ScaleStartDetails(
      pointerCount: pointers,
      focalPoint: focal,
      localFocalPoint: focal,
    );

ScaleUpdateDetails update({
  int pointers = 1,
  Offset delta = Offset.zero,
  double scale = 1,
  double rotation = 0,
  Offset focal = Offset.zero,
}) => ScaleUpdateDetails(
  pointerCount: pointers,
  focalPointDelta: delta,
  scale: scale,
  rotation: rotation,
  focalPoint: focal,
  localFocalPoint: focal,
);

ScaleEndDetails end({Velocity velocity = Velocity.zero, int pointers = 0}) =>
    ScaleEndDetails(velocity: velocity, pointerCount: pointers);

void main() {
  group('two-finger mode arbitration', () {
    test(
      'tilt is reachable with zoom and rotate disabled, even while the '
      'fingers incidentally spread and twist',
      () {
        final h = _Harness()..features.dragEnabled = false;
        h.config
          ..zoomEnabled = false
          ..rotateEnabled = false;
        h.handler.onScaleStart(start(pointers: 2));
        // Spread (scale 1.5) and twist (0.3 rad) would claim pinch mode if
        // those gestures could act; disabled, they must not block the shove.
        h.handler.onScaleUpdate(
          update(
            pointers: 2,
            delta: const Offset(2, -20),
            scale: 1.5,
            rotation: 0.3,
          ),
        );
        final pitches = h.sent<PitchByCommand>();
        expect(pitches, hasLength(1));
        // -(-20) * SHOVE_PIXEL_CHANGE_FACTOR (0.1 deg/px).
        expect(pitches.single.deltaDegrees, closeTo(2.0, 1e-9));
        expect(h.sent<ScaleByCommand>(), isEmpty);
        expect(h.sent<RotateByCommand>(), isEmpty);
        expect(h.sent<MoveByCommand>(), isEmpty);
      },
    );

    test('a vertical two-finger drag stays a pan when tilt is disabled', () {
      final h = _Harness()..features.dragEnabled = false;
      h.config.tiltEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      h.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(0, -20)),
      );
      expect(h.sent<PitchByCommand>(), isEmpty);
      final moves = h.sent<MoveByCommand>();
      expect(moves, hasLength(1));
      expect(moves.single.dy, -20);
    });

    test('a deliberate spread locks pinch: later vertical travel that would '
        'lock a shove keeps zooming instead', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      h.handler.onScaleUpdate(update(pointers: 2, scale: 1.1));
      expect(h.sent<ScaleByCommand>(), hasLength(1));
      // Way past the tilt lock travel, but the mode is already pinch.
      h.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(0, -30), scale: 1.1),
      );
      expect(h.sent<PitchByCommand>(), isEmpty);
    });

    test('the mode stays undecided below the thresholds and vertical travel '
        'accumulated across samples locks the tilt', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      // Below the zoom activation scale (0.04) and the tilt lock travel (14).
      h.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(0, -8), scale: 1.02),
      );
      expect(h.sent<PitchByCommand>(), isEmpty);
      expect(h.sent<ScaleByCommand>(), isEmpty);
      // Total travel is now (0, -20): mostly vertical and past the lock.
      h.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(0, -12), scale: 1.02),
      );
      expect(h.sent<PitchByCommand>(), hasLength(1));
    });
  });

  group('shove lock', () {
    test('lifting one finger mid-shove does not degenerate into a pan or a '
        'fling', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      h.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(0, -16)),
      );
      expect(h.sent<PitchByCommand>(), hasLength(1));
      // One finger up: the remaining finger keeps moving, fast.
      h.handler.onScaleUpdate(
        update(delta: const Offset(0, 25)),
      );
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(0, 3000))),
      );
      // No pan, no extra pitch from the single finger, no fling.
      expect(h.sent<MoveByCommand>(), isEmpty);
      expect(h.sent<PitchByCommand>(), hasLength(1));
      expect(h.userPans, 0);
    });
  });

  group('pinch activation gating', () {
    test('rotation stays off for the whole gesture once zoom wins '
        '(disableRotateWhenScaling)', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      h.handler.onScaleUpdate(update(pointers: 2, scale: 1.2));
      expect(h.sent<ScaleByCommand>(), hasLength(1));
      // 0.2 rad is ~11.5 degrees, far past the 3-degree threshold.
      h.handler.onScaleUpdate(
        update(pointers: 2, scale: 1.2, rotation: 0.2),
      );
      expect(h.sent<RotateByCommand>(), isEmpty);
    });

    test('zoom needs the raised threshold once rotation wins, and activation '
        'starts from the current pose instead of replaying the gated scale '
        '(increaseScaleThresholdWhenRotating)', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start(pointers: 2));
      // 0.1 rad = 5.73 degrees: rotation activates first.
      h.handler.onScaleUpdate(update(pointers: 2, rotation: 0.1));
      final rotations = h.sent<RotateByCommand>();
      expect(rotations, hasLength(1));
      // Flutter rotation is positive clockwise; the bearing delta is negated
      // so the map content follows the fingers.
      expect(rotations.single.deltaDegrees, closeTo(-5.7295779513, 1e-6));
      // |1.2 - 1| = 0.2 clears the normal 0.04 threshold but not the raised
      // 0.4 one: absorbed, not applied.
      h.handler.onScaleUpdate(update(pointers: 2, scale: 1.2, rotation: 0.1));
      expect(h.sent<ScaleByCommand>(), isEmpty);
      // 0.6 clears the raised threshold; the first applied factor is the
      // ratio from the last absorbed sample (1.6 / 1.2), not the full 1.6.
      h.handler.onScaleUpdate(update(pointers: 2, scale: 1.6, rotation: 0.1));
      final scales = h.sent<ScaleByCommand>();
      expect(scales, hasLength(1));
      expect(scales.single.factor, closeTo(1.6 / 1.2, 1e-9));
    });
  });

  group('fling', () {
    test('a fast release continues the pan with the SDK duration and offset '
        'math', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start());
      h.handler.onScaleUpdate(update(delta: const Offset(12, 0)));
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(2000, 0))),
      );
      final moves = h.sent<MoveByCommand>();
      expect(moves, hasLength(2));
      final fling = moves.last;
      // duration = speed / 7 / 1.5 + 150; offset = v * duration * 0.28 / 1000.
      expect(fling.durationMs, closeTo(340.47619047619048, 1e-9));
      expect(fling.dx, closeTo(190.66666666666666, 1e-9));
      expect(fling.dy, 0);
    });

    test('a release below the velocity threshold does not fling', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start());
      h.handler.onScaleUpdate(update(delta: const Offset(12, 0)));
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(800, 0))),
      );
      final moves = h.sent<MoveByCommand>();
      expect(moves, hasLength(1));
      expect(moves.single.durationMs, isNull);
    });

    test('a pitched camera flings shorter: the same screen offset covers '
        'more ground near the horizon', () {
      final h = _Harness()..features.dragEnabled = false;
      h.pitch = 60;
      h.handler.onScaleStart(start());
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(2000, 0))),
      );
      final fling = h.sent<MoveByCommand>().single;
      // tiltFactor = 1.5 + 60 / 10 = 7.5.
      expect(fling.durationMs, closeTo(188.09523809523810, 1e-9));
      expect(fling.dx, closeTo(105.33333333333333, 1e-9));
    });

    test('no fling when scrolling is disabled', () {
      final h = _Harness()..features.dragEnabled = false;
      h.config.scrollEnabled = false;
      h.handler.onScaleStart(start());
      h.handler.onScaleUpdate(update(delta: const Offset(12, 0)));
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(2000, 0))),
      );
      expect(h.sent<MoveByCommand>(), isEmpty);
    });
  });

  group('pan dismissing location tracking', () {
    test('a one-finger pan past the threshold dismisses; two-finger drift '
        'below the raised threshold does not', () {
      final h = _Harness()..features.dragEnabled = false;
      h.handler.onScaleStart(start());
      h.handler.onScaleUpdate(update(delta: const Offset(0, 5)));
      expect(h.userPans, 1);

      final h2 = _Harness()..features.dragEnabled = false;
      h2.handler.onScaleStart(start(pointers: 2));
      h2.handler.onScaleUpdate(
        update(pointers: 2, delta: const Offset(5, 0)),
      );
      expect(h2.sent<MoveByCommand>(), hasLength(1));
      expect(h2.userPans, 0);
    });
  });

  group('taps', () {
    test('a double tap zooms in one level about the tap point', () {
      final h = _Harness();
      h.handler.onDoubleTapDown(
        TapDownDetails(localPosition: const Offset(30, 40)),
      );
      h.handler.onDoubleTap();
      final scale = h.sent<ScaleByCommand>().single;
      expect(scale.factor, 2);
      expect(scale.anchorX, 30);
      expect(scale.anchorY, 40);
      expect(scale.durationMs, 300);
    });

    test('a double tap does nothing when double-click zoom is disabled', () {
      final h = _Harness();
      h.config.doubleClickZoomEnabled = false;
      h.handler.onDoubleTapDown(
        TapDownDetails(localPosition: const Offset(30, 40)),
      );
      h.handler.onDoubleTap();
      expect(h.sent<ScaleByCommand>(), isEmpty);
    });

    test('a quick stationary two-finger tap zooms out about the finger '
        'midpoint', () async {
      final h = _Harness();
      h.handler.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
      );
      h.handler.onPointerDown(
        const PointerDownEvent(
          position: Offset(30, 10),
          timeStamp: Duration(milliseconds: 50),
          pointer: 2,
        ),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 120)),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 150)),
      );
      final scale = h.sent<ScaleByCommand>().single;
      expect(scale.factor, 0.5);
      expect(scale.anchorX, 20);
      expect(scale.anchorY, 10);
      expect(scale.durationMs, 300);
      // The touch is bracketed like the SDK's onTouchEvent: flag set on the
      // first down, cleared (a microtask later) after the last up.
      await pumpEventQueue();
      final brackets = h.sent<SetGestureInProgressCommand>();
      expect(brackets.map((c) => c.inProgress), [true, false]);
    });

    test('a two-finger tap with too much travel does not zoom', () {
      final h = _Harness();
      h.handler.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
      );
      h.handler.onPointerDown(
        const PointerDownEvent(
          position: Offset(30, 10),
          timeStamp: Duration(milliseconds: 50),
          pointer: 2,
        ),
      );
      h.handler.onPointerMove(
        const PointerMoveEvent(delta: Offset(25, 0)),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 120)),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 150)),
      );
      expect(h.sent<ScaleByCommand>(), isEmpty);
    });

    test('a two-finger tap does nothing when zoom is disabled', () {
      final h = _Harness();
      h.config.zoomEnabled = false;
      h.handler.onPointerDown(
        const PointerDownEvent(position: Offset(10, 10)),
      );
      h.handler.onPointerDown(
        const PointerDownEvent(
          position: Offset(30, 10),
          timeStamp: Duration(milliseconds: 50),
          pointer: 2,
        ),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 120)),
      );
      h.handler.onPointerUp(
        const PointerUpEvent(timeStamp: Duration(milliseconds: 150)),
      );
      expect(h.sent<ScaleByCommand>(), isEmpty);
    });

    test('a tap cancels transitions, unprojects the point, and emits the map '
        'click', () async {
      final h = _Harness();
      h.host.onQuery = (query) {
        expect(query, isA<LatLngForPixelQuery>());
        final q = query as LatLngForPixelQuery;
        expect(q.x, 5);
        expect(q.y, 6);
        return (latitude: 1.0, longitude: 2.0);
      };
      h.handler.onTapUp(
        TapUpDetails(
          kind: PointerDeviceKind.touch,
          localPosition: const Offset(5, 6),
        ),
      );
      await pumpEventQueue();
      expect(h.sent<CancelTransitionsCommand>(), hasLength(1));
      expect(h.mapClicks, hasLength(1));
      expect(h.mapClicks.single['latLng'], const LatLng(1, 2));
    });
  });

  group('feature drag arbitration', () {
    test('pan deltas buffered while the hit-test is in flight are flushed as '
        'one pan on a miss', () async {
      final h = _Harness();
      h.features.registerLayer('pins');
      h.host.onQuery = (query) {
        expect(query, isA<QueryTopFeatureQuery>());
        return null; // No feature under the finger.
      };
      h.handler.onPointerDown(
        const PointerDownEvent(position: Offset(50, 50)),
      );
      h.handler.onScaleStart(start(focal: const Offset(50, 50)));
      h.handler.onScaleUpdate(update(delta: const Offset(3, 0)));
      h.handler.onScaleUpdate(update(delta: const Offset(4, 0)));
      // Nothing moves until the arbitration resolves.
      expect(h.sent<MoveByCommand>(), isEmpty);
      await pumpEventQueue();
      final moves = h.sent<MoveByCommand>();
      expect(moves, hasLength(1));
      expect(moves.single.dx, 7);
      expect(moves.single.dy, 0);
      expect(h.userPans, 1);
    });

    test('a draggable feature captures the gesture: drag events flow, the '
        'camera never pans, and the release does not fling', () async {
      final h = _Harness();
      h.features.registerLayer('pins');
      h.host.onQuery = (query) {
        if (query is QueryTopFeatureQuery) {
          return (
            layerId: 'pins',
            feature: <String, dynamic>{
              'id': 'f1',
              'properties': <String, dynamic>{'draggable': true},
            },
          );
        }
        final q = query as LatLngForPixelQuery;
        return (latitude: q.y / 10, longitude: q.x / 10);
      };
      h.handler.onPointerDown(
        const PointerDownEvent(position: Offset(50, 50)),
      );
      h.handler.onScaleStart(start(focal: const Offset(50, 50)));
      h.handler.onScaleUpdate(
        update(delta: const Offset(5, 0), focal: const Offset(55, 50)),
      );
      await pumpEventQueue();
      h.handler.onScaleEnd(
        end(velocity: const Velocity(pixelsPerSecond: Offset(5000, 0))),
      );
      expect(
        h.drags.map((d) => d['eventType']),
        ['start', 'drag', 'end'],
      );
      // The drag caught up with the finger through the unproject.
      expect(h.drags[1]['current'], const LatLng(5, 5.5));
      // Symbol placement transitions are suspended for the drag's duration.
      expect(
        h.sent<SetPlacementTransitionsCommand>().map((c) => c.enabled),
        [false, true],
      );
      expect(h.sent<MoveByCommand>(), isEmpty);
      expect(h.userPans, 0);
    });
  });
}
