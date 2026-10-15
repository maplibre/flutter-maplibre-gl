// Drives the real setFilter and getFilter interop against a hand-built
// stand-in for the map, so it needs the browser, but never the library itself.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

void main() {
  /// A map that keeps the last filter it was given and hands it back, the way
  /// GL JS does.
  JSObject fakeMap() {
    final map = JSObject();
    map.setProperty(
      'setFilter'.toJS,
      ((JSString layerId, JSAny? filter) {
        map.setProperty('filter'.toJS, filter);
        return map;
      }).toJS,
    );
    map.setProperty(
      'getFilter'.toJS,
      ((JSString layerId) => map.getProperty<JSAny?>('filter'.toJS)).toJS,
    );
    return map;
  }

  MapLibreMap wrap(JSObject map) =>
      MapLibreMap.fromJsObject(map as MapLibreMapJsImpl);

  test('a nested expression reaches GL JS as nested arrays', () {
    final map = wrap(fakeMap());

    map.setFilter('layer', [
      '==',
      ['get', 'type'],
      'park',
    ]);

    expect(map.getFilter('layer'), [
      '==',
      ['get', 'type'],
      'park',
    ]);
  });

  test('null removes the filter', () {
    final map = wrap(fakeMap());

    map.setFilter('layer', ['has', 'name']);
    map.setFilter('layer', null);

    expect(map.getFilter('layer'), isNull);
  });

  test('a filter that is a plain boolean reads back as one', () {
    final map = wrap(fakeMap());

    map.setFilter('layer', false);

    expect(map.getFilter('layer'), isFalse);
  });
}
