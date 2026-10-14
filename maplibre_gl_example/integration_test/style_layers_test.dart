// Integration test for style sources and layers driven through the controller.
//
// Covers adding and removing sources (addSource, addGeoJsonSource,
// removeSource), every layer type that works offline (fill, line, circle,
// symbol, background, heatmap, fill-extrusion), the generic addLayer,
// belowLayerId ordering, reading layers and sources back
// (getLayerIds, getSourceIds, getLayerProperties, getSourceProperties),
// setLayerProperties, layer visibility, and the edge cases around unknown and
// duplicate ids.
//
// Each of these calls ends in the native style (MapLibre Native on Android and
// iOS, maplibre-gl-js on web), and the three answer edge cases differently, so
// only a live map can tell whether they agree. Every map is built from the
// offline style in the harness, so no test needs the network.
//
// Run on Android or iOS:
//   flutter test integration_test/style_layers_test.dart -d <device id>
//
// Run on Chrome (with chromedriver on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/style_layers_test.dart -d chrome
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'points';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('addSource, addGeoJsonSource and removeSource update '
      'getSourceIds', (tester) async {
    final controller = await pumpMap(tester);

    final before = await _sourceIds(tester, controller);
    expect(before, isNot(contains('inline')));
    expect(before, isNot(contains('geojson')));

    await pumpUntil(
      tester,
      controller.addSource(
        'inline',
        GeojsonSourceProperties(data: pointCollection()),
      ),
      'addSource',
    );
    expect(await _sourceIds(tester, controller), contains('inline'));

    await pumpUntil(
      tester,
      controller.addGeoJsonSource('geojson', pointCollection(count: 2)),
      'addGeoJsonSource',
    );
    final both = await _sourceIds(tester, controller);
    expect(both, containsAll(<String>['inline', 'geojson']));

    await pumpUntil(
      tester,
      controller.removeSource('inline'),
      'removeSource inline',
    );
    final afterFirst = await _sourceIds(tester, controller);
    expect(afterFirst, isNot(contains('inline')));
    expect(afterFirst, contains('geojson'));

    await pumpUntil(
      tester,
      controller.removeSource('geojson'),
      'removeSource geojson',
    );
    final afterBoth = await _sourceIds(tester, controller);
    expect(afterBoth, isNot(contains('geojson')));
    // Whatever the platform keeps internally is untouched by the round trip.
    expect(afterBoth.toSet(), before.toSet());
  });

  testWidgets('getSourceProperties describes a geojson source', (tester) async {
    // A source that came with the style is readable on every platform, so the
    // shape is pinned on it first.
    final controller = await pumpMap(tester, styleString: _styleWithSource());

    final styled = await pumpUntil(
      tester,
      controller.getSourceProperties('styled'),
      'getSourceProperties styled',
    );
    expect(styled, isNotNull);
    expect(styled!['type'], 'geojson');

    await pumpUntil(
      tester,
      controller.addSource(
        'runtime',
        GeojsonSourceProperties(data: pointCollection()),
      ),
      'addSource',
    );
    final runtime = await pumpUntil(
      tester,
      controller.getSourceProperties('runtime'),
      'getSourceProperties runtime',
    );
    if (testPlatform == TestPlatform.ios) {
      // Documented on getSourceProperties: iOS reads the style as it was
      // loaded, so a source added at runtime is not in it (#985).
      expect(runtime, isNull);
    } else {
      expect(runtime, isNotNull);
      expect(runtime!['type'], 'geojson');
    }
  });

  testWidgets('each offline layer type can be added and removed', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);

    await pumpUntil(
      tester,
      controller.addFillLayer(
        _sourceId,
        'fill',
        const FillLayerProperties(fillOpacity: 0.5),
      ),
      'addFillLayer',
    );
    await pumpUntil(
      tester,
      controller.addLineLayer(
        _sourceId,
        'line',
        const LineLayerProperties(lineWidth: 2),
      ),
      'addLineLayer',
    );
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer',
    );
    // An icon that is not in the style: the layer is valid even though it has
    // nothing to draw, and it needs neither glyphs nor a sprite.
    await pumpUntil(
      tester,
      controller.addSymbolLayer(
        _sourceId,
        'symbol',
        const SymbolLayerProperties(iconImage: 'missing-icon', iconSize: 1.5),
      ),
      'addSymbolLayer',
    );
    await pumpUntil(
      tester,
      controller.addHeatmapLayer(
        _sourceId,
        'heatmap',
        const HeatmapLayerProperties(heatmapRadius: 20),
      ),
      'addHeatmapLayer',
    );
    await pumpUntil(
      tester,
      controller.addFillExtrusionLayer(
        _sourceId,
        'extrusion',
        const FillExtrusionLayerProperties(fillExtrusionHeight: 100),
      ),
      'addFillExtrusionLayer',
    );
    await pumpUntil(
      tester,
      controller.addBackgroundLayer(
        'second-background',
        const BackgroundLayerProperties(backgroundOpacity: 0.5),
      ),
      'addBackgroundLayer',
    );

    const added = [
      'fill',
      'line',
      'circle',
      'symbol',
      'heatmap',
      'extrusion',
      'second-background',
    ];
    expect(await _layerIds(tester, controller), containsAll(added));

    for (final id in added) {
      await pumpUntil(tester, controller.removeLayer(id), 'removeLayer $id');
      expect(
        await _layerIds(tester, controller),
        isNot(contains(id)),
        reason: '$id should be gone after removeLayer',
      );
    }
    // The style's own layer is untouched.
    expect(await _layerIds(tester, controller), contains(backgroundLayerId));
  });

  testWidgets('addLayer dispatches every offline layer type', (tester) async {
    final controller = await _pumpMapWithSource(tester);

    const layers = <String, LayerProperties>{
      'g-fill': FillLayerProperties(fillOpacity: 0.5),
      'g-line': LineLayerProperties(lineWidth: 2),
      'g-circle': CircleLayerProperties(circleRadius: 4),
      'g-symbol': SymbolLayerProperties(iconImage: 'missing-icon'),
      'g-heatmap': HeatmapLayerProperties(heatmapRadius: 20),
      'g-extrusion': FillExtrusionLayerProperties(fillExtrusionHeight: 100),
      'g-background': BackgroundLayerProperties(backgroundOpacity: 0.5),
    };
    for (final entry in layers.entries) {
      await pumpUntil(
        tester,
        controller.addLayer(_sourceId, entry.key, entry.value),
        'addLayer ${entry.key}',
      );
    }

    final ids = await _layerIds(tester, controller);
    expect(ids, containsAll(layers.keys));
    // Without belowLayerId each layer goes on top, so they stack in the order
    // they were added.
    final positions = [for (final id in layers.keys) ids.indexOf(id)];
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('belowLayerId inserts the layer under its anchor', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);

    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'top',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer top',
    );
    await pumpUntil(
      tester,
      controller.addLineLayer(
        _sourceId,
        'under-top',
        const LineLayerProperties(lineWidth: 2),
        belowLayerId: 'top',
      ),
      'addLineLayer under-top',
    );
    await pumpUntil(
      tester,
      controller.addLayer(
        _sourceId,
        'under-background',
        const FillLayerProperties(fillOpacity: 0.5),
        belowLayerId: backgroundLayerId,
      ),
      'addLayer under-background',
    );

    final ids = await _layerIds(tester, controller);
    expect(ids.indexOf('under-top'), lessThan(ids.indexOf('top')));
    expect(
      ids.indexOf('under-top'),
      greaterThan(ids.indexOf(backgroundLayerId)),
    );
    expect(
      ids.indexOf('under-background'),
      lessThan(ids.indexOf(backgroundLayerId)),
    );
  });

  testWidgets('getLayerProperties reports id, type, source, zoom range, '
      'paint and layout', (tester) async {
    final controller = await pumpMap(tester, styleString: _styleWithSource());

    // A layer that came with the style is readable on every platform.
    final styled = await pumpUntil(
      tester,
      controller.getLayerProperties('styled-circles'),
      'getLayerProperties styled-circles',
    );
    expect(styled, isNotNull);
    expect(styled!['id'], 'styled-circles');
    expect(styled['type'], 'circle');
    expect(styled['source'], 'styled');
    expect(styled['minzoom'], 1);
    expect(styled['maxzoom'], 15);
    expect((styled['paint'] as Map)['circle-radius'], 5);

    await pumpUntil(
      tester,
      controller.addLineLayer(
        'styled',
        'runtime-line',
        const LineLayerProperties(
          lineWidth: 3,
          lineOpacity: 0.5,
          lineCap: 'round',
        ),
        minzoom: 2,
        maxzoom: 12,
      ),
      'addLineLayer',
    );
    final runtime = await pumpUntil(
      tester,
      controller.getLayerProperties('runtime-line'),
      'getLayerProperties runtime-line',
    );
    if (testPlatform == TestPlatform.ios) {
      // Documented on getLayerProperties: iOS reads the style as it was
      // loaded, so a layer added at runtime is not in it (#985).
      expect(runtime, isNull);
      return;
    }
    expect(runtime, isNotNull);
    expect(runtime!['id'], 'runtime-line');
    expect(runtime['type'], 'line');
    expect(runtime['source'], 'styled');
    // Numbers are read as num: the shared shaping turns 2.0 into 2 everywhere.
    expect(runtime['minzoom'], 2);
    expect(runtime['maxzoom'], 12);
    final paint = runtime['paint'] as Map;
    expect(paint['line-width'], 3);
    expect(paint['line-opacity'], 0.5);
    expect((runtime['layout'] as Map)['line-cap'], 'round');
  });

  testWidgets('setLayerProperties round trips through getLayerProperties', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);

    await pumpUntil(
      tester,
      controller.addLineLayer(
        _sourceId,
        'line',
        const LineLayerProperties(lineWidth: 1, lineCap: 'butt'),
      ),
      'addLineLayer',
    );
    await pumpUntil(
      tester,
      controller.setLayerProperties(
        'line',
        const LineLayerProperties(
          lineWidth: 6,
          lineOpacity: 0.25,
          lineCap: 'round',
        ),
      ),
      'setLayerProperties',
    );

    // A failed set would surface above; reading back needs a runtime layer,
    // which iOS cannot read (#985), so there only the call is checked.
    if (testPlatform == TestPlatform.ios) return;

    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('line'),
      'getLayerProperties',
    );
    expect(properties, isNotNull);
    final paint = properties!['paint'] as Map;
    expect(paint['line-width'], 6);
    expect(paint['line-opacity'], 0.25);
    expect((properties['layout'] as Map)['line-cap'], 'round');
  });

  testWidgets('setLayerVisibility round trips through getLayerVisibility', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);

    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer',
    );
    // A new layer is visible until told otherwise.
    expect(
      await pumpUntil(
        tester,
        controller.getLayerVisibility('circle'),
        'getLayerVisibility initial',
      ),
      isTrue,
    );

    await pumpUntil(
      tester,
      controller.setLayerVisibility('circle', false),
      'setLayerVisibility false',
    );
    expect(
      await pumpUntil(
        tester,
        controller.getLayerVisibility('circle'),
        'getLayerVisibility hidden',
      ),
      isFalse,
    );

    await pumpUntil(
      tester,
      controller.setLayerVisibility('circle', true),
      'setLayerVisibility true',
    );
    expect(
      await pumpUntil(
        tester,
        controller.getLayerVisibility('circle'),
        'getLayerVisibility shown',
      ),
      isTrue,
    );
  });

  testWidgets('setLayerVisibility shows up in the layer layout', (
    tester,
  ) async {
    // Reads visibility back through getLayerProperties, so the setter is
    // covered even where getLayerVisibility is not answered. iOS cannot read a
    // runtime layer back (#985), so there only the call itself is checked.
    final controller = await _pumpMapWithSource(tester);

    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer',
    );
    await pumpUntil(
      tester,
      controller.setLayerVisibility('circle', false),
      'setLayerVisibility false',
    );
    if (testPlatform == TestPlatform.ios) return;

    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('circle'),
      'getLayerProperties',
    );
    expect((properties!['layout'] as Map)['visibility'], 'none');
  });

  testWidgets('removing an unknown layer or source is a no-op', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    final layersBefore = await _layerIds(tester, controller);
    final sourcesBefore = await _sourceIds(tester, controller);

    await pumpUntil(
      tester,
      controller.removeLayer('no-such-layer'),
      'removeLayer unknown',
    );
    await pumpUntil(
      tester,
      controller.removeSource('no-such-source'),
      'removeSource unknown',
    );

    expect(await _layerIds(tester, controller), layersBefore);
    expect(
      (await _sourceIds(tester, controller)).toSet(),
      sourcesBefore.toSet(),
    );
  });

  testWidgets('removing a source still used by a layer keeps both', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer',
    );

    // Every engine refuses to orphan a layer; the call itself does not fail.
    await pumpUntil(
      tester,
      controller.removeSource(_sourceId),
      'removeSource in use',
    );
    expect(await _sourceIds(tester, controller), contains(_sourceId));
    expect(await _layerIds(tester, controller), contains('circle'));

    // Once the layer is gone the same call goes through.
    await pumpUntil(tester, controller.removeLayer('circle'), 'removeLayer');
    await pumpUntil(
      tester,
      controller.removeSource(_sourceId),
      'removeSource free',
    );
    expect(await _sourceIds(tester, controller), isNot(contains(_sourceId)));
  });

  testWidgets('adding a duplicate source id fails and keeps the original', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);

    // Silently keeping the first source would make the caller believe its new
    // data is on the map, so a clash is reported.
    await expectPlatformError(
      tester,
      controller.addGeoJsonSource(_sourceId, pointCollection(count: 1)),
      'addGeoJsonSource duplicate',
    );
    await expectPlatformError(
      tester,
      controller.addSource(
        _sourceId,
        GeojsonSourceProperties(data: pointCollection(count: 1)),
      ),
      'addSource duplicate',
    );

    final ids = await _sourceIds(tester, controller);
    expect(ids.where((id) => id == _sourceId), hasLength(1));
  });

  testWidgets('adding a duplicate layer id fails and keeps the original', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer',
    );

    await expectPlatformError(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(circleRadius: 9),
      ),
      'addCircleLayer duplicate',
    );
    // Same id, different type: still a clash.
    await expectPlatformError(
      tester,
      controller.addFillLayer(
        _sourceId,
        'circle',
        const FillLayerProperties(fillOpacity: 0.5),
      ),
      'addFillLayer duplicate',
    );

    final ids = await _layerIds(tester, controller);
    expect(ids.where((id) => id == 'circle'), hasLength(1));
    if (testPlatform != TestPlatform.ios) {
      final properties = await pumpUntil(
        tester,
        controller.getLayerProperties('circle'),
        'getLayerProperties',
      );
      expect(properties!['type'], 'circle');
      expect((properties['paint'] as Map)['circle-radius'], 4);
    }
  });

  testWidgets('getLayerProperties and getSourceProperties answer null for an '
      'unknown id', (tester) async {
    final controller = await pumpMap(tester);

    expect(
      await pumpUntil(
        tester,
        controller.getLayerProperties('no-such-layer'),
        'getLayerProperties unknown',
      ),
      isNull,
    );
    expect(
      await pumpUntil(
        tester,
        controller.getSourceProperties('no-such-source'),
        'getSourceProperties unknown',
      ),
      isNull,
    );
  });

  testWidgets('getLayerVisibility answers null for an unknown layer', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    expect(
      await pumpUntil(
        tester,
        controller.getLayerVisibility('no-such-layer'),
        'getLayerVisibility unknown',
      ),
      isNull,
    );
  });

  testWidgets('setLayerProperties on an unknown layer fails', (tester) async {
    final controller = await pumpMap(tester);

    await expectPlatformError(
      tester,
      controller.setLayerProperties(
        'no-such-layer',
        const LineLayerProperties(lineWidth: 2),
      ),
      'setLayerProperties unknown',
      code: 'LAYER_NOT_FOUND_ERROR',
    );
  });
}

/// A map with the offline style plus a GeoJSON source of three points.
Future<MapLibreMapController> _pumpMapWithSource(WidgetTester tester) async {
  final controller = await pumpMap(tester);
  await pumpUntil(
    tester,
    controller.addGeoJsonSource(_sourceId, pointCollection()),
    'addGeoJsonSource',
  );
  return controller;
}

/// The offline style with a GeoJSON source and a circle layer baked in, for
/// reads that iOS only answers for what came with the style (#985).
String _styleWithSource() {
  final style = jsonDecode(offlineStyle) as Map<String, dynamic>;
  style['sources'] = {
    'styled': {'type': 'geojson', 'data': pointCollection()},
  };
  (style['layers'] as List).add({
    'id': 'styled-circles',
    'type': 'circle',
    'source': 'styled',
    'minzoom': 1,
    'maxzoom': 15,
    'paint': {'circle-radius': 5},
  });
  return jsonEncode(style);
}

Future<List<String>> _layerIds(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final ids = await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds');
  return ids.map((id) => id.toString()).toList();
}

Future<List<String>> _sourceIds(
  WidgetTester tester,
  MapLibreMapController controller,
) => pumpUntil(tester, controller.getSourceIds(), 'getSourceIds');
