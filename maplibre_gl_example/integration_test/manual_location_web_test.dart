// Integration test for the web manual-location puck.
//
// On web, `ManualLocationSource` makes the plugin render its own user-location
// puck from HTML markers (there is no native location component to feed). This
// test drives that path end to end in a real browser and asserts the puck's DOM
// element is created after a manual fix is pushed.
//
// Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/manual_location_web_test.dart \
//     -d chrome
//
// The assertions only run on web; on other platforms the test is a no-op so the
// suite stays green everywhere.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web/web.dart' as web;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web manual puck renders after updateManualLocation', (
    tester,
  ) async {
    if (!kIsWeb) {
      // The manual puck DOM is a web-only concern; nothing to assert elsewhere.
      return;
    }

    const target = LatLng(37.33233141, -122.0312186);
    final controllerCompleter = Completer<MapLibreMapController>();
    final styleLoadedCompleter = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapLibreMap(
            styleString: 'assets/style.json',
            locationSource: const ManualLocationSource(),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
            initialCameraPosition: const CameraPosition(
              target: target,
              zoom: 15,
            ),
            onMapCreated: controllerCompleter.complete,
            onStyleLoadedCallback: () {
              if (!styleLoadedCompleter.isCompleted) {
                styleLoadedCompleter.complete();
              }
            },
          ),
        ),
      ),
    );

    // The map view is created on the next frame(s).
    final controller = await _await(
      tester,
      controllerCompleter.future,
      'onMapCreated',
    );
    await _await(tester, styleLoadedCompleter.future, 'onStyleLoaded');

    // Before any fix, the puck must not exist.
    expect(
      web.document.querySelector('.maplibregl-user-location-dot'),
      isNull,
      reason: 'puck should not render before a manual location is pushed',
    );

    // Push a manual fix: this should create the dot + accuracy-circle markers.
    // (Previously this threw UnsupportedError on web.)
    await controller.updateManualLocation(
      ManualLocationUpdate(
        target: target,
        bearing: 90,
        speed: 4.2,
        horizontalAccuracy: 8,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      ),
    );

    // Marker DOM is attached synchronously by addTo, but pump a frame to be safe.
    await tester.pump();

    expect(
      web.document.querySelector('.maplibregl-user-location-dot'),
      isNotNull,
      reason: 'the location dot should render after a manual fix',
    );
    expect(
      web.document.querySelector('.maplibregl-user-location-accuracy-circle'),
      isNotNull,
      reason: 'the accuracy circle should render when accuracy is provided',
    );
    expect(
      web.document.querySelector('.maplibre-gl-manual-location-arrow'),
      isNotNull,
      reason:
          'the bearing arrow element should render when bearing is provided',
    );
  });
}

/// Awaits [future] while pumping frames, failing with [label] if it doesn't
/// complete within the timeout (avoids hanging the whole suite on a stuck map).
Future<T> _await<T>(
  WidgetTester tester,
  Future<T> future,
  String label, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  var done = false;
  T? result;
  unawaited(
    future.then((value) {
      done = true;
      result = value;
    }),
  );
  while (!done) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $label');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  return result as T;
}
