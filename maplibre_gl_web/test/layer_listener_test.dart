// Drives the real Evented wrapper against a hand-built stand-in for the map, so
// it needs the browser, but never the library itself.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/util/evented_interop.dart';
import 'package:maplibre_gl_web/src/util/evented.dart';

/// A layer listener registered on [_FakeMap].
typedef _Registration = ({String type, String layerId, JSFunction listener});

/// Keeps the layer listeners it is given and drops one on `off` only when the
/// very same JS function comes back, as maplibre-gl-js does.
class _FakeMap {
  final registrations = <_Registration>[];
  final jsObject = JSObject();

  _FakeMap() {
    jsObject.setProperty(
      'on'.toJS,
      ((JSString type, JSString layerId, JSFunction listener) {
        registrations.add((
          type: type.toDart,
          layerId: layerId.toDart,
          listener: listener,
        ));
        return JSObject()..setProperty('unsubscribe'.toJS, (() {}).toJS);
      }).toJS,
    );
    jsObject.setProperty(
      'off'.toJS,
      ((JSString type, JSString layerId, JSFunction? listener) {
        registrations.removeWhere(
          (r) =>
              r.type == type.toDart &&
              r.layerId == layerId.toDart &&
              listener != null &&
              r.listener.strictEquals(listener).toDart,
        );
        // maplibre-gl-js answers with the map itself.
        return jsObject;
      }).toJS,
    );
  }

  int count(String type, String layerId) =>
      registrations.where((r) => r.type == type && r.layerId == layerId).length;
}

/// Stands in for the platform, whose layer listeners are method tear-offs: a
/// new closure object on each `on` and `off`, equal only by `==`.
class _Owner {
  void onLayerEvent(Event event, String layerId) {}
}

void main() {
  test('off with an equal tear-off removes the listener that on added', () {
    final fake = _FakeMap();
    final evented = Evented.fromJsObject(fake.jsObject as EventedJsImpl);
    final owner = _Owner();

    evented.on('mousemove', 'points', owner.onLayerEvent);
    expect(fake.count('mousemove', 'points'), 1);

    evented.off('mousemove', 'points', owner.onLayerEvent);
    expect(fake.count('mousemove', 'points'), 0);
  });

  test('a layer removed and added again has one listener, not two', () {
    final fake = _FakeMap();
    final evented = Evented.fromJsObject(fake.jsObject as EventedJsImpl);
    final owner = _Owner();

    for (var i = 0; i < 3; i++) {
      evented.on('mouseenter', 'points', owner.onLayerEvent);
      evented.off('mouseenter', 'points', owner.onLayerEvent);
    }
    evented.on('mouseenter', 'points', owner.onLayerEvent);

    expect(fake.count('mouseenter', 'points'), 1);
  });

  test('off on one layer leaves the same listener on another layer', () {
    final fake = _FakeMap();
    final evented = Evented.fromJsObject(fake.jsObject as EventedJsImpl);
    final owner = _Owner();

    evented.on('mouseleave', 'a', owner.onLayerEvent);
    evented.on('mouseleave', 'b', owner.onLayerEvent);
    evented.off('mouseleave', 'a', owner.onLayerEvent);

    expect(fake.count('mouseleave', 'a'), 0);
    expect(fake.count('mouseleave', 'b'), 1);
  });
}
