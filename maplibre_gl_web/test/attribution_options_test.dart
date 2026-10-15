// Imports the web plugin library, which pulls in `dart:js_interop`, so it needs
// the browser. No map is built: the options are read into a recording sink.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

/// Records every attribution position it is given and ignores every other
/// option.
class _AttributionSink implements MapLibreMapOptionsSink {
  final positions = <AttributionButtonPosition>[];

  @override
  void setAttributionButtonAlignment(AttributionButtonPosition position) {
    positions.add(position);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the map is created with the attribution at the bottom right', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions({}, sink, initial: true);
    expect(sink.positions, [AttributionButtonPosition.bottomRight]);
  });

  test('the map is created with the position the app set', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions(
      {'attributionButtonPosition': AttributionButtonPosition.topLeft.index},
      sink,
      initial: true,
    );
    expect(sink.positions, [AttributionButtonPosition.topLeft]);
  });

  test('an update without the position leaves the attribution alone', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions({'compassEnabled': false}, sink);
    expect(sink.positions, isEmpty);
  });

  test('an update with the position moves the attribution', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions(
      {'attributionButtonPosition': AttributionButtonPosition.topRight.index},
      sink,
    );
    expect(sink.positions, [AttributionButtonPosition.topRight]);
  });
}
