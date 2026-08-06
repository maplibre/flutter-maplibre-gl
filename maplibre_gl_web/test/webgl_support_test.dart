// The diagnostic itself is pure, with the context probe injected, so no test
// here needs a GPU. It still runs with the other web tests rather than on the
// VM, because package:web reaches dart:js_interop.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/webgl_support.dart';

void main() {
  /// A stand-in for [canCreateWebGlContext] that answers from [webGl2] and
  /// [webGl1], and records what it was asked for in [asked].
  bool Function({required bool version2}) fakeProbe({
    required bool webGl2,
    required bool webGl1,
    List<bool>? asked,
  }) {
    return ({required bool version2}) {
      asked?.add(version2);
      return version2 ? webGl2 : webGl1;
    };
  }

  group('webGlDiagnostic', () {
    test('stays quiet for a map that has a renderer, and probes nothing', () {
      final asked = <bool>[];

      final diagnostic = webGlDiagnostic(
        hasRenderer: true,
        probe: fakeProbe(webGl2: false, webGl1: false, asked: asked),
      );

      expect(diagnostic, isNull);
      expect(
        asked,
        isEmpty,
        reason: 'a working map must not pay for a context probe',
      );
    });

    test('stays quiet when WebGL2 is there, so WebGL is not the cause', () {
      expect(
        webGlDiagnostic(
          hasRenderer: false,
          probe: fakeProbe(webGl2: true, webGl1: true),
        ),
        isNull,
      );
    });

    test('names the version 5 way out for a WebGL1 only browser', () {
      final diagnostic = webGlDiagnostic(
        hasRenderer: false,
        probe: fakeProbe(webGl2: false, webGl1: true),
      );

      expect(diagnostic, contains('WebGL1 but not WebGL2'));
      expect(
        diagnostic,
        contains('MapLibreMap.webLibrarySource'),
        reason: 'the message has to name what the app can actually change',
      );
    });

    test('offers no way out when the browser has no WebGL at all', () {
      final diagnostic = webGlDiagnostic(
        hasRenderer: false,
        probe: fakeProbe(webGl2: false, webGl1: false),
      );

      expect(diagnostic, contains('no WebGL context at all'));
      expect(
        diagnostic,
        isNot(contains('MapLibreMap.webLibrarySource')),
        reason: 'no build of the library helps here, so do not suggest one',
      );
    });
  });

  group('mapRendererDiagnostic', () {
    /// A stand-in for the library's map, with or without the `painter` the
    /// library assigns once it has a context.
    MapLibreMap fakeMap({required bool withRenderer}) {
      final map = JSObject();
      if (withRenderer) map.setProperty('painter'.toJS, JSObject());
      return MapLibreMap.fromJsObject(map as MapLibreMapJsImpl);
    }

    test('reads the renderer back, and probes nothing when there is one', () {
      final asked = <bool>[];

      final diagnostic = mapRendererDiagnostic(
        fakeMap(withRenderer: true),
        probe: fakeProbe(webGl2: false, webGl1: false, asked: asked),
      );

      expect(diagnostic, isNull);
      expect(asked, isEmpty);
    });

    test('reports a map that built no renderer', () {
      final diagnostic = mapRendererDiagnostic(
        fakeMap(withRenderer: false),
        probe: fakeProbe(webGl2: false, webGl1: true),
      );

      expect(diagnostic, contains('WebGL1 but not WebGL2'));
    });
  });
}
