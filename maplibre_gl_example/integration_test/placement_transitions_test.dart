// Integration test for MapLibreMap.symbolPlacementTransitionsEnabled and
// MapLibreMapController.setSymbolPlacementTransitionsEnabled.
//
// Each platform switches a different thing (the style's transition options on
// Android, MLNStyle.performsPlacementTransitions on iOS, the map's symbol fade
// duration on web), which a unit test with a mocked channel never reaches. The
// fade itself cannot be measured from a test, so these tests check what can
// be: the option is accepted at creation and at runtime, a symbol added while
// transitions are off is drawn without the camera moving, and the setting
// survives a style change.
import 'dart:math' show Point;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'placement-points';
const _layerId = 'placement-symbols';
const _camera = CameraPosition(target: LatLng(0, 2), zoom: 4);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('placementTransitions', () {
    testWidgets('a map created with them off draws its symbols', (
      tester,
    ) async {
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: _camera,
              symbolPlacementTransitionsEnabled: false,
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
            ),
      );
      await _addSymbols(tester, controller, pointCollection(count: 1));

      await _waitForSymbol(tester, controller, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a symbol added while they are off is drawn at once', (
      tester,
    ) async {
      final controller = await pumpMap(
        tester,
        initialCameraPosition: _camera,
      );
      await _addSymbols(tester, controller, pointCollection(count: 1));
      await _waitForSymbol(tester, controller, 1);

      await pumpUntil(
        tester,
        controller.setSymbolPlacementTransitionsEnabled(false),
        'transitions off',
      );
      await pumpUntil(
        tester,
        controller.setGeoJsonSource(_sourceId, pointCollection(count: 3)),
        'setGeoJsonSource',
      );
      // The camera does not move, so only the repaint after the update can
      // bring the new symbol to the screen.
      await _waitForSymbol(tester, controller, 3);

      await pumpUntil(
        tester,
        controller.setSymbolPlacementTransitionsEnabled(true),
        'transitions on',
      );
      await _waitForSymbol(tester, controller, 3);
      // Turning them off and on twice in a row is harmless.
      for (final enabled in [false, false, true, true]) {
        await pumpUntil(
          tester,
          controller.setSymbolPlacementTransitionsEnabled(enabled),
          'transitions $enabled',
        );
      }
      await _waitForSymbol(tester, controller, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the setting survives a style change', (tester) async {
      var styleLoads = 0;
      final controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: _camera,
              symbolPlacementTransitionsEnabled: false,
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: () {
                styleLoads++;
                onStyleLoaded();
              },
            ),
      );

      await pumpUntil(
        tester,
        controller.setStyle(offlineStyle),
        'setStyle',
      );
      await pumpUntilValue(
        tester,
        () async => styleLoads,
        (loads) => loads >= 2,
        'second style load',
      );
      await _addSymbols(tester, controller, pointCollection(count: 2));
      await _waitForSymbol(tester, controller, 2);

      await pumpUntil(
        tester,
        controller.setSymbolPlacementTransitionsEnabled(true),
        'transitions on after the style change',
      );
      await _waitForSymbol(tester, controller, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Adds an icon, a GeoJSON source with [data] and a symbol layer drawing it.
/// Icons need no glyphs, so this works with the offline style.
Future<void> _addSymbols(
  WidgetTester tester,
  MapLibreMapController controller,
  Map<String, dynamic> data,
) async {
  final png =
      (await rootBundle.load(
        'assets/symbols/custom-marker.png',
      )).buffer.asUint8List();
  await pumpUntil(tester, controller.addImage('marker', png), 'addImage');
  await pumpUntil(
    tester,
    controller.addGeoJsonSource(_sourceId, data),
    'addGeoJsonSource',
  );
  await pumpUntil(
    tester,
    controller.addSymbolLayer(
      _sourceId,
      _layerId,
      const SymbolLayerProperties(iconImage: 'marker', iconAllowOverlap: true),
    ),
    'addSymbolLayer',
  );
}

/// Waits until the symbol of the point with id [id] (at longitude [id] on the
/// equator, see [pointCollection]) is rendered.
Future<void> _waitForSymbol(
  WidgetTester tester,
  MapLibreMapController controller,
  int id,
) async {
  final screen = await pumpUntil(
    tester,
    controller.toScreenLocation(LatLng(0, id.toDouble())),
    'toScreenLocation $id',
  );
  final point = Point<double>(screen.x.toDouble(), screen.y.toDouble());
  await pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [_layerId], null),
    (features) => features.cast<Map>().any(
      (f) => (f['properties'] as Map?)?['n'].toString() == '$id',
    ),
    'symbol $id rendered',
  );
}
