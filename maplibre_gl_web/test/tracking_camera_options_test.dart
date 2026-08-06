// Instantiates the web controller, which pulls in `dart:js_interop`, so it needs
// the browser. It never builds a map: the call under test refuses before it
// touches one.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

void main() {
  test('setTrackingCameraOptions reports that web cannot honor it', () async {
    final controller = MapLibreMapController();

    await expectLater(
      controller.setTrackingCameraOptions(tilt: 45),
      throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('setTrackingCameraOptions'),
            contains('GeolocateControl'),
            contains('Android and iOS'),
          ),
        ),
      ),
    );
  });
}
