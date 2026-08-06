// Inspects real JS objects, so it needs a browser:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/style/feature_identifier_interop.dart';

/// `removeFeatureState(sourceId)` with no feature id is the documented way to
/// reset a whole source, and it did nothing on web: the target was built with
/// `id: null`, and maplibre-gl-js only treats a **missing** id as "every
/// feature of this source". A null one is an id to look up, so it matched
/// nothing and cleared nothing, without an error.
///
/// The distinction is invisible in Dart, where both read as null, which is why
/// it is asserted here on the JS object itself.
void main() {
  group('FeatureIdentifierJsImpl', () {
    test('leaves out the arguments it is not given', () {
      final target = FeatureIdentifierJsImpl(source: 'states');

      expect(target.has('source'), isTrue);
      expect(
        target.has('id'),
        isFalse,
        reason: 'a present id, even null, stops a source-wide remove',
      );
      expect(target.has('sourceLayer'), isFalse);
    });

    test('sets the arguments it is given', () {
      final target = FeatureIdentifierJsImpl(
        source: 'states',
        id: '46'.toJS,
        sourceLayer: 'admin',
      );

      expect(target.has('id'), isTrue);
      expect((target.id as JSString?)?.toDart, '46');
      expect(target.sourceLayer, 'admin');
    });

    test('an explicitly null id is still a property, which is the trap', () {
      // Passing null explicitly is the case under test: the analyzer is right
      // that it matches the default, and wrong that it changes nothing.
      // ignore: avoid_redundant_argument_values
      final target = FeatureIdentifierJsImpl(source: 'states', id: null);

      expect(
        target.has('id'),
        isTrue,
        reason:
            'if this ever stops holding, passing null became equivalent to '
            'omitting and removeFeatureState no longer needs its two branches',
      );
    });
  });
}
