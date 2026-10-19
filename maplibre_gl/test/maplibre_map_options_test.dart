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

  group('panInertia', () {
    Map<String, dynamic> toMap(MapLibreMap map) =>
        MapLibreMapOptions.fromWidget(map).toMap();

    Map<String, dynamic> diff(MapLibreMap from, MapLibreMap to) =>
        MapLibreMapOptions.fromWidget(
          from,
        ).updatesMap(MapLibreMapOptions.fromWidget(to));

    test('defaults to normal', () {
      expect(MapLibreMap().panInertia, PanInertia.normal);
      expect(toMap(MapLibreMap())['panInertia'], PanInertia.normal.index);
    });

    test('sends the chosen level', () {
      for (final inertia in PanInertia.values) {
        expect(
          toMap(MapLibreMap(panInertia: inertia))['panInertia'],
          inertia.index,
        );
      }
    });

    test('a change is sent with the other gesture options', () {
      // Web applies the inertia when it enables drag-pan, so it needs
      // scrollGesturesEnabled in the same update.
      final update = diff(
        MapLibreMap(),
        MapLibreMap(panInertia: PanInertia.short),
      );

      expect(update['panInertia'], PanInertia.short.index);
      expect(update['scrollGesturesEnabled'], isTrue);
      expect(update['rotateGesturesEnabled'], isTrue);
    });

    test('a gesture change resends the inertia', () {
      final update = diff(
        MapLibreMap(panInertia: PanInertia.none),
        MapLibreMap(panInertia: PanInertia.none, scrollGesturesEnabled: false),
      );

      expect(update['scrollGesturesEnabled'], isFalse);
      expect(update['panInertia'], PanInertia.none.index);
    });

    test('is not sent again when unchanged', () {
      final update = diff(
        MapLibreMap(panInertia: PanInertia.short),
        MapLibreMap(panInertia: PanInertia.short),
      );

      expect(update, isEmpty);
    });
  });

  group('MapLibreMap.hapticFeedbackEnabled', () {
    test('defaults to true and is sent to the platform', () {
      final options = MapLibreMapOptions.fromWidget(MapLibreMap());

      expect(options.toMap()['hapticFeedbackEnabled'], isTrue);
    });

    test('false is sent to the platform', () {
      final options = MapLibreMapOptions.fromWidget(
        MapLibreMap(hapticFeedbackEnabled: false),
      );

      expect(options.toMap()['hapticFeedbackEnabled'], isFalse);
    });

    test('updatesMap reports a change and nothing else', () {
      final before = MapLibreMapOptions.fromWidget(MapLibreMap());
      final after = MapLibreMapOptions.fromWidget(
        MapLibreMap(hapticFeedbackEnabled: false),
      );

      final diff = before.updatesMap(after);

      expect(diff, {'hapticFeedbackEnabled': false});
    });
  });

  group('symbolPlacementTransitionsEnabled', () {
    test('is sent on, the MapLibre default, unless set', () {
      final options = MapLibreMapOptions.fromWidget(MapLibreMap());
      expect(options.toMap()['symbolPlacementTransitionsEnabled'], isTrue);
    });

    test('is sent off when set off, and only as an update when it changed', () {
      final on = MapLibreMapOptions.fromWidget(MapLibreMap());
      final off = MapLibreMapOptions.fromWidget(
        MapLibreMap(symbolPlacementTransitionsEnabled: false),
      );

      expect(off.toMap()['symbolPlacementTransitionsEnabled'], isFalse);
      expect(on.updatesMap(off), {'symbolPlacementTransitionsEnabled': false});
      expect(off.updatesMap(off), isEmpty);
    });
  });

  group('attributionEnabled', () {
    test('is sent on unless set', () {
      final options = MapLibreMapOptions.fromWidget(MapLibreMap());
      expect(options.toMap()['attributionEnabled'], isTrue);
    });

    test('is sent off when set off, and only as an update when it changed', () {
      final on = MapLibreMapOptions.fromWidget(MapLibreMap());
      final off = MapLibreMapOptions.fromWidget(
        MapLibreMap(attributionEnabled: false),
      );

      expect(off.toMap()['attributionEnabled'], isFalse);
      expect(on.updatesMap(off), {'attributionEnabled': false});
      expect(off.updatesMap(on), {'attributionEnabled': true});
      expect(off.updatesMap(off), isEmpty);
    });
  });
}
