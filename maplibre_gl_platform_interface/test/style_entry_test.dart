import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('shapeStyleProperties', () {
    test('turns integral doubles into ints and keeps fractions', () {
      expect(
        shapeStyleProperties({'minzoom': 4.0, 'fill-opacity': 0.5, 'id': 'a'}),
        {'minzoom': 4, 'fill-opacity': 0.5, 'id': 'a'},
      );
      expect(shapeStyleProperties({'minzoom': 4.0})['minzoom'], isA<int>());
    });

    test('shapes values inside lists and maps', () {
      expect(
        shapeStyleProperties({
          'paint': {
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              1.0,
              2.5,
            ],
          },
        }),
        {
          'paint': {
            'line-width': [
              'interpolate',
              ['linear'],
              ['zoom'],
              1,
              2.5,
            ],
          },
        },
      );
    });

    test('leaves non-finite doubles alone', () {
      final shaped = shapeStyleProperties({
        'nan': double.nan,
        'inf': double.infinity,
      });

      expect((shaped['nan'] as double).isNaN, isTrue);
      expect(shaped['inf'], double.infinity);
    });

    test('turns top-level keys into strings', () {
      expect(shapeStyleProperties({1: 'one'}), {'1': 'one'});
    });
  });
}
