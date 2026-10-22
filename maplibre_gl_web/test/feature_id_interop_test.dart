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
    /// A GeoJSON source created with the promoteId [own], now using
    /// [current], as maplibre-gl-js holds it.
    JSObject source({String? own, String? current}) {
      final source =
          {
                'type': 'geojson',
                'promoteId': current,
                'workerOptions': {
                  'geojsonVtOptions': {'promoteId': current},
                },
              }.jsify()!
              as JSObject;
      source.setProperty(
        'serialize'.toJS,
        (() => {'type': 'geojson', 'promoteId': own}.jsify()).toJS,
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

    test('switches a source of the plugin off and on again', () {
      final plugin = source(own: featureIdProperty, current: featureIdProperty);

      expect(promoteFeatureIds(plugin, promote: false), isFalse);
      expect(promoteIds(plugin), [null, null]);

      expect(promoteFeatureIds(plugin, promote: true), isTrue);
      expect(promoteIds(plugin), [featureIdProperty, featureIdProperty]);
    });

    test('switches on a source of the style without a promoteId', () {
      final style = source();

      expect(promoteFeatureIds(style, promote: true), isTrue);
      expect(promoteIds(style), [featureIdProperty, featureIdProperty]);
    });

    test('keeps a promoteId of the app', () {
      final app = source(own: 'ref', current: 'ref');

      expect(promoteFeatureIds(app, promote: true), isFalse);
      expect(promoteFeatureIds(app, promote: false), isFalse);
      expect(promoteIds(app), ['ref', 'ref']);
    });
  });
}
