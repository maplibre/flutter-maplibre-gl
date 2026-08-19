// Drives the real interop against hand-built stand-ins for a version 6 and a
// version 5 map, so it needs the browser, but never the library itself.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

void main() {
  /// A map like version 6: it takes a resolver, and keeps whatever it was
  /// handed in `resolver` for the test to call.
  JSObject fakeVersion6Map() {
    final map = JSObject();
    map.setProperty(
      'setMissingStyleImageResolver'.toJS,
      ((JSFunction? resolver) {
        map.setProperty('resolver'.toJS, resolver);
      }).toJS,
    );
    return map;
  }

  /// A map like version 5: no resolver, only `on`, which records the event type
  /// it was asked for and answers with something that can be unsubscribed.
  JSObject fakeVersion5Map() {
    final map = JSObject();
    map.setProperty(
      'on'.toJS,
      ((JSString type, JSFunction listener) {
        map.setProperty('subscribedTo'.toJS, type);
        map.setProperty('listener'.toJS, listener);
        return JSObject()..setProperty('unsubscribe'.toJS, (() {}).toJS);
      }).toJS,
    );
    return map;
  }

  MapLibreMap wrap(JSObject map) =>
      MapLibreMap.fromJsObject(map as MapLibreMapJsImpl);

  group('hasMissingStyleImageResolver', () {
    test('is true for a build that has the method', () {
      expect(wrap(fakeVersion6Map()).hasMissingStyleImageResolver, isTrue);
    });

    test('is false for a build that does not, so version 5 is recognised', () {
      expect(wrap(fakeVersion5Map()).hasMissingStyleImageResolver, isFalse);
    });
  });

  group('setMissingStyleImageHandler', () {
    test(
      'registers a resolver on version 6, and hands it the image id',
      () async {
        final map = fakeVersion6Map();
        String? resolved;

        final subscription = wrap(map).setMissingStyleImageHandler((id) async {
          resolved = id;
        });

        expect(
          subscription,
          isNull,
          reason: 'the resolver path has nothing to unsubscribe',
        );
        final resolver = map.getProperty<JSFunction?>('resolver'.toJS);
        expect(resolver, isNotNull, reason: 'the resolver must reach the map');
        // The map calls the resolver with the id and awaits what comes back.
        final returned = resolver!.callAsFunction(map, 'icon.png'.toJS);
        await (returned! as JSPromise).toDart;
        expect(resolved, 'icon.png');
      },
    );

    test('falls back to the listener on version 5, and returns it', () {
      final map = fakeVersion5Map();

      final subscription = wrap(map).setMissingStyleImageHandler((_) async {});

      expect(
        subscription,
        isNotNull,
        reason: 'the listener has to be unsubscribable on dispose',
      );
      expect(
        map.getProperty<JSString?>('subscribedTo'.toJS)?.toDart,
        'styleimagemissing',
      );
    });
  });

  group('clearMissingStyleImageHandler', () {
    test('removes the resolver on version 6', () {
      final map = fakeVersion6Map();
      final wrapped = wrap(map)..setMissingStyleImageHandler((_) async {});
      expect(map.getProperty<JSFunction?>('resolver'.toJS), isNotNull);

      wrapped.clearMissingStyleImageHandler();

      expect(map.getProperty<JSFunction?>('resolver'.toJS), isNull);
    });

    test('does nothing on version 5, which has no resolver to remove', () {
      final map = fakeVersion5Map();

      expect(wrap(map).clearMissingStyleImageHandler, returnsNormally);
    });
  });
}
