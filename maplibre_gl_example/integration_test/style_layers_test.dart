// Integration test for style sources and layers driven through the controller.
//
// Covers adding and removing sources (addSource, addGeoJsonSource,
// removeSource), every layer type that works offline (fill, line, circle,
// symbol, background, heatmap, fill-extrusion), the generic addLayer and the
// filter it carries, belowLayerId ordering, reading layers and sources back
// (getLayerIds, getSourceIds, getLayerProperties, getSourceProperties),
// setLayerProperties, layer visibility (setLayerVisibility and the batch
// setLayersVisibility), setLayerZoomRange, and the edge cases
// around unknown and duplicate ids.
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

import 'package:flutter/services.dart' show PlatformException;
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
    expect(runtime, isNotNull);
    expect(runtime!['type'], 'geojson');
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

  testWidgets('addLayer applies the filter of fill extrusion and heatmap '
      'layers (#360)', (tester) async {
    final controller = await _pumpMapWithSource(tester);

    const filter = [
      '==',
      ['get', 'n'],
      2,
    ];
    const layers = <String, LayerProperties>{
      'f-extrusion': FillExtrusionLayerProperties(fillExtrusionHeight: 100),
      'f-heatmap': HeatmapLayerProperties(heatmapRadius: 20),
    };
    for (final entry in layers.entries) {
      await pumpUntil(
        tester,
        controller.addLayer(_sourceId, entry.key, entry.value, filter: filter),
        'addLayer ${entry.key}',
      );
      final applied = await pumpUntil(
        tester,
        controller.getLayerFilter(entry.key),
        'getLayerFilter ${entry.key}',
      );
      expect(applied, filter, reason: '${entry.key} should keep its filter');
    }

    // addHeatmapLayer takes the filter directly as well.
    await pumpUntil(
      tester,
      controller.addHeatmapLayer(
        _sourceId,
        'direct-heatmap',
        const HeatmapLayerProperties(heatmapRadius: 20),
        filter: filter,
      ),
      'addHeatmapLayer',
    );
    expect(
      await pumpUntil(
        tester,
        controller.getLayerFilter('direct-heatmap'),
        'getLayerFilter direct-heatmap',
      ),
      filter,
    );
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

  testWidgets('setLayerZoomRange round trips through getLayerProperties', (
    tester,
  ) async {
    final controller = await pumpMap(tester, styleString: _styleWithSource());

    await pumpUntil(
      tester,
      controller.setLayerZoomRange('styled-circles', 5.5, 12),
      'setLayerZoomRange 5.5 12',
    );
    final narrowed = await pumpUntil(
      tester,
      controller.getLayerProperties('styled-circles'),
      'getLayerProperties narrowed',
    );
    expect(narrowed!['minzoom'], 5.5);
    expect(narrowed['maxzoom'], 12);

    // The spec defaults are left out on every platform, as for a layer that
    // never set a range.
    await pumpUntil(
      tester,
      controller.setLayerZoomRange('styled-circles', 0, 24),
      'setLayerZoomRange 0 24',
    );
    final full = await pumpUntil(
      tester,
      controller.getLayerProperties('styled-circles'),
      'getLayerProperties full',
    );
    expect(full, isNot(contains('minzoom')));
    expect(full, isNot(contains('maxzoom')));
  });

  testWidgets('setLayerZoomRange applies to a layer added at runtime', (
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
    await pumpUntil(
      tester,
      controller.setLayerZoomRange('circle', 3, 9.5),
      'setLayerZoomRange',
    );
    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('circle'),
      'getLayerProperties',
    );
    expect(properties!['minzoom'], 3);
    expect(properties['maxzoom'], 9.5);
  });

  testWidgets('setLayerZoomRange rejects an unknown layer and a bad range', (
    tester,
  ) async {
    final controller = await pumpMap(tester, styleString: _styleWithSource());

    await expectPlatformError(
      tester,
      controller.setLayerZoomRange('no-such-layer', 2, 10),
      'setLayerZoomRange unknown',
      code: 'LAYER_NOT_FOUND_ERROR',
    );
    for (final (minzoom, maxzoom) in [(10.0, 2.0), (-1.0, 10.0), (2.0, 25.0)]) {
      await expectPlatformError(
        tester,
        controller.setLayerZoomRange('styled-circles', minzoom, maxzoom),
        'setLayerZoomRange $minzoom $maxzoom',
        code: 'INVALID_ARGUMENT',
      );
    }
    // A bad range is checked before the layer is looked up.
    await expectPlatformError(
      tester,
      controller.setLayerZoomRange('no-such-layer', 10, 2),
      'setLayerZoomRange unknown, bad range',
      code: 'INVALID_ARGUMENT',
    );

    // Nothing was applied.
    final styled = await pumpUntil(
      tester,
      controller.getLayerProperties('styled-circles'),
      'getLayerProperties styled-circles',
    );
    expect(styled!['minzoom'], 1);
    expect(styled['maxzoom'], 15);
  });

  testWidgets('setLayerZoomRange rejects a bad range before the style loads', (
    tester,
  ) async {
    // onMapCreated runs before onStyleLoadedCallback, so calls made from it
    // reach a platform whose style is usually still loading. A valid range
    // sent alongside answers STYLE_NOT_READY then, or LAYER_NOT_FOUND_ERROR
    // when the style was already in; the bad range must fail the same way
    // either way.
    late Future<Object?> badRange;
    late Future<Object?> validRange;
    Future<Object?> errorOf(Future<void> call) =>
        call.then<Object?>((_) => null, onError: (Object e) => e);

    await pumpMap(
      tester,
      builder:
          (onMapCreated, onStyleLoaded) => MapLibreMap(
            styleString: offlineStyle,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 3,
            ),
            onMapCreated: (controller) {
              badRange = errorOf(controller.setLayerZoomRange('x', 10, 2));
              validRange = errorOf(controller.setLayerZoomRange('x', 2, 10));
              onMapCreated(controller);
            },
            onStyleLoadedCallback: onStyleLoaded,
          ),
    );

    final bad = await pumpUntil(tester, badRange, 'bad range');
    expect(
      bad,
      isA<PlatformException>().having(
        (e) => e.code,
        'code',
        'INVALID_ARGUMENT',
      ),
    );
    final valid = await pumpUntil(tester, validRange, 'valid range');
    expect(
      valid,
      isA<PlatformException>().having(
        (e) => e.code,
        'code',
        anyOf('STYLE_NOT_READY', 'LAYER_NOT_FOUND_ERROR'),
      ),
    );
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

  testWidgets('getLayerProperties reads values back in the shape they were '
      'set, and leaves out what was never set', (tester) async {
    final controller = await _pumpMapWithSource(tester);
    const radius = [
      'interpolate',
      ['linear'],
      ['zoom'],
      5,
      1,
      10,
      4,
    ];
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        'circle',
        const CircleLayerProperties(
          circleRadius: radius,
          circleTranslate: [1, 2],
          circlePitchAlignment: 'map',
          // The default value, which still counts as set.
          circleOpacity: 1,
        ),
      ),
      'addCircleLayer',
    );

    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('circle'),
      'getLayerProperties',
    );
    expect(properties!['paint'], {
      'circle-radius': radius,
      'circle-translate': [1, 2],
      'circle-pitch-alignment': 'map',
      'circle-opacity': 1,
    });
  });

  testWidgets('setLayerProperties on a layer of the style resets what it '
      'leaves null', (tester) async {
    final controller = await pumpMap(tester, styleString: _styleWithSource());

    // Sends every circle property, so the style's circle-radius goes back to
    // its default and reads as never set.
    await pumpUntil(
      tester,
      controller.setLayerProperties(
        'styled-circles',
        const CircleLayerProperties(circleBlur: 0.5),
      ),
      'setLayerProperties',
    );
    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('styled-circles'),
      'getLayerProperties',
    );
    expect(properties!['paint'], {'circle-blur': 0.5});
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
    // covered even where getLayerVisibility is not answered.
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

    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('circle'),
      'getLayerProperties',
    );
    expect((properties!['layout'] as Map)['visibility'], 'none');
  });

  testWidgets('setLayersVisibility hides and shows several layers at once', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    final layerIds = await _addCircleLayers(tester, controller, 3);

    // A repeated id is harmless.
    expect(
      await pumpUntil(
        tester,
        controller.setLayersVisibility([...layerIds, layerIds.first], false),
        'setLayersVisibility false',
      ),
      isEmpty,
    );
    for (final layerId in layerIds) {
      expect(
        await pumpUntil(
          tester,
          controller.getLayerVisibility(layerId),
          'getLayerVisibility $layerId hidden',
        ),
        isFalse,
      );
    }

    await pumpUntil(
      tester,
      controller.setLayersVisibility(layerIds, true),
      'setLayersVisibility true',
    );
    for (final layerId in layerIds) {
      expect(
        await pumpUntil(
          tester,
          controller.getLayerVisibility(layerId),
          'getLayerVisibility $layerId shown',
        ),
        isTrue,
      );
    }
  });

  testWidgets('setLayersVisibility skips unknown ids and returns them', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    final layerIds = await _addCircleLayers(tester, controller, 2);

    // Unknown ids around and between known ones, one of them repeated.
    final missing = await pumpUntil(
      tester,
      controller.setLayersVisibility([
        layerIds[0],
        'no-such-layer',
        layerIds[1],
        'other-missing-layer',
        'no-such-layer',
      ], false),
      'setLayersVisibility unknown',
    );
    expect(missing, ['no-such-layer', 'other-missing-layer']);

    // The known layers were still hidden.
    for (final layerId in layerIds) {
      expect(
        await pumpUntil(
          tester,
          controller.getLayerVisibility(layerId),
          'getLayerVisibility $layerId after skipped ids',
        ),
        isFalse,
      );
    }
  });

  testWidgets('setLayersVisibility with an empty list succeeds', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    final layerIds = await _addCircleLayers(tester, controller, 1);

    expect(
      await pumpUntil(
        tester,
        controller.setLayersVisibility(const [], false),
        'setLayersVisibility empty',
      ),
      isEmpty,
    );
    expect(
      await pumpUntil(
        tester,
        controller.getLayerVisibility(layerIds.single),
        'getLayerVisibility after empty call',
      ),
      isTrue,
    );
  });

  testWidgets(
    'an unknown layer is LAYER_NOT_FOUND_ERROR, an unknown source a no-op',
    (
      tester,
    ) async {
      final controller = await _pumpMapWithSource(tester);
      final layersBefore = await _layerIds(tester, controller);
      final sourcesBefore = await _sourceIds(tester, controller);

      // A layer call names one layer, so a missing one is reported, as for
      // setLayerProperties. Removing a source stays idempotent.
      await expectPlatformError(
        tester,
        controller.removeLayer('no-such-layer'),
        'removeLayer unknown',
        code: 'LAYER_NOT_FOUND_ERROR',
      );
      await expectPlatformError(
        tester,
        controller.setLayerVisibility('no-such-layer', false),
        'setLayerVisibility unknown',
        code: 'LAYER_NOT_FOUND_ERROR',
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
    },
  );

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
      code: 'SOURCE_ALREADY_EXISTS',
    );
    await expectPlatformError(
      tester,
      controller.addSource(
        _sourceId,
        GeojsonSourceProperties(data: pointCollection(count: 1)),
      ),
      'addSource duplicate',
      code: 'SOURCE_ALREADY_EXISTS',
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
      code: 'LAYER_ALREADY_EXISTS',
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
      code: 'LAYER_ALREADY_EXISTS',
    );

    final ids = await _layerIds(tester, controller);
    expect(ids.where((id) => id == 'circle'), hasLength(1));
    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties('circle'),
      'getLayerProperties',
    );
    expect(properties!['type'], 'circle');
    expect((properties['paint'] as Map)['circle-radius'], 4);
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

  testWidgets('moveLayer reorders layers and keeps them on errors', (
    tester,
  ) async {
    final controller = await _pumpMapWithSource(tester);
    for (final id in ['a', 'b', 'c']) {
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          id,
          const CircleLayerProperties(circleRadius: 4),
        ),
        'addCircleLayer $id',
      );
    }

    await pumpUntil(
      tester,
      controller.moveLayer('c', belowLayerId: 'a'),
      'move c below a',
    );
    var ids = await _layerIds(tester, controller);
    expect(ids.indexOf('c'), lessThan(ids.indexOf('a')));
    expect(ids.indexOf('a'), lessThan(ids.indexOf('b')));

    await pumpUntil(tester, controller.moveLayer('c'), 'move c to the top');
    ids = await _layerIds(tester, controller);
    expect(ids.last, 'c');

    // A layer cannot go below itself: the call succeeds and nothing moves.
    await pumpUntil(
      tester,
      controller.moveLayer('a', belowLayerId: 'a'),
      'move a below itself',
    );
    expect(await _layerIds(tester, controller), ids);

    // A missing anchor fails before anything moves, so the layer stays.
    await expectPlatformError(
      tester,
      controller.moveLayer('a', belowLayerId: 'no-such-layer'),
      'move below unknown',
      code: 'LAYER_NOT_FOUND_ERROR',
    );
    await expectPlatformError(
      tester,
      controller.moveLayer('no-such-layer'),
      'move unknown',
      code: 'LAYER_NOT_FOUND_ERROR',
    );
    expect(await _layerIds(tester, controller), ids);
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

/// The offline style with a GeoJSON source and a circle layer baked in.
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

/// Adds [count] circle layers on the test source and returns their ids.
Future<List<String>> _addCircleLayers(
  WidgetTester tester,
  MapLibreMapController controller,
  int count,
) async {
  final layerIds = [for (var i = 0; i < count; i++) 'circle-$i'];
  for (final layerId in layerIds) {
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _sourceId,
        layerId,
        const CircleLayerProperties(circleRadius: 4),
      ),
      'addCircleLayer $layerId',
    );
  }
  return layerIds;
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
