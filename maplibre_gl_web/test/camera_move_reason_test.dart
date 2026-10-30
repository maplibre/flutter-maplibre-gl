// Builds browser events, so it needs the browser, but never the library.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/camera_move_reason.dart';
import 'package:web/web.dart' as web;

/// A `movestart` of maplibre-gl-js, caused by [input] when there is one.
JSObject _moveStart([web.Event? input]) {
  final event = JSObject();
  if (input != null) event.setProperty('originalEvent'.toJS, input);
  return event;
}

/// A click the browser dispatched on [target].
web.Event _clickOn(web.Element target) {
  final click = web.MouseEvent('click');
  target.dispatchEvent(click);
  return click;
}

void main() {
  test('a move without a browser event is programmatic', () {
    expect(cameraMoveReason(_moveStart()), CameraMoveReason.programmatic);
  });

  test('a move from input on the map is a gesture', () {
    final canvas = web.document.createElement('canvas');
    expect(
      cameraMoveReason(_moveStart(_clickOn(canvas))),
      CameraMoveReason.gesture,
    );
    expect(
      cameraMoveReason(_moveStart(web.KeyboardEvent('keydown'))),
      CameraMoveReason.gesture,
    );
  });

  test(
    'a move of the mouse wheel, which has no browser event, is a gesture',
    () {
      expect(
        cameraMoveReason(_moveStart(), scrollZooming: true),
        CameraMoveReason.gesture,
      );
    },
  );

  test('a click on the compass is programmatic, as on Android and iOS', () {
    final control = web.document.createElement('div')
      ..className = 'maplibregl-ctrl maplibregl-ctrl-group';
    final icon = web.document.createElement('span');
    control.appendChild(web.document.createElement('button')).appendChild(icon);

    expect(
      cameraMoveReason(_moveStart(_clickOn(icon))),
      CameraMoveReason.programmatic,
    );
  });
}
