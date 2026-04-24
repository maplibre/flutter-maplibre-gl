import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/camera_easing_math.dart';

void main() {
  group('easingImplFor', () {
    test('linear is the identity', () {
      final f = easingImplFor(CameraAnimationInterpolation.linear);
      expect(f(0), 0);
      expect(f(0.25), closeTo(0.25, 1e-9));
      expect(f(0.5), closeTo(0.5, 1e-9));
      expect(f(0.75), closeTo(0.75, 1e-9));
      expect(f(1), 1);
    });

    test('easeInOut pins endpoints and is symmetric at t=0.5', () {
      final f = easingImplFor(CameraAnimationInterpolation.easeInOut);
      expect(f(0), 0);
      expect(f(1), 1);
      expect(f(0.5), closeTo(0.5, 1e-3));
      expect(f(0.25) + f(0.75), closeTo(1, 1e-3));
    });

    test('easeOut decelerates — first half covers more than half', () {
      final f = easingImplFor(CameraAnimationInterpolation.easeOut);
      expect(f(0), 0);
      expect(f(1), 1);
      expect(f(0.5), greaterThan(0.5));
    });

    test('fastOutLinearIn accelerates — first half covers less than half', () {
      final f = easingImplFor(CameraAnimationInterpolation.fastOutLinearIn);
      expect(f(0), 0);
      expect(f(1), 1);
      expect(f(0.5), lessThan(0.5));
    });

    test('every curve is weakly monotonic over a dense sample', () {
      for (final i in CameraAnimationInterpolation.values) {
        final f = easingImplFor(i);
        var prev = f(0);
        for (var k = 1; k <= 100; k++) {
          final y = f(k / 100);
          expect(
            y,
            greaterThanOrEqualTo(prev - 1e-6),
            reason: '$i not monotonic at k=$k',
          );
          prev = y;
        }
      }
    });
  });

  group('cubicBezier', () {
    test('clamps input below 0 to 0 and above 1 to 1', () {
      expect(cubicBezier(-0.5, 0.42, 0, 0.58, 1), 0);
      expect(cubicBezier(1.5, 0.42, 0, 0.58, 1), 1);
    });

    test('agrees with the pure identity when control points are (0,0,1,1)', () {
      // cubic-bezier(0,0,1,1) is the CSS "linear" curve
      for (final u in [0.0, 0.1, 0.5, 0.9, 1.0]) {
        expect(cubicBezier(u, 0, 0, 1, 1), closeTo(u, 1e-6));
      }
    });
  });
}
