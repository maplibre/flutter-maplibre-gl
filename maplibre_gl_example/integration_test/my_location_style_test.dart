// Integration test for MapLibreMap.myLocationStyle.
//
// The style recolors the user-location puck: LocationComponentOptions on
// Android, the default user location view of MLNMapView on iOS, and CSS rules
// on web. The colors cannot be read back through the plugin, so this checks
// what can be: the style is accepted at creation and as an update, with the
// puck shown and fed manual fixes, in the tracking modes that draw the puck
// differently, and can be reset, without an error on any platform. The CSS
// that web generates is covered by maplibre_gl_web's unit tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _camera = CameraPosition(target: LatLng(45, 9), zoom: 14);

const _branded = MyLocationStyle(
  fillColor: Color(0xFFE53935),
  bearingColor: Color(0xFF1E88E5),
  accuracyColor: Color(0xFFFDD835),
  pulseEnabled: true,
  pulseColor: Color(0xFF43A047),
);

const _hidden = MyLocationStyle(
  fillColor: Color(0xFF000000),
  accuracyCircleEnabled: false,
  pulseEnabled: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('myLocationStyle', () {
    for (final (label, style) in [
      ('no style', null),
      ('a branded style', _branded),
      ('a style without accuracy circle and pulse', _hidden),
    ]) {
      testWidgets('the map is created with $label', (tester) async {
        final controller = await pumpMap(
          tester,
          initialCameraPosition: _camera,
          builder:
              (onMapCreated, onStyleLoaded) =>
                  _map(onMapCreated, onStyleLoaded, style: style),
        );
        await _pushFix(tester, controller);

        await pumpUntil(
          tester,
          controller.getVisibleRegion(),
          'getVisibleRegion',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a change is applied as an update', (tester) async {
      late MapCreatedCallback created;
      late OnStyleLoadedCallback styleLoaded;
      final controller = await pumpMap(
        tester,
        initialCameraPosition: _camera,
        builder: (onMapCreated, onStyleLoaded) {
          created = onMapCreated;
          styleLoaded = onStyleLoaded;
          return _map(onMapCreated, onStyleLoaded);
        },
      );
      await _pushFix(tester, controller);

      // Each tracking mode draws the puck its own way, GPS tracking as an
      // arrow on iOS, so every style is set in each of them.
      for (final mode in [
        MyLocationTrackingMode.none,
        MyLocationTrackingMode.tracking,
        MyLocationTrackingMode.trackingGps,
      ]) {
        for (final (label, style) in [
          ('branded', _branded),
          ('hidden', _hidden),
          ('reset', null),
        ]) {
          await _update(
            tester,
            controller,
            _map(created, styleLoaded, style: style, trackingMode: mode),
            '$label in $mode',
          );
          await _pushFix(tester, controller);
        }
      }

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
  MyLocationStyle? style,
  MyLocationTrackingMode trackingMode = MyLocationTrackingMode.none,
}) => MapLibreMap(
  styleString: offlineStyle,
  initialCameraPosition: _camera,
  myLocationEnabled: true,
  locationSource: const ManualLocationSource(),
  myLocationTrackingMode: trackingMode,
  myLocationStyle: style,
  onMapCreated: onMapCreated,
  onStyleLoadedCallback: onStyleLoaded,
);

/// Feeds the puck a fix with a bearing and a small accuracy, so the dot, the
/// accuracy circle, the pulse and the bearing are all drawn.
Future<void> _pushFix(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  await pumpUntil(
    tester,
    controller.updateManualLocation(
      ManualLocationUpdate(
        target: const LatLng(45, 9),
        horizontalAccuracy: 8,
        bearing: 90,
        speed: 5,
        timestamp: DateTime.now(),
      ),
    ),
    'updateManualLocation',
  );
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
}

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
