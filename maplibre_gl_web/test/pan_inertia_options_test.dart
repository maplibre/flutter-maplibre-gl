// Imports the web plugin library, which pulls in `dart:js_interop`, so it needs
// the browser. No map is built: the options are read into a recording sink.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

/// Records the arguments of setGestures and ignores every other option.
class _GestureSink implements MapLibreMapOptionsSink {
  PanInertia? panInertia;
  bool? scrollGesturesEnabled;

  @override
  void setGestures({
    required bool rotateGesturesEnabled,
    required bool scrollGesturesEnabled,
    required bool tiltGesturesEnabled,
    required bool zoomGesturesEnabled,
    required bool doubleClickZoomEnabled,
    PanInertia panInertia = PanInertia.normal,
  }) {
    this.scrollGesturesEnabled = scrollGesturesEnabled;
    this.panInertia = panInertia;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Map<String, dynamic> _gestures({int? panInertia}) => {
  'rotateGesturesEnabled': true,
  'scrollGesturesEnabled': true,
  'tiltGesturesEnabled': true,
  'zoomGesturesEnabled': true,
  'doubleClickZoomEnabled': true,
  if (panInertia != null) 'panInertia': panInertia,
};

void main() {
  test('the pan inertia reaches setGestures', () {
    for (final inertia in PanInertia.values) {
      final sink = _GestureSink();
      Convert.interpretMapLibreMapOptions(
        _gestures(panInertia: inertia.index),
        sink,
      );
      expect(sink.panInertia, inertia);
      expect(sink.scrollGesturesEnabled, isTrue);
    }
  });

  test('a missing pan inertia means normal', () {
    final sink = _GestureSink();
    Convert.interpretMapLibreMapOptions(_gestures(), sink);
    expect(sink.panInertia, PanInertia.normal);
  });
}
