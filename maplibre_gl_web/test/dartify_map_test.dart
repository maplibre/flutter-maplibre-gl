// Runs against the real JS object model, so it needs a browser:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/utils.dart';

/// `getFeatureState` returned `(state as JSObject).dartify() as Map<String,
/// dynamic>?` and threw on every call that found a state, from 0.26.0 until
/// this test was written, because that conversion does not produce the map the
/// cast asked for. What is asserted here is our side of it: `dartifyMap` builds
/// the typed map the signature promises. Asserting the other half, how the SDK's
/// `dartify` behaves, would turn an SDK change into a red build on working code.
void main() {
  group('converting a JS object to a Dart map', () {
    test('dartifyMap produces one, with the values intact', () {
      final jsState =
          JSObject()
            ..setProperty('selected'.toJS, true.toJS)
            ..setProperty('score'.toJS, 42.toJS)
            ..setProperty('label'.toJS, 'north'.toJS);

      final state = dartifyMap(jsState);

      expect(state, isA<Map<String, dynamic>>());
      expect(state, {'selected': true, 'score': 42, 'label': 'north'});
    });

    test('an empty JS object gives an empty map, not null', () {
      expect(dartifyMap(JSObject()), isEmpty);
    });
  });
}
