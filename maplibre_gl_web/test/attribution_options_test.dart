// Imports the web plugin library, which pulls in `dart:js_interop`, so it needs
// the browser. No map is built: the options are read into a recording sink.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

/// Records the attribution calls and ignores every other option.
class _AttributionSink implements MapLibreMapOptionsSink {
  final calls = <String>[];

  @override
  void setAttributionEnabled(bool enabled) => calls.add('enabled $enabled');

  @override
  void setAttributionButtonAlignment(AttributionButtonPosition position) =>
      calls.add('position ${position.name}');

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('the attribution settings reach the sink', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions({
      'attributionEnabled': false,
      'attributionButtonPosition': AttributionButtonPosition.topLeft.index,
    }, sink);
    expect(sink.calls, ['position topLeft', 'enabled false']);
  });

  test('an update without attribution settings leaves them alone', () {
    // Before, any update moved the control back to the bottom right, and it
    // would also have shown a hidden one again.
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions({'compassEnabled': false}, sink);
    expect(sink.calls, isEmpty);
  });

  test('showing the attribution again sends only that', () {
    final sink = _AttributionSink();
    Convert.interpretMapLibreMapOptions({'attributionEnabled': true}, sink);
    expect(sink.calls, ['enabled true']);
  });
}
