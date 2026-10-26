// Instantiates the web controller, which pulls in `dart:js_interop`, so it needs
// the browser. It never builds a map: the calls under test refuse before they
// touch one.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

Matcher _unsupported(String call) => throwsA(
  isA<UnsupportedError>().having(
    (e) => e.message,
    'message',
    allOf(contains(call), contains('Android and iOS')),
  ),
);

void main() {
  test('setCustomHeaders reports that web has no custom headers', () async {
    final controller = MapLibreMapController();

    await expectLater(
      controller.setCustomHeaders({'X-Api-Key': 'secret'}, const []),
      _unsupported('setCustomHeaders'),
    );
  });

  test('getCustomHeaders reports that web has no custom headers', () async {
    final controller = MapLibreMapController();

    await expectLater(
      controller.getCustomHeaders(),
      _unsupported('getCustomHeaders'),
    );
  });
}
