import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('buildFeatureCollection', () {
    test('wraps features in FeatureCollection', () {
      final features = [
        {'type': 'Feature', 'geometry': null, 'properties': {}},
      ];
      final result = buildFeatureCollection(features);
      expect(result['type'], 'FeatureCollection');
      expect(result['features'], features);
    });

    test('empty list produces empty FeatureCollection', () {
      final result = buildFeatureCollection([]);
      expect(result['type'], 'FeatureCollection');
      expect(result['features'], isEmpty);
    });

    test('multiple features', () {
      final features = [
        {'type': 'Feature', 'properties': {'id': '1'}},
        {'type': 'Feature', 'properties': {'id': '2'}},
      ];
      final result = buildFeatureCollection(features);
      expect((result['features'] as List).length, 2);
    });
  });

  group('getRandomString', () {
    test('default length is 10', () {
      final result = getRandomString();
      expect(result.length, 10);
    });

    test('custom length', () {
      expect(getRandomString(5).length, 5);
      expect(getRandomString(20).length, 20);
    });

    test('produces different strings', () {
      final a = getRandomString();
      final b = getRandomString();
      // Statistically extremely unlikely to be equal
      expect(a, isNot(equals(b)));
    });

    test('contains only alphanumeric characters', () {
      final result = getRandomString(100);
      expect(
        result,
        matches(RegExp(r'^[A-Za-z0-9]+$')),
      );
    });
  });
}
