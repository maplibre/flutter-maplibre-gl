import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/gestures.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show LatLng;

import '../../engine/map_session.dart';
import '../../protocol/protocol.dart';
import '../platform/feature_interaction.dart';
import '../platform/map_options.dart';

/// Flutter-side gesture layer of the FFI map view.
///
/// Owns all gesture state and arbitration (pan/pinch/rotate/shove, feature
/// drag, fling, double- and two-finger taps) and translates recognized
/// gestures into engine camera commands; all camera math and constraint
/// clamping happens inside MapLibre Native, exactly like the Android SDK's
/// MapGestureDetector, which this class mirrors.
///
/// The view wires the widget callbacks (a [Listener] plus a
/// [GestureDetector]) straight to the handler methods; the handler reaches
/// back through the injected getters, so it never outlives or rebuilds the
/// widget tree. It knows nothing about the `MapLibrePlatform` adapter: what it
/// needs is the session, the gesture flags, the feature hit-tester, and two
/// event sinks.
class MapGestureHandler {
  MapGestureHandler({
    required MapSession? Function() session,
    required GestureConfig config,
    required FeatureInteraction features,
    required double Function() cameraPitch,
    required bool Function() mounted,
    required void Function() onUserPan,
    required void Function(Map<String, dynamic> payload) onMapLongClick,
  }) : _session = session,
       _config = config,
       _features = features,
       _cameraPitch = cameraPitch,
       _mounted = mounted,
       _onUserPan = onUserPan,
       _onMapLongClick = onMapLongClick;

  /// The live session, or null before the map is up and after it is torn down:
  /// a gesture can be in flight across both, and a null session simply means
  /// there is nothing to move.
  final MapSession? Function() _session;

  /// Which gestures are enabled. Read per sample, never cached: the app can
  /// flip a flag mid-gesture through `MapLibreMap`'s properties.
  final GestureConfig _config;

  /// Hit-testing of the interactive layers, plus the feature tap/drag events.
  final FeatureInteraction _features;

  final double Function() _cameraPitch;
  final bool Function() _mounted;

  /// Called once a gesture has panned the camera far enough to count as the
  /// user taking over: dismisses an active location tracking mode.
  final void Function() _onUserPan;

  final void Function(Map<String, dynamic> payload) _onMapLongClick;

  // Tuning constants.
  // Ported from the Android SDK gesture stack (MapGestureDetector.java,
  // MapLibreConstants.java, dimens.xml) so both backends feel the same.
  // Units: logical pixels (== dp on Android), degrees, milliseconds.

  /// VELOCITY_THRESHOLD_IGNORE_FLING: slower releases do not fling.
  static const _flingVelocityThreshold = 1000.0;

  /// ANIMATION_DURATION_FLING_BASE: constant part of the fling duration.
  static const _flingBaseTimeMs = 150.0;

  /// Empirical Android factor converting velocity * duration to an offset.
  static const _flingOffsetFactor = 0.28;

  /// Rotate detector angle threshold: accumulated rotation required before
  /// the rotation gesture activates.
  static const _rotateActivationDegrees = 3.0;

  /// Scale change (|scale - 1| since gesture start) required before the zoom
  /// gesture activates; stands in for the SDK's span-since-start threshold.
  static const _zoomActivationScale = 0.04;

  /// Raised zoom activation while a rotation is active, mirroring
  /// increaseScaleThresholdWhenRotating (75dp span on Android).
  static const _zoomActivationScaleWhileRotating = 0.4;

  /// SHOVE_PIXEL_CHANGE_FACTOR: tilt degrees per vertical pixel.
  static const _shoveDegreesPerPixel = 0.1;

  /// Two-finger travel that locks the shove (tilt) gesture.
  static const _tiltLockTravel = 14.0;

  /// ANIMATION_DURATION: double-tap and two-finger-tap zoom animation.
  static const _tapZoomDurationMs = 300.0;

  /// A two-finger tap must lift within this time of the second finger down
  /// and move less than [_twoFingerTapMaxTravel] to count.
  static const _twoFingerTapMaxDuration = Duration(milliseconds: 250);
  static const _twoFingerTapMaxTravel = 20.0;

  /// Scroll-wheel pixels per zoom level (one mouse notch on Android is one
  /// zoom level in the SDK; Flutter reports notches as ~this many pixels).
  static const _scrollWheelNotchPixels = 120.0;

  /// Cumulative pan beyond which location tracking is dismissed; mirrors the
  /// Android LocationComponent thresholds (higher for multi-finger gestures
  /// so finger drift during a pinch does not dismiss).
  static const _panDismissThreshold = 4.0;
  static const _panDismissThresholdMultiFinger = 24.0;

  // Gesture state.

  // Incremental tracking for the ScaleGestureRecognizer stream.
  double _lastGestureScale = 1;
  double _lastGestureRotation = 0;
  Offset? _doubleTapPosition;

  // Two-finger gestures start undecided and lock to either pinch
  // (zoom/rotate/pan) or tilt (shove) once movement crosses a threshold,
  // mirroring the SDK's mutually exclusive shove/scale/rotate sets.
  _TwoFingerMode _twoFingerMode = _TwoFingerMode.undecided;
  Offset _twoFingerTravel = Offset.zero;

  // Within pinch mode zoom and rotation activate independently: rotation
  // stays off once zoom wins (disableRotateWhenScaling) and zoom needs a
  // raised threshold once rotation wins (increaseScaleThresholdWhenRotating).
  bool _zoomActive = false;
  bool _rotateActive = false;

  /// Cumulative camera pan applied by the current gesture, used to dismiss
  /// location tracking once the user deliberately moves the map.
  Offset _gesturePanTravel = Offset.zero;

  // NOTE(perf, 2026-07): a per-frame command batch flushed via
  // scheduleFrameCallback was tried here and REGRESSED UI jank (extra forced
  // frames out of phase with pointer delivery; pan jank 5% -> 32% in the
  // phase-2 bisect). Commands stay per-sample: they are cheap on the
  // SendPort and the engine already coalesces camera writes per frame.

  // Feature drag: a one-finger pan or long-press first hit-tests the
  // draggable layers (async, one isolate round-trip); pan deltas are
  // buffered until the arbitration resolves to a drag session or a pan.
  _DragSession? _drag;
  bool _dragResolving = false;
  int _dragGeneration = 0;

  // Last pointer-down position: the drag hit-test anchors here instead of
  // the scale-start focal point, which the gesture arena only reports after
  // the touch slop (~18px) and would already be off a small feature.
  Offset? _pointerDownPosition;
  Offset _bufferedPanDelta = Offset.zero;
  Offset? _dragPosition;
  bool _dragQueryInFlight = false;
  bool _dragDirty = false;

  // Raw pointer bookkeeping for the two-finger tap (zoom out): the scale
  // recognizer reports it as a no-op gesture, so it is detected from the
  // Listener's pointer stream instead.
  int _pointersDown = 0;
  int _maxPointersDown = 0;
  Offset? _firstPointerPosition;
  Offset? _secondPointerPosition;
  Duration? _secondPointerDownTime;
  double _pointerTravel = 0;

  // Raw pointer stream (Listener).

  void onPointerDown(PointerDownEvent event) {
    _pointersDown++;
    if (_pointersDown == 1) {
      _pointerDownPosition = event.localPosition;
      _firstPointerPosition = event.localPosition;
      _maxPointersDown = 1;
      _pointerTravel = 0;
      _secondPointerPosition = null;
      _secondPointerDownTime = null;
      // Bracket the touch interaction like the SDK's onTouchEvent
      // (ACTION_DOWN sets the gesture flag, the last ACTION_UP clears it).
      _setGestureInProgress(true);
    } else {
      _maxPointersDown = max(_maxPointersDown, _pointersDown);
      if (_pointersDown == 2) {
        _secondPointerPosition = event.localPosition;
        _secondPointerDownTime = event.timeStamp;
      }
    }
  }

  void onPointerMove(PointerMoveEvent event) {
    _pointerTravel += event.delta.distance;
  }

  void onPointerUp(PointerUpEvent event) {
    if (_pointersDown > 0) _pointersDown--;
    if (_pointersDown == 0) {
      _clearGestureInProgressSoon();
      _maybeTwoFingerTap(event.timeStamp);
    }
  }

  void onPointerCancel(PointerCancelEvent event) {
    if (_pointersDown > 0) _pointersDown--;
    if (_pointersDown == 0) _clearGestureInProgressSoon();
    _maxPointersDown = 0;
  }

  /// The recognizer end callbacks (e.g. the fling of onScaleEnd) fire later
  /// in the same pointer-event dispatch as onPointerUp, so the clear is
  /// deferred one microtask: the fling command then reaches the engine while
  /// the gesture flag is still set, like Android (onFling runs inside
  /// onTouchEvent, before ACTION_UP clears the flag), keeping the fling an
  /// easeTo instead of being promoted to flyTo.
  void _clearGestureInProgressSoon() {
    scheduleMicrotask(() {
      if (_pointersDown == 0) _setGestureInProgress(false);
    });
  }

  void _setGestureInProgress(bool inProgress) {
    final session = _session();
    if (session == null) return;
    session.send(
      SetGestureInProgressCommand(session.id, inProgress: inProgress),
    );
  }

  /// Two-finger tap zooms out one level about the finger midpoint, like the
  /// SDK's onMultiFingerTap (exactly two pointers, quick, stationary).
  void _maybeTwoFingerTap(Duration upTime) {
    final session = _session();
    final first = _firstPointerPosition;
    final second = _secondPointerPosition;
    final secondDownTime = _secondPointerDownTime;
    final valid =
        session != null &&
        _config.zoomEnabled &&
        _maxPointersDown == 2 &&
        first != null &&
        second != null &&
        secondDownTime != null &&
        upTime - secondDownTime <= _twoFingerTapMaxDuration &&
        _pointerTravel < _twoFingerTapMaxTravel &&
        _drag == null;
    _maxPointersDown = 0;
    if (!valid) return;
    final anchor = (first + second) / 2;
    session.send(
      ScaleByCommand(
        session.id,
        0.5,
        anchorX: anchor.dx,
        anchorY: anchor.dy,
        durationMs: _tapZoomDurationMs,
      ),
    );
  }

  /// Mouse scroll wheel zooms about the cursor (one notch = one level, like
  /// the SDK's onGenericMotionEvent). Registered through the resolver so the
  /// event is not also consumed by an enclosing scrollable.
  void onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_config.zoomEnabled) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final session = _session();
      if (session == null) return;
      final scrollEvent = event as PointerScrollEvent;
      final zoomDelta = -scrollEvent.scrollDelta.dy / _scrollWheelNotchPixels;
      if (zoomDelta == 0) return;
      session.send(
        ScaleByCommand(
          session.id,
          pow(2.0, zoomDelta).toDouble(),
          anchorX: scrollEvent.localPosition.dx,
          anchorY: scrollEvent.localPosition.dy,
        ),
      );
    });
  }

  // Scale gesture family.

  void onScaleStart(ScaleStartDetails details) {
    final session = _session();
    if (session == null) return;
    session.send(CancelTransitionsCommand(session.id));
    _lastGestureScale = 1;
    _lastGestureRotation = 0;
    _twoFingerMode = _TwoFingerMode.undecided;
    _twoFingerTravel = Offset.zero;
    _zoomActive = false;
    _rotateActive = false;
    _gesturePanTravel = Offset.zero;
    _endDrag();
    _dragResolving = false;
    _bufferedPanDelta = Offset.zero;
    if (details.pointerCount == 1 && _features.dragEnabled) {
      _dragResolving = true;
      _dragPosition = details.localFocalPoint;
      unawaited(
        _resolveDragCandidate(
          _pointerDownPosition ?? details.localFocalPoint,
          ++_dragGeneration,
          onMiss: _flushBufferedPan,
        ),
      );
    }
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    final session = _session();
    if (session == null) return;

    // Feature drag arbitration: while the hit-test is in flight buffer the
    // movement; while a drag is active route movement to drag events.
    if (_dragResolving) {
      if (details.pointerCount >= 2) {
        // A second finger means pinch intent: cancel the drag candidate.
        _dragResolving = false;
        _dragGeneration++;
        _flushBufferedPan();
      } else {
        _bufferedPanDelta += details.focalPointDelta;
        _dragPosition = details.localFocalPoint;
        return;
      }
    }
    if (_drag != null) {
      if (details.pointerCount >= 2) {
        _endDrag();
      } else {
        _dragPosition = details.localFocalPoint;
        _pumpDrag();
        return;
      }
    }

    if (details.pointerCount >= 2) {
      _twoFingerTravel += details.focalPointDelta;
      if (_twoFingerMode == _TwoFingerMode.undecided) {
        _twoFingerMode = _resolveTwoFingerMode(details);
      }
    }
    if (_twoFingerMode == _TwoFingerMode.tilt) {
      // Shove excludes pan/zoom/rotate for the whole gesture, like the
      // SDK's mutually exclusive gesture sets (move disabled during shove).
      // The lock outlives the second finger on purpose: lifting one finger
      // mid-shove must not degenerate into a pan, so the remaining samples
      // are ignored until the gesture ends.
      if (details.pointerCount >= 2 &&
          _config.tiltEnabled &&
          details.focalPointDelta.dy != 0) {
        session.send(
          PitchByCommand(
            session.id,
            -details.focalPointDelta.dy * _shoveDegreesPerPixel,
          ),
        );
      }
      return;
    }

    // One-finger drag or pinch focal movement: focalPointDelta is already in
    // logical pixels.
    if (_config.scrollEnabled && details.focalPointDelta != Offset.zero) {
      _accumulateGesturePan(details.focalPointDelta, details.pointerCount);
      session.send(
        MoveByCommand(
          session.id,
          details.focalPointDelta.dx,
          details.focalPointDelta.dy,
        ),
      );
    }

    if (details.pointerCount >= 2) {
      _updatePinchActivation(details);
      final anchor = details.localFocalPoint;
      // Increments are absorbed even while a gesture is gated so activation
      // starts clean from the current pose instead of replaying the
      // below-threshold accumulation as a visible jump.
      if (details.scale != _lastGestureScale) {
        final ratio = details.scale / _lastGestureScale;
        _lastGestureScale = details.scale;
        if (_zoomActive &&
            ratio.isFinite &&
            ratio > 0 &&
            (ratio - 1).abs() >= 0.001) {
          session.send(
            ScaleByCommand(
              session.id,
              ratio,
              anchorX: anchor.dx,
              anchorY: anchor.dy,
            ),
          );
        }
      }
      if (details.rotation != _lastGestureRotation) {
        final deltaDegrees =
            (details.rotation - _lastGestureRotation) * 180 / pi;
        _lastGestureRotation = details.rotation;
        if (_rotateActive && deltaDegrees.abs() >= 0.1) {
          // Flutter rotation is positive clockwise (y-axis points down)
          // while increasing the bearing turns the map content
          // counterclockwise, so the gesture delta must be subtracted for
          // the map to follow the fingers.
          session.send(
            RotateByCommand(
              session.id,
              -deltaDegrees,
              anchorX: anchor.dx,
              anchorY: anchor.dy,
            ),
          );
        }
      }
    }
  }

  void onScaleEnd(ScaleEndDetails details) {
    final wasTilt = _twoFingerMode == _TwoFingerMode.tilt;
    if (_dragResolving) {
      // The gesture ended before the hit-test resolved: it was a plain pan.
      _dragResolving = false;
      _dragGeneration++;
      _flushBufferedPan();
    }
    final hadDrag = _drag != null;
    _endDrag();
    if (!hadDrag && !wasTilt) _maybeFling(details);
  }

  /// Continues a released pan with the SDK's fling: a single animated moveBy
  /// that MapLibre Native interpolates internally (no per-frame Dart work).
  void _maybeFling(ScaleEndDetails details) {
    final session = _session();
    if (session == null || !_config.scrollEnabled) return;
    final velocity = details.velocity.pixelsPerSecond;
    final speed = velocity.distance;
    if (speed < _flingVelocityThreshold) return;
    // Tilted views fling shorter: the same screen offset covers more ground
    // near the horizon.
    final pitch = _cameraPitch();
    final tiltFactor = 1.5 + (pitch != 0 ? pitch / 10 : 0.0);
    final durationMs = speed / 7 / tiltFactor + _flingBaseTimeMs;
    session.send(
      MoveByCommand(
        session.id,
        velocity.dx * durationMs * _flingOffsetFactor / 1000,
        velocity.dy * durationMs * _flingOffsetFactor / 1000,
        durationMs: durationMs,
      ),
    );
  }

  _TwoFingerMode _resolveTwoFingerMode(ScaleUpdateDetails details) {
    // Only enabled gestures may claim the sequence (like the activation
    // gating in _updatePinchActivation): with zoom and rotate disabled, an
    // incidental spread must not lock the gesture into pinch mode and make
    // an enabled tilt unreachable, and with tilt disabled a vertical drag
    // must stay a pan instead of locking into a shove that does nothing.
    final zoomIntent =
        _config.zoomEnabled && (details.scale - 1).abs() > _zoomActivationScale;
    final rotateIntent =
        _config.rotateEnabled &&
        details.rotation.abs() * 180 / pi >= _rotateActivationDegrees;
    // Zoom/rotate intent wins as soon as the fingers spread or turn.
    if (zoomIntent || rotateIntent) return _TwoFingerMode.pinch;
    // Mostly-vertical parallel movement locks the tilt (shove) gesture.
    if (_config.tiltEnabled &&
        _twoFingerTravel.dy.abs() > _tiltLockTravel &&
        _twoFingerTravel.dy.abs() > 2 * _twoFingerTravel.dx.abs()) {
      return _TwoFingerMode.tilt;
    }
    return _TwoFingerMode.undecided;
  }

  /// Zoom/rotate activation within a pinch, mirroring the SDK gating:
  /// whichever crosses its threshold first wins; rotation stays disabled
  /// once zoom won (disableRotateWhenScaling) and zoom needs a much larger
  /// scale change once rotation won (increaseScaleThresholdWhenRotating).
  void _updatePinchActivation(ScaleUpdateDetails details) {
    final scaleSinceStart = (details.scale - 1).abs();
    final rotationSinceStart = details.rotation.abs() * 180 / pi;
    if (!_zoomActive && !_rotateActive) {
      final rotateHit =
          _config.rotateEnabled &&
          rotationSinceStart >= _rotateActivationDegrees;
      final zoomHit =
          _config.zoomEnabled && scaleSinceStart >= _zoomActivationScale;
      if (rotateHit &&
          (!zoomHit ||
              rotationSinceStart / _rotateActivationDegrees >=
                  scaleSinceStart / _zoomActivationScale)) {
        _rotateActive = true;
      } else if (zoomHit) {
        _zoomActive = true;
      }
    } else if (_rotateActive && !_zoomActive) {
      if (_config.zoomEnabled &&
          scaleSinceStart >= _zoomActivationScaleWhileRotating) {
        _zoomActive = true;
      }
    }
  }

  void _accumulateGesturePan(Offset delta, int pointerCount) {
    _gesturePanTravel += delta;
    final threshold = pointerCount >= 2
        ? _panDismissThresholdMultiFinger
        : _panDismissThreshold;
    if (_gesturePanTravel.distance > threshold) {
      _onUserPan();
    }
  }

  // Taps.

  void onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void onDoubleTap() {
    final session = _session();
    final position = _doubleTapPosition;
    if (session == null ||
        position == null ||
        !_config.doubleClickZoomEnabled) {
      return;
    }
    session.send(
      ScaleByCommand(
        session.id,
        2,
        anchorX: position.dx,
        anchorY: position.dy,
        durationMs: _tapZoomDurationMs,
      ),
    );
  }

  void onTapUp(TapUpDetails details) {
    final position = details.localPosition;
    unawaited(() async {
      final session = _session();
      if (session == null) return;
      // A tap stops an ongoing fling or animation, like the SDK's
      // onSingleTapUp.
      session.send(CancelTransitionsCommand(session.id));
      try {
        final latLng = await session.query(
          LatLngForPixelQuery(session.id, position.dx, position.dy),
        );
        // Hit-tests the interactive layers and emits the feature tap and/or
        // the map click.
        await _features.handleTap(
          Point<double>(position.dx, position.dy),
          LatLng(latLng.latitude, latLng.longitude),
        );
      } catch (error) {
        // The map can be torn down (or the query fail) between the unproject
        // and the hit-test; without this net the unawaited chain surfaces an
        // unhandled async error, unlike the drag paths, which all catch.
        debugPrint('[maplibre_gl_native] tap handling failed: $error');
      }
    }());
  }

  Future<void> _emitTapEvent(
    Offset position,
    void Function(Map<String, dynamic>) sink,
  ) async {
    final session = _session();
    if (session == null) return;
    try {
      final latLng = await session.query(
        LatLngForPixelQuery(session.id, position.dx, position.dy),
      );
      sink(<String, dynamic>{
        'point': Point<double>(position.dx, position.dy),
        'latLng': LatLng(latLng.latitude, latLng.longitude),
      });
    } catch (error) {
      // Same net as the drag paths: the session can die mid-query and the
      // caller does not await this future.
      debugPrint('[maplibre_gl_native] tap event failed: $error');
    }
  }

  // Long press and feature drag.
  void onLongPressStart(LongPressStartDetails details) {
    void emitLongClick() =>
        unawaited(_emitTapEvent(details.localPosition, _onMapLongClick));
    // Press-and-hold on a draggable feature grabs it (the drag session then
    // follows the finger); anywhere else it is the map long-click.
    if (_features.dragEnabled) {
      _dragResolving = true;
      _dragPosition = details.localPosition;
      unawaited(
        _resolveDragCandidate(
          _pointerDownPosition ?? details.localPosition,
          ++_dragGeneration,
          onMiss: emitLongClick,
        ),
      );
      return;
    }
    emitLongClick();
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_drag == null && !_dragResolving) return;
    _dragPosition = details.localPosition;
    if (_drag != null) _pumpDrag();
  }

  void onLongPressEnd(LongPressEndDetails details) {
    if (_dragResolving) {
      _dragResolving = false;
      _dragGeneration++;
      _bufferedPanDelta = Offset.zero;
    }
    _endDrag();
  }

  Future<void> _resolveDragCandidate(
    Offset position,
    int generation, {
    required void Function() onMiss,
  }) async {
    final point = Point<double>(position.dx, position.dy);
    Map<String, dynamic>? feature;
    GeoPoint? origin;
    try {
      feature = await _features.queryDraggableFeature(point);
      final session = _session();
      if (feature != null && session != null) {
        origin = await session.query(
          LatLngForPixelQuery(session.id, position.dx, position.dy),
        );
      }
    } catch (error) {
      debugPrint('[maplibre_gl_native] drag hit-test failed: $error');
    }
    // The gesture may have ended or been superseded while resolving.
    if (generation != _dragGeneration || !_dragResolving || !_mounted()) {
      return;
    }
    _dragResolving = false;
    if (feature == null || origin == null) {
      onMiss();
      return;
    }
    final originLatLng = LatLng(origin.latitude, origin.longitude);
    _drag = _DragSession(
      feature: feature,
      origin: originLatLng,
      last: originLatLng,
      lastPoint: point,
    );
    _features.emitDrag(
      feature: feature,
      point: point,
      origin: originLatLng,
      current: originLatLng,
      delta: const LatLng(0, 0),
      eventType: 'start',
    );
    // Align the feature with the finger: _dragPosition already tracks the
    // pointer (including movement that arrived while the hit-test was in
    // flight), so one pump catches up from the grab point.
    _bufferedPanDelta = Offset.zero;
    if (_dragPosition != position) _pumpDrag();
  }

  void _flushBufferedPan() {
    final session = _session();
    final delta = _bufferedPanDelta;
    _bufferedPanDelta = Offset.zero;
    if (session != null && _config.scrollEnabled && delta != Offset.zero) {
      _accumulateGesturePan(delta, 1);
      session.send(MoveByCommand(session.id, delta.dx, delta.dy));
    }
  }

  /// Emits one coalesced drag event for the latest pointer position; queries
  /// in flight are never stacked, only the newest position is unprojected.
  void _pumpDrag() {
    if (_dragQueryInFlight) {
      _dragDirty = true;
      return;
    }
    final drag = _drag;
    final session = _session();
    final position = _dragPosition;
    if (drag == null || session == null || position == null) return;
    _dragQueryInFlight = true;
    unawaited(
      session
          .query(LatLngForPixelQuery(session.id, position.dx, position.dy))
          .then((latLng) {
            _dragQueryInFlight = false;
            final active = _drag;
            if (!_mounted() || active == null) return;
            final current = LatLng(latLng.latitude, latLng.longitude);
            final delta = LatLng(
              current.latitude - active.last.latitude,
              current.longitude - active.last.longitude,
            );
            active.last = current;
            active.lastPoint = Point<double>(position.dx, position.dy);
            _features.emitDrag(
              feature: active.feature,
              point: active.lastPoint,
              origin: active.origin,
              current: current,
              delta: delta,
              eventType: 'drag',
            );
            if (_dragDirty) {
              _dragDirty = false;
              _pumpDrag();
            }
          })
          .catchError((Object error) {
            _dragQueryInFlight = false;
            debugPrint('[maplibre_gl_native] drag update failed: $error');
          }),
    );
  }

  void _endDrag() {
    final drag = _drag;
    _drag = null;
    _dragDirty = false;
    if (drag == null) return;
    _features.emitDrag(
      feature: drag.feature,
      point: drag.lastPoint,
      origin: drag.origin,
      current: drag.last,
      delta: const LatLng(0, 0),
      eventType: 'end',
    );
  }
}

/// Disambiguated two-finger gesture for one scale-gesture sequence.
enum _TwoFingerMode { undecided, pinch, tilt }

/// State of one active feature drag (a one-finger pan captured by a
/// draggable feature instead of moving the camera).
class _DragSession {
  _DragSession({
    required this.feature,
    required this.origin,
    required this.last,
    required this.lastPoint,
  });

  final Map<String, dynamic> feature;
  final LatLng origin;
  LatLng last;
  Point<double> lastPoint;
}
