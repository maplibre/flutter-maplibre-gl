import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/camera_target_bounds.dart';

void main() {
  final usa = LatLngBounds(
    southwest: const LatLng(25, -125),
    northeast: const LatLng(49, -67),
  );

  group('clampCameraTarget', () {
    test('a target inside the bounds is left alone', () {
      expect(clampCameraTarget(40, -100, usa), isNull);
    });

    test('a target on the edge is left alone', () {
      expect(clampCameraTarget(25, -67, usa), isNull);
    });

    test('latitude and longitude are clamped apart', () {
      final north = clampCameraTarget(60, -100, usa)!;
      expect(north.lat, 49);
      expect(north.lng, -100);

      final west = clampCameraTarget(40, -140, usa)!;
      expect(west.lat, 40);
      expect(west.lng, -125);
    });

    test('a corner target goes to the nearest corner', () {
      final next = clampCameraTarget(0, 10, usa)!;
      expect(next.lat, 25);
      expect(next.lng, -67);
    });

    test('a target in another world copy keeps its copy', () {
      // -100 + 360, inside the bounds one world over.
      expect(clampCameraTarget(40, 260, usa), isNull);

      final next = clampCameraTarget(40, 360 + 10, usa)!;
      expect(next.lng, closeTo(360 - 67, 1e-9));
    });

    test('longitudes in any order span the longitudes between them', () {
      // As Android's LatLngBounds.Builder: never across the antimeridian.
      final swapped = LatLngBounds(
        southwest: const LatLng(-20, 170),
        northeast: const LatLng(20, -170),
      );
      expect(clampCameraTarget(0, 0, swapped), isNull);
      expect(clampCameraTarget(30, 175, swapped)!.lng, 170);
      expect(clampCameraTarget(30, 175, swapped)!.lat, 20);
      expect(clampCameraTarget(0, -175, swapped)!.lng, -170);
    });
  });
}
