// Drives the real camera wrapper against a hand-built stand-in for the map, so
// it needs the browser, but never the library itself.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

/// Records the arguments `easeTo` and `flyTo` receive, as maplibre-gl-js would
/// see them, and answers with the map itself.
class _FakeMap {
  final calls = <String, List<JSAny?>>{};
  final jsObject = JSObject();

  _FakeMap() {
    for (final method in ['easeTo', 'flyTo']) {
      jsObject.setProperty(
        method.toJS,
        ((JSAny options, [JSAny? eventData]) {
          calls[method] = [options, eventData];
          return jsObject;
        }).toJS,
      );
    }
  }

  /// The [key] of the event data the last [method] call passed on.
  JSAny? eventData(String method, String key) =>
      (calls[method]![1] as JSObject?)?.getProperty<JSAny?>(key.toJS);
}

void main() {
  // The platform tells its animation's events apart by this event data, so
  // flyTo must pass it on as easeTo does.
  for (final method in ['easeTo', 'flyTo']) {
    test('$method passes its event data on to the events it fires', () {
      final fake = _FakeMap();
      final map = MapLibreMap.fromJsObject(fake.jsObject as MapLibreMapJsImpl);
      final options = {'zoom': 3};

      if (method == 'easeTo') {
        map.easeTo(options, {'tag': 7});
      } else {
        map.flyTo(options, {'tag': 7});
      }

      expect((fake.eventData(method, 'tag') as JSNumber?)?.toDartInt, 7);
    });

    test('$method without event data passes none', () {
      final fake = _FakeMap();
      final map = MapLibreMap.fromJsObject(fake.jsObject as MapLibreMapJsImpl);

      if (method == 'easeTo') {
        map.easeTo({'zoom': 3});
      } else {
        map.flyTo({'zoom': 3});
      }

      expect(fake.calls[method]![1], isNull);
    });
  }
}
