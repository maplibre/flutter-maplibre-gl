// Instantiates the web controller, which pulls in `dart:js_interop`, so it needs
// the browser. It never builds a map: the calls under test answer before they
// touch one.
@TestOn('browser')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';

void main() {
  test('setManualLocation without myLocationEnabled fails as on Android and '
      'iOS', () async {
    final controller = MapLibreMapController();

    await expectLater(
      controller.setManualLocation(
        const ManualLocationUpdate(target: LatLng(45, 9)),
      ),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'LOCATION_COMPONENT_NOT_READY',
        ),
      ),
    );
  });

  test('telemetry is always off', () async {
    final controller = MapLibreMapController();

    await controller.setTelemetryEnabled(true);

    expect(await controller.getTelemetryEnabled(), isFalse);
  });
}
