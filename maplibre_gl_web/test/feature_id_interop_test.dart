// Inspects real JS objects, so it needs a browser:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/feature_id_interop.dart';
import 'package:maplibre_gl_web/src/feature_ids.dart';

/// What maplibre-gl-js is handed so that a GeoJSON source keeps the ids of its
/// data: each feature carries its id in a property, and the source takes its
/// ids from there. A key spelled differently from the library's would be a
/// silent no-op on a live map, so it is asserted here on JS objects.
void main() {
  group('copyFeatureId', () {
    test('copies the id into the properties', () {
      final feature =
          {
                'type': 'Feature',
                'id': 'poi-12',
                'properties': {'name': 'a'},
              }.jsify()!
              as JSObject;

      copyFeatureId(feature);

      expect(feature.dartify(), {
        'type': 'Feature',
        'id': 'poi-12',
        'properties': {'name': 'a', featureIdProperty: 'poi-12'},
      });
    });

    test('creates the properties of a feature without them', () {
      final feature = {'type': 'Feature', 'id': 2.5}.jsify()! as JSObject;

      copyFeatureId(feature);

      expect(feature.dartify(), {
        'type': 'Feature',
        'id': 2.5,
        'properties': {featureIdProperty: 2.5},
      });
    });

    test('leaves a feature without an id as it is', () {
      final feature =
          {'type': 'Feature', 'properties': {}}.jsify()! as JSObject;

      copyFeatureId(feature);

      expect(feature.dartify(), {'type': 'Feature', 'properties': {}});
    });
  });

  group('promoteFeatureIds', () {
    setUp(debugResetFeatureIdWarning);

    /// A GeoJSON source created with the options [promoteId] and
    /// [generateId], now using the promoteId [current], as maplibre-gl-js
    /// holds it. Without [fields], it lacks the fields the plugin sets.
    JSObject source({
      String? promoteId,
      bool? generateId,
      String? current,
      bool fields = true,
    }) {
      final source =
          {
                'type': 'geojson',
                if (fields) ...{
                  'promoteId': current,
                  'workerOptions': {
                    'geojsonVtOptions': {
                      'promoteId': current,
                      'generateId': generateId ?? false,
                    },
                  },
                },
              }.jsify()!
              as JSObject;
      source.setProperty(
        'serialize'.toJS,
        (() =>
                {
                  'type': 'geojson',
                  if (promoteId != null) 'promoteId': promoteId,
                  if (generateId != null) 'generateId': generateId,
                }.jsify())
            .toJS,
      );
      return source;
    }

    /// The promoteId of [source] and the one its worker gets.
    List<Object?> promoteIds(JSObject source) => [
      source.getProperty<JSAny?>('promoteId'.toJS).dartify(),
      source
          .getProperty<JSObject>('workerOptions'.toJS)
          .getProperty<JSObject>('geojsonVtOptions'.toJS)
          .getProperty<JSAny?>('promoteId'.toJS)
          .dartify(),
    ];

    /// The console warnings while the test runs.
    List<String> warnings() {
      final warnings = <String>[];
      final console = globalContext.getProperty<JSObject>('console'.toJS);
      final warn = console.getProperty<JSFunction>('warn'.toJS);
      console.setProperty(
        'warn'.toJS,
        ((JSAny? message) {
          warnings.add('${message.dartify()}');
        }).toJS,
      );
      addTearDown(() => console.setProperty('warn'.toJS, warn));
      return warnings;
    }

    test('switches a source of the plugin off and on again', () {
      final plugin = source(current: featureIdProperty);

      expect(promotesFeatureIds(plugin), isTrue);
      expect(promoteFeatureIds(plugin, promote: false), isFalse);
      expect(promoteIds(plugin), [null, null]);
      expect(promotesFeatureIds(plugin), isFalse);

      expect(promoteFeatureIds(plugin, promote: true), isTrue);
      expect(promoteIds(plugin), [featureIdProperty, featureIdProperty]);
    });

    test('switches on a source of the style without a promoteId', () {
      final style = source();

      expect(promoteFeatureIds(style, promote: true), isTrue);
      expect(promoteIds(style), [featureIdProperty, featureIdProperty]);
    });

    test('keeps a promoteId of the app', () {
      final app = source(promoteId: 'ref', current: 'ref');

      expect(promoteFeatureIds(app, promote: true), isFalse);
      expect(promoteFeatureIds(app, promote: false), isFalse);
      expect(promoteIds(app), ['ref', 'ref']);
    });

    // maplibre-gl-js ignores generated ids under a promoteId.
    test('keeps the generated ids of a source with generateId', () {
      final generated = source(generateId: true);

      expect(promoteFeatureIds(generated, promote: true), isFalse);
      expect(promoteIds(generated), [null, null]);
      expect(
        promoteFeatureIds(source(generateId: false), promote: true),
        isTrue,
      );
    });

    test('changes nothing, and warns once, on a build without the '
        'fields', () {
      final warned = warnings();
      final bare = source(fields: false);

      expect(promoteFeatureIds(bare, promote: true), isFalse);
      expect(promoteFeatureIds(bare, promote: false), isFalse);
      expect(bare.has('promoteId'), isFalse);
      expect(warned, [contains('no promoteId')]);

      // A source with the promoteId but not the worker options.
      debugResetFeatureIdWarning();
      final noWorker =
          source(fields: false)
            ..setProperty('promoteId'.toJS, null)
            ..setProperty(
              'workerOptions'.toJS,
              {'geojsonVtOptions': <String, Object?>{}}.jsify(),
            );
      expect(promoteFeatureIds(noWorker, promote: true), isFalse);
      expect(promoteFeatureIds(noWorker, promote: true), isFalse);
      expect(noWorker.getProperty<JSAny?>('promoteId'.toJS), isNull);
      expect(warned, [
        contains('no promoteId'),
        contains('no workerOptions.geojsonVtOptions.promoteId'),
      ]);
    });
  });
}
