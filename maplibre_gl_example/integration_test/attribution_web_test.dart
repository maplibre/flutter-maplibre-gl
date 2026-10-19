// Integration test for MapLibreMap.attributionEnabled on web, read from the
// DOM.
//
// attribution_test.dart checks on every platform that the option is
// accepted. On web the attribution control is a DOM element, so this also
// checks that it is there or not, and in which corner, after creation, after
// toggling, and after a position change made while it was hidden.
//
// It imports package:web, which does not compile for Android or iOS, so it
// is not part of all_tests.dart. Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/attribution_web_test.dart \
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

const _camera = CameraPosition(target: LatLng(0, 0), zoom: 3);

const _topLeft = '.maplibregl-ctrl-top-left';
const _bottomLeft = '.maplibregl-ctrl-bottom-left';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('attributionEnabled on web', () {
    testWidgets('a map created hidden has no attribution control', (
      tester,
    ) async {
      if (!kIsWeb) return;
      await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) =>
                _map(onMapCreated, onStyleLoaded, enabled: false),
      );

      expect(_attributions(), 0);
    });

    testWidgets('a map created shown has one, in its corner', (tester) async {
      if (!kIsWeb) return;
      await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) =>
                _map(onMapCreated, onStyleLoaded, enabled: true),
      );

      expect(_attributions(), 1);
      expect(_attributions(_topLeft), 1);
    });

    testWidgets('toggling adds and removes the control', (tester) async {
      if (!kIsWeb) return;
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
      expect(_attributions(), 0);

      for (final enabled in [true, false, true]) {
        await _update(
          tester,
          controller,
          _map(created, styleLoaded, enabled: enabled),
          'attributionEnabled: $enabled',
        );
        expect(_attributions(), enabled ? 1 : 0, reason: '$enabled');
        expect(_attributions(_topLeft), enabled ? 1 : 0, reason: '$enabled');
      }
    });

    testWidgets('a position set while hidden is used once shown', (
      tester,
    ) async {
      if (!kIsWeb) return;
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
      expect(_attributions(), 0);

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
      expect(_attributions(), 1);
      expect(_attributions(_bottomLeft), 1);
      expect(_attributions(_topLeft), 0);
    });
  });
}

/// The number of attribution controls in the page, or in the control corner
/// matched by [corner].
int _attributions([String? corner]) =>
    web.document
        .querySelectorAll(
          corner == null
              ? '.maplibregl-ctrl-attrib'
              : '$corner .maplibregl-ctrl-attrib',
        )
        .length;

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
