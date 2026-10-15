// Integration test for the map widget's lifecycle.
//
// Covers removing a map before its platform view has been created (#1048):
// the widget tears down a platform that was never set up, and a platform view
// that shows up after that must not be wired to the widget that is gone.
//
// Whether the platform view exists by the time the widget goes away depends on
// the native view factory, so only a live map can exercise it.
//
// Run on Android or iOS:
//   flutter test integration_test/map_lifecycle_test.dart -d <device id>
//
// Run on Chrome (with chromedriver on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/map_lifecycle_test.dart -d chrome
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('removing a map before onMapCreated throws nothing (#1048)', (
    tester,
  ) async {
    var created = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MapLibreMap(
          styleString: offlineStyle,
          initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
          onMapCreated: (_) => created = true,
        ),
      ),
    );
    // Gone on the very next frame, before the platform view can answer.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);

    // Let a platform view that was already on its way arrive.
    await pumpFor(tester, const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(created, isFalse);

    // A map built afterwards still comes up.
    final controller = await pumpMap(tester);
    expect(controller.isDisposed, isFalse);
  });
}
