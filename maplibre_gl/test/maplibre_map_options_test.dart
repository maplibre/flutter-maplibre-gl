import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('MapLibreMapOptions.updatesMap', () {
    test(
      'returns empty diff when only nested-list options (cameraTargetBounds) are equal by value',
      () {
        // Two MapLibreMap widgets with the *same* cameraTargetBounds value
        // (deeply nested list when serialized to JSON). The diff between
        // their derived MapLibreMapOptions must be empty: nothing changed,
        // so no platform update should be triggered.
        final bounds = LatLngBounds(
          southwest: const LatLng(10, 20),
          northeast: const LatLng(30, 40),
        );

        final mapA = MapLibreMap(
          cameraTargetBounds: CameraTargetBounds(bounds),
        );
        final mapB = MapLibreMap(
          cameraTargetBounds: CameraTargetBounds(
            LatLngBounds(
              southwest: const LatLng(10, 20),
              northeast: const LatLng(30, 40),
            ),
          ),
        );

        final optionsA = MapLibreMapOptions.fromWidget(mapA);
        final optionsB = MapLibreMapOptions.fromWidget(mapB);

        final diff = optionsA.updatesMap(optionsB);

        expect(
          diff,
          isEmpty,
          reason:
              'Nested-list values that are deeply equal must be detected as '
              'unchanged. Otherwise the platform receives spurious updates '
              'on every rebuild.',
        );
      },
    );

    test('detects an actual cameraTargetBounds change', () {
      final mapA = MapLibreMap(
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            southwest: const LatLng(10, 20),
            northeast: const LatLng(30, 40),
          ),
        ),
      );
      final mapB = MapLibreMap(
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            southwest: const LatLng(11, 21),
            northeast: const LatLng(31, 41),
          ),
        ),
      );

      final diff = MapLibreMapOptions.fromWidget(
        mapA,
      ).updatesMap(MapLibreMapOptions.fromWidget(mapB));

      expect(diff.containsKey('cameraTargetBounds'), isTrue);
    });

    test('returns empty diff when no widget property changed at all', () {
      final mapA = MapLibreMap();
      final mapB = MapLibreMap();

      final diff = MapLibreMapOptions.fromWidget(
        mapA,
      ).updatesMap(MapLibreMapOptions.fromWidget(mapB));

      expect(diff, isEmpty);
    });
  });
}
