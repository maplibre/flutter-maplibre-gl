import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/presentation/platform/camera_update_codec.dart';
import 'package:maplibre_gl_native/src/protocol/protocol.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

/// The CameraUpdate -> EngineCommand translation, exercised through the real
/// maplibre_gl `CameraUpdate` constructors so the test also pins the
/// positional `toJson()` shapes the codec decodes. The traps this guards:
/// the [[swLat, swLng], [neLat, neLng]] axis order, the scrollBy sign
/// negation, and the zoom-delta-to-scale-factor conversion.
void main() {
  const sessionId = 7;

  EngineCommand encode(
    CameraUpdate update, {
    double? durationMs,
    List<double>? easing,
  }) => cameraUpdateCommand(
    update,
    sessionId: sessionId,
    durationMs: durationMs,
    easing: easing,
  );

  group('cameraUpdateCommand', () {
    test('newCameraPosition without a duration is an instant jump', () {
      final command = encode(
        CameraUpdate.newCameraPosition(
          const CameraPosition(
            target: LatLng(45.5, 9.2),
            zoom: 12,
            bearing: 30,
            tilt: 40,
          ),
        ),
      );
      final jump = command as JumpToCommand;
      expect(jump.sessionId, sessionId);
      expect(jump.camera.latitude, 45.5);
      expect(jump.camera.longitude, 9.2);
      expect(jump.camera.zoom, 12);
      expect(jump.camera.bearing, 30);
      // maplibre_gl calls it tilt, the engine calls it pitch.
      expect(jump.camera.pitch, 40);
    });

    test('newCameraPosition with a duration eases, carrying the easing', () {
      final command = encode(
        CameraUpdate.newCameraPosition(
          const CameraPosition(target: LatLng(1, 2)),
        ),
        durationMs: 250,
        easing: const [0, 0, 1, 1],
      );
      final ease = command as EaseToCommand;
      expect(ease.durationMs, 250);
      expect(ease.easing, const [0, 0, 1, 1]);
      expect(ease.camera.latitude, 1);
      expect(ease.camera.longitude, 2);
    });

    test('newLatLng moves only the target, leaving the rest unchanged', () {
      final command = encode(CameraUpdate.newLatLng(const LatLng(-33.9, 18.4)));
      final jump = command as JumpToCommand;
      expect(jump.camera.latitude, -33.9);
      expect(jump.camera.longitude, 18.4);
      expect(jump.camera.zoom, isNull);
      expect(jump.camera.bearing, isNull);
      expect(jump.camera.pitch, isNull);
    });

    test('newLatLngZoom carries target and zoom only', () {
      final command = encode(
        CameraUpdate.newLatLngZoom(const LatLng(52.5, 13.4), 11),
      );
      final jump = command as JumpToCommand;
      expect(jump.camera.latitude, 52.5);
      expect(jump.camera.longitude, 13.4);
      expect(jump.camera.zoom, 11);
      expect(jump.camera.bearing, isNull);
      expect(jump.camera.pitch, isNull);
    });

    test('newLatLngBounds decodes the [[swLat,swLng],[neLat,neLng]] order '
        'and the LTRB padding', () {
      final command = encode(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: const LatLng(-10, 20),
            northeast: const LatLng(30, 40),
          ),
          left: 1,
          top: 2,
          right: 3,
          bottom: 4,
        ),
        durationMs: 500,
        easing: const [0.42, 0, 0.58, 1],
      );
      final fit = command as FitBoundsCommand;
      expect(fit.sessionId, sessionId);
      // A lat/lng swap or a corner swap would land here first.
      expect(fit.bounds.south, -10);
      expect(fit.bounds.west, 20);
      expect(fit.bounds.north, 30);
      expect(fit.bounds.east, 40);
      expect(fit.paddingLeft, 1);
      expect(fit.paddingTop, 2);
      expect(fit.paddingRight, 3);
      expect(fit.paddingBottom, 4);
      expect(fit.durationMs, 500);
      expect(fit.easing, const [0.42, 0, 0.58, 1]);
    });

    test('newLatLngBounds without a duration is an instant fit', () {
      final command = encode(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: const LatLng(0, 0),
            northeast: const LatLng(1, 1),
          ),
        ),
      );
      final fit = command as FitBoundsCommand;
      expect(fit.durationMs, isNull);
      expect(fit.paddingLeft, 0);
      expect(fit.paddingBottom, 0);
    });

    test('scrollBy negates both deltas (Android moveBy semantics: scrolling '
        'the map content moves the camera the other way)', () {
      final command = encode(
        CameraUpdate.scrollBy(50, 75),
        durationMs: 100,
      );
      final move = command as MoveByCommand;
      expect(move.dx, -50);
      expect(move.dy, -75);
      expect(move.durationMs, 100);
    });

    test('zoomBy converts the zoom delta to a scale factor (2^delta)', () {
      final command = encode(CameraUpdate.zoomBy(2));
      final scale = command as ScaleByCommand;
      expect(scale.factor, 4);
      expect(scale.anchorX, isNull);
      expect(scale.anchorY, isNull);
    });

    test('a negative zoomBy scales below one', () {
      final command = encode(CameraUpdate.zoomBy(-1));
      expect((command as ScaleByCommand).factor, 0.5);
    });

    test('a fractional zoomBy is a fractional power of two', () {
      final command = encode(CameraUpdate.zoomBy(0.5));
      expect((command as ScaleByCommand).factor, closeTo(1.41421356, 1e-8));
    });

    test('zoomBy with a focus anchors the scale at that screen point', () {
      final command = encode(
        CameraUpdate.zoomBy(1, const Offset(15, 25)),
        durationMs: 200,
      );
      final scale = command as ScaleByCommand;
      expect(scale.factor, 2);
      expect(scale.anchorX, 15);
      expect(scale.anchorY, 25);
      expect(scale.durationMs, 200);
    });

    test('zoomIn doubles and zoomOut halves the scale, unanchored', () {
      final zoomIn = encode(CameraUpdate.zoomIn()) as ScaleByCommand;
      expect(zoomIn.factor, 2);
      expect(zoomIn.anchorX, isNull);
      final zoomOut = encode(CameraUpdate.zoomOut()) as ScaleByCommand;
      expect(zoomOut.factor, 0.5);
    });

    test('zoomTo sets only the zoom', () {
      final command = encode(CameraUpdate.zoomTo(14));
      final jump = command as JumpToCommand;
      expect(jump.camera.zoom, 14);
      expect(jump.camera.latitude, isNull);
      expect(jump.camera.longitude, isNull);
      expect(jump.camera.bearing, isNull);
      expect(jump.camera.pitch, isNull);
    });

    test('bearingTo sets only the bearing', () {
      final command = encode(CameraUpdate.bearingTo(90), durationMs: 300);
      final ease = command as EaseToCommand;
      expect(ease.camera.bearing, 90);
      expect(ease.camera.latitude, isNull);
      expect(ease.camera.zoom, isNull);
      expect(ease.camera.pitch, isNull);
    });

    test('tiltTo sets only the pitch', () {
      final command = encode(CameraUpdate.tiltTo(60));
      final jump = command as JumpToCommand;
      expect(jump.camera.pitch, 60);
      expect(jump.camera.bearing, isNull);
      expect(jump.camera.latitude, isNull);
    });
  });

  group('easingCurve', () {
    test('defaults to ease-in-out when no interpolation is given', () {
      expect(easingCurve(null), const [0.42, 0, 0.58, 1]);
    });

    test('maps every interpolation to its bezier', () {
      expect(
        easingCurve(CameraAnimationInterpolation.linear),
        const [0, 0, 1, 1],
      );
      expect(
        easingCurve(CameraAnimationInterpolation.easeInOut),
        const [0.42, 0, 0.58, 1],
      );
      expect(
        easingCurve(CameraAnimationInterpolation.easeOut),
        const [0, 0, 0.58, 1],
      );
      expect(
        easingCurve(CameraAnimationInterpolation.fastOutLinearIn),
        const [0.4, 0, 1, 1],
      );
    });
  });
}
