// Integration test for MapLibreMap.myLocationStyle on web, read from the DOM.
//
// my_location_style_test.dart checks on every platform that the style is
// accepted. On web the puck is DOM elements styled by CSS, so this also reads
// the computed colors of the dot, the accuracy circle and the bearing arrow of
// the manual puck, after creation, after an update, and after a reset.
//
// It imports package:web, which does not compile for Android or iOS, so it
// is not part of all_tests.dart. Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/my_location_style_web_test.dart \
//     -d web-server --browser-name=chrome
//
// The assertions only run on web; elsewhere the tests are no-ops.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web/web.dart' as web;

import 'support/map_harness.dart';

const _camera = CameraPosition(target: LatLng(45, 9), zoom: 14);

const _style = MyLocationStyle(
  fillColor: Color(0xFFFF0000),
  bearingColor: Color(0xFF00FF00),
  accuracyColor: Color(0xFF0000FF),
);

const _dot = '.maplibregl-user-location-dot';
const _accuracy = '.maplibregl-user-location-accuracy-circle';
const _arrow = '.maplibre-gl-manual-location-arrow';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('myLocationStyle on web', () {
    testWidgets('the puck takes the colors and loses them on reset', (
      tester,
    ) async {
      if (!kIsWeb) return;
      late MapCreatedCallback created;
      late OnStyleLoadedCallback styleLoaded;
      final controller = await pumpMap(
        tester,
        initialCameraPosition: _camera,
        builder: (onMapCreated, onStyleLoaded) {
          created = onMapCreated;
          styleLoaded = onStyleLoaded;
          return _map(onMapCreated, onStyleLoaded, style: _style);
        },
      );
      await _pushFix(tester, controller);

      expect(_color(_dot, 'background-color'), 'rgb(255, 0, 0)');
      expect(_color(_arrow, 'border-bottom-color'), 'rgb(0, 255, 0)');
      expect(_color(_accuracy, 'background-color'), 'rgba(0, 0, 255, 0.2)');

      await _update(
        tester,
        controller,
        _map(
          created,
          styleLoaded,
          style: const MyLocationStyle(accuracyCircleEnabled: false),
        ),
      );
      await _pushFix(tester, controller);
      expect(_color(_dot, 'background-color'), 'rgb(29, 161, 242)');
      expect(_color(_accuracy, 'display'), 'none');

      await _update(tester, controller, _map(created, styleLoaded));
      await _pushFix(tester, controller);
      expect(_color(_dot, 'background-color'), 'rgb(29, 161, 242)');
      expect(_color(_accuracy, 'display'), 'block');
    });
  });
}

String _color(String selector, String property) {
  final element = web.document.querySelector(selector);
  expect(element, isNotNull, reason: '$selector is in the DOM');
  return web.window
      .getComputedStyle(element!)
      .getPropertyValue(property)
      .trim();
}

MapLibreMap _map(
  MapCreatedCallback onMapCreated,
  OnStyleLoadedCallback onStyleLoaded, {
  MyLocationStyle? style,
}) => MapLibreMap(
  styleString: offlineStyle,
  initialCameraPosition: _camera,
  myLocationEnabled: true,
  locationSource: const ManualLocationSource(),
  myLocationStyle: style,
  onMapCreated: onMapCreated,
  onStyleLoadedCallback: onStyleLoaded,
);

Future<void> _pushFix(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  await pumpUntil(
    tester,
    controller.updateManualLocation(
      const ManualLocationUpdate(
        target: LatLng(45, 9),
        horizontalAccuracy: 50,
        bearing: 90,
      ),
    ),
    'updateManualLocation',
  );
  await tester.pump(const Duration(milliseconds: 200));
}

/// Rebuilds the map with [map] and waits for the platform to apply it.
Future<void> _update(
  WidgetTester tester,
  MapLibreMapController controller,
  MapLibreMap map,
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
        fail('Timed out waiting for the update');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  } finally {
    controller.removeListener(listener);
  }
}
