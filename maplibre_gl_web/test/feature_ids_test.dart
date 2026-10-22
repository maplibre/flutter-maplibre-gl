// What web does so that feature ids come back as they are in the data:
// maplibre-gl-js keeps only integer ids, so the plugin copies each id into a
// property and reads it back. Pure Dart, so it runs on the VM.
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/feature_ids.dart';

void main() {
  const idExpression = [
    'coalesce',
    ['get', featureIdProperty],
    ['id'],
  ];

  group('withFeatureIds', () {
    test("makes ['id'] read the id in the data, wherever it is", () {
      expect(withFeatureIds(['id']), idExpression);
      expect(
        withFeatureIds([
          'all',
          [
            '==',
            ['id'],
            'poi-12',
          ],
          [
            'match',
            ['id'],
            [2, 3],
            true,
            false,
          ],
        ]),
        [
          'all',
          ['==', idExpression, 'poi-12'],
          [
            'match',
            idExpression,
            [2, 3],
            true,
            false,
          ],
        ],
      );
    });

    test('rewrites layer properties and keeps their type', () {
      final properties = <String, dynamic>{
        'circle-radius': 4,
        'circle-color': [
          'case',
          [
            '==',
            ['id'],
            2.5,
          ],
          'red',
          'blue',
        ],
      };

      final rewritten = withFeatureIds(properties);

      expect(rewritten, isA<Map<String, dynamic>>());
      expect(rewritten, {
        'circle-radius': 4,
        'circle-color': [
          'case',
          ['==', idExpression, 2.5],
          'red',
          'blue',
        ],
      });
      // The app's own value is left as it was.
      expect((properties['circle-color'] as List)[1], [
        '==',
        ['id'],
        2.5,
      ]);
    });

    test('leaves what holds no id expression as it is', () {
      final filter = [
        '==',
        ['get', 'id'],
        2,
      ];
      final legacy = ['==', 'id', 2];
      final literal = [
        'literal',
        ['id'],
      ];

      expect(withFeatureIds(filter), same(filter));
      expect(withFeatureIds(legacy), same(legacy));
      expect(withFeatureIds(literal), same(literal));
      expect(withFeatureIds(null), isNull);
      expect(withFeatureIds(true), isTrue);
    });

    test("leaves a match label ['id'], which is the text id", () {
      final byLabel = [
        'match',
        ['get', 'field'],
        ['id'],
        1,
        0,
      ];
      expect(withFeatureIds(byLabel), same(byLabel));

      // The input, the outputs and the fallback are expressions.
      expect(
        withFeatureIds([
          'match',
          ['id'],
          ['id'],
          ['id'],
          'poi-12',
          ['id'],
          ['id'],
        ]),
        [
          'match',
          idExpression,
          ['id'],
          idExpression,
          'poi-12',
          idExpression,
          idExpression,
        ],
      );
    });

    test('leaves the GeoJSON of within and distance as it is', () {
      final geometry = {
        'type': 'Feature',
        'geometry': null,
        'properties': {
          'tags': ['id'],
        },
      };
      final within = ['within', geometry];
      final distance = ['distance', geometry];

      expect(withFeatureIds(within), same(within));
      expect(withFeatureIds(distance), same(distance));
    });

    test('leaves the legacy syntax as it is', () {
      final legacy = [
        'all',
        ['==', r'$id', 'poi-12'],
        ['in', r'$id', 1, 2],
        ['has', r'$id'],
      ];

      expect(withFeatureIds(legacy), same(legacy));
    });

    test('rewrites an expression once, however many times it runs', () {
      final once = withFeatureIds([
        '==',
        ['id'],
        2,
      ]);

      expect(withFeatureIds(once), same(once));
      expect(withFeatureIds(idExpression), same(idExpression));
    });
  });

  test('withoutFeatureIds gives back what withFeatureIds took', () {
    final filter = [
      'any',
      [
        '==',
        ['id'],
        '2',
      ],
      [
        'in',
        ['id'],
        [
          'literal',
          [1, 2],
        ],
      ],
    ];
    final layer = {
      'id': 'layer',
      'filter': filter,
      'paint': {
        'circle-radius': [
          'case',
          [
            '==',
            ['id'],
            2,
          ],
          8,
          4,
        ],
      },
    };

    expect(withoutFeatureIds(withFeatureIds(filter)), filter);
    expect(withoutFeatureIds(withFeatureIds(layer)), layer);
    expect(withoutFeatureIds(filter), same(filter));
  });

  group('takeFeatureId', () {
    test('answers the id in the data and drops the property', () {
      final properties = {featureIdProperty: 'poi-12', 'name': 'a'};

      expect(takeFeatureId(0, properties), 'poi-12');
      expect(properties, {'name': 'a'});
    });

    test('answers the id maplibre-gl-js holds without the property', () {
      expect(takeFeatureId(7, {'name': 'a'}), 7);
      expect(takeFeatureId(7, null), 7);
      expect(takeFeatureId(null, {}), isNull);
    });

    test('answers a whole number as an int', () {
      expect(takeFeatureId(2.0, null), isA<int>());
      expect(takeFeatureId(null, {featureIdProperty: 2.0}), isA<int>());
      expect(takeFeatureId(2.5, null), 2.5);
      expect(takeFeatureId('2', null), '2');
    });
  });

  group('withoutFeatureIdsInSource', () {
    test('drops the property the plugin added', () {
      final source = <String, dynamic>{
        'type': 'geojson',
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'id': 'a',
              'properties': {featureIdProperty: 'a', 'name': 'a'},
              'geometry': null,
            },
            {'type': 'Feature', 'properties': null, 'geometry': null},
          ],
        },
      };

      expect(withoutFeatureIdsInSource(source), {
        'type': 'geojson',
        'data': {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'id': 'a',
              'properties': {'name': 'a'},
              'geometry': null,
            },
            {'type': 'Feature', 'properties': null, 'geometry': null},
          ],
        },
      });
    });

    test('handles a lone Feature and data from a url', () {
      expect(
        withoutFeatureIdsInSource({
          'type': 'geojson',
          'data': {
            'type': 'Feature',
            'id': 2,
            'properties': {featureIdProperty: 2},
            'geometry': null,
          },
        }),
        {
          'type': 'geojson',
          'data': {
            'type': 'Feature',
            'id': 2,
            'properties': <String, dynamic>{},
            'geometry': null,
          },
        },
      );
      expect(
        withoutFeatureIdsInSource({
          'type': 'geojson',
          'data': 'https://example.com/a.json',
        }),
        {'type': 'geojson', 'data': 'https://example.com/a.json'},
      );
    });

    test('keeps a promoteId of the app, and other sources as they are', () {
      final own = {'type': 'geojson', 'promoteId': 'ref', 'data': 'url'};
      final vector = {'type': 'vector', 'promoteId': featureIdProperty};

      expect(withoutFeatureIdsInSource(own), {
        'type': 'geojson',
        'promoteId': 'ref',
        'data': 'url',
      });
      expect(withoutFeatureIdsInSource(vector), same(vector));
      expect(vector, contains('promoteId'));
    });
  });
}
