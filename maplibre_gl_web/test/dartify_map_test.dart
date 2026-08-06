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
/// this test was written. The platform code cannot be unit tested without a
/// live map, but the reason it threw can be, and it is the part that is easy
/// to reintroduce: `dartify()` looks like it produces the map the signature
/// promises, and it does not.
void main() {
  group('converting a JS object to a Dart map', () {
    test('dartify does not produce a Map<String, dynamic>', () {
      final jsState = JSObject()..setProperty('selected'.toJS, true.toJS);

      expect(
        jsState.dartify(),
        isNot(isA<Map<String, dynamic>>()),
        reason:
            'if this ever starts holding, the cast that used to be here was '
            'not the bug it looked like; check the fix in getFeatureState',
      );
    });

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
