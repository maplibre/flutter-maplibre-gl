// Imports the web plugin library, which pulls in `dart:js_interop`, so it needs
// the browser. No map is built: the options are read into a recording sink.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/location_puck_style.dart';
import 'package:web/web.dart' as web;

/// Records the puck style and ignores every other option.
class _StyleSink implements MapLibreMapOptionsSink {
  Map<String, dynamic>? style;

  @override
  void setMyLocationStyle(Map<String, dynamic> style) => this.style = style;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the puck style reaches setMyLocationStyle', () {
    final sink = _StyleSink();
    Convert.interpretMapLibreMapOptions({
      'myLocationStyle': {
        'fillColor': 0xFFFF0000,
        'accuracyCircleEnabled': true,
      },
    }, sink);
    expect(sink.style, {
      'fillColor': 0xFFFF0000,
      'accuracyCircleEnabled': true,
    });
  });

  test('a default style makes no CSS', () {
    expect(locationPuckCss('.s', {'accuracyCircleEnabled': true}), isEmpty);
    expect(locationPuckCss('.s', {}), isEmpty);
  });

  test('each color becomes a rule scoped to the map', () {
    final css = locationPuckCss('.s', {
      'fillColor': 0xFFFF0000,
      'bearingColor': 0x8000FF00,
      'accuracyColor': 0x100000FF,
      'accuracyCircleEnabled': true,
      'pulseColor': 0xFFFFFF00,
    });
    expect(
      css,
      contains(
        '.s .maplibregl-user-location-dot:not(.maplibregl-user-location-dot-stale)'
        ' { background-color: rgba(255, 0, 0, 1.000); }',
      ),
    );
    expect(
      css,
      contains(
        '.s .maplibregl-user-location-dot::before'
        ' { background-color: rgba(255, 255, 0, 1.000); }',
      ),
    );
    // The accuracy circle keeps its own 20% opacity, whatever the alpha.
    expect(
      css,
      contains(
        '.s .maplibregl-user-location-accuracy-circle'
        ' { background-color: rgba(0, 0, 255, 0.200); }',
      ),
    );
    expect(
      css,
      contains(
        '.s .maplibre-gl-manual-location-arrow'
        ' { border-bottom-color: rgba(0, 255, 0, 0.502); }',
      ),
    );
  });

  test('the accuracy circle and the pulse can be hidden', () {
    final css = locationPuckCss('.s', {
      'accuracyColor': 0xFF0000FF,
      'accuracyCircleEnabled': false,
      'pulseEnabled': false,
      'pulseColor': 0xFFFFFF00,
    });
    expect(
      css,
      contains(
        '.s .maplibregl-user-location-accuracy-circle'
        ' { display: none !important; }',
      ),
    );
    expect(
      css,
      contains('.s .maplibregl-user-location-dot::before { display: none; }'),
    );
    expect(css, isNot(contains('rgba(0, 0, 255')));
    expect(css, isNot(contains('rgba(255, 255, 0')));
  });

  test('the styler adds and removes its rules on the container', () {
    final container = web.document.createElement('div') as web.HTMLDivElement;
    final styler = LocationPuckStyler(container);

    styler.apply({'fillColor': 0xFFFF0000, 'accuracyCircleEnabled': true});
    expect(container.className, startsWith('maplibre-gl-puck-style-'));
    final style = container.querySelector('style');
    expect(style?.textContent, contains('rgba(255, 0, 0, 1.000)'));

    styler.apply({'fillColor': 0xFF00FF00, 'accuracyCircleEnabled': true});
    expect(container.querySelectorAll('style').length, 1);
    expect(style?.textContent, contains('rgba(0, 255, 0, 1.000)'));

    styler.apply({'accuracyCircleEnabled': true});
    expect(container.querySelector('style'), isNull);
    expect(container.className, isEmpty);
  });
}
