// Integration test for MapLibreMap.attributionEnabled.
//
// The option hides the attribution (i) button: UiSettings on Android, the
// attribution button of MLNMapView on iOS, and the attribution control on
// web. Whether a button is drawn cannot be read back through the plugin, so
// this checks what can be: the option is accepted at creation and as an
// update on every platform, together with a position, without an error.
// On web the control is in the DOM, and attribution_web_test.dart checks it
// there.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _camera = CameraPosition(target: LatLng(0, 0), zoom: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('attributionEnabled', () {
    for (final enabled in [true, false]) {
      testWidgets('the map is created with $enabled', (tester) async {
        final controller = await pumpMap(
          tester,
          builder:
              (onMapCreated, onStyleLoaded) =>
                  _map(onMapCreated, onStyleLoaded, enabled: enabled),
        );

        final region = await pumpUntil(
          tester,
          controller.getVisibleRegion(),
          'getVisibleRegion',
        );
        expect(region.northeast.longitude, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a change is applied as an update', (tester) async {
      late MapCreatedCallback created;
      late OnStyleLoadedCallback styleLoaded;
      final controller = await pumpMap(
        tester,
        builder: (onMapCreated, onStyleLoaded) {
          created = onMapCreated;
          styleLoaded = onStyleLoaded;
          return _map(onMapCreated, onStyleLoaded, enabled: false);
        },
      );

      for (final enabled in [true, false, true]) {
        await _update(
          tester,
          controller,
          _map(created, styleLoaded, enabled: enabled),
          'attributionEnabled: $enabled',
        );
      }
      // The position can still change while the button is hidden.
      await _update(
        tester,
        controller,
        _map(
          created,
          styleLoaded,
          enabled: false,
          position: AttributionButtonPosition.bottomLeft,
        ),
        'attributionEnabled: false, bottomLeft',
      );
      await _update(
        tester,
        controller,
        _map(
          created,
          styleLoaded,
          enabled: true,
          position: AttributionButtonPosition.bottomLeft,
        ),
        'attributionEnabled: true, bottomLeft',
      );

      await pumpUntil(
        tester,
        controller.getVisibleRegion(),
        'getVisibleRegion',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

MapLibreMap _map(
  MapCreatedCallback onMapCreated,
  OnStyleLoadedCallback onStyleLoaded, {
  required bool enabled,
  AttributionButtonPosition position = AttributionButtonPosition.topLeft,
}) => MapLibreMap(
  styleString: offlineStyle,
  initialCameraPosition: _camera,
  attributionEnabled: enabled,
  attributionButtonPosition: position,
  onMapCreated: onMapCreated,
  onStyleLoadedCallback: onStyleLoaded,
);

/// Rebuilds the map with [map], in the same tree [pumpMap] built, and waits
/// for the option update to come back from the platform: the controller
/// notifies its listeners once the platform has answered.
Future<void> _update(
  WidgetTester tester,
  MapLibreMapController controller,
  MapLibreMap map,
  String label,
) async {
  var notified = false;
  void listener() => notified = true;
  controller.addListener(listener);
  try {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 300, height: 300, child: map),
          ),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!notified) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for the $label update');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  } finally {
    controller.removeListener(listener);
  }
  expect(tester.takeException(), isNull, reason: label);
}
