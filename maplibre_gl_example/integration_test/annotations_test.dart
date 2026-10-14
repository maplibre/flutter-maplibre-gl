// Integration tests for the annotation API (symbols, lines, circles, fills)
// and for style images.
//
// The annotation managers live in Dart, but each one owns real GeoJSON
// sources and style layers and pushes every add, update and remove through
// the platform. A unit test can only see the Dart bookkeeping; whether the
// data actually reached the native source, whether the layers sit in the
// order the widget asked for, and whether an image added at runtime can be
// drawn by a symbol all need a live map. So each check reads back from the
// map: getLayerIds/getSourceIds, querySourceFeatures on the manager source,
// and queryRenderedFeatures where something has to be drawn.
//
// Run on Android or iOS:
//   flutter test integration_test/annotations_test.dart -d <device id>
//
// Run on Chrome (with chromedriver on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/annotations_test.dart -d chrome
import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

/// [offlineStyle] plus a `glyphs` URL.
///
/// The symbol manager's layer always sets `text-field`, and maplibre-gl-js
/// refuses a layer with `text-field` when the style has no `glyphs`, so on web
/// the symbol layer would silently never be added. The URL is never fetched:
/// no test here gives a symbol any text, so no glyph is ever requested.
final String _annotationStyle = jsonEncode({
  ...jsonDecode(offlineStyle) as Map<String, dynamic>,
  'glyphs': 'http://127.0.0.1:9/{fontstack}/{range}.pbf',
});

const _initialCamera = CameraPosition(target: LatLng(0, 0), zoom: 4);

const List<AnnotationType> _defaultOrder = [
  AnnotationType.line,
  AnnotationType.symbol,
  AnnotationType.circle,
  AnnotationType.fill,
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('symbols: add, update, remove and clear reach the source', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);
    final manager = controller.symbolManager!;
    final sourceId = manager.layerIds.single;

    // The manager's layer and its same-named source exist natively.
    final layers = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    expect(layers, contains(sourceId));
    final sources = await pumpUntil(
      tester,
      controller.getSourceIds(),
      'sources',
    );
    expect(sources, contains(sourceId));

    final first = await pumpUntil(
      tester,
      controller.addSymbol(const SymbolOptions(geometry: LatLng(1, 1)), {
        'tag': 'first',
      }),
      'addSymbol',
    );
    final more = await pumpUntil(
      tester,
      controller.addSymbols([
        const SymbolOptions(geometry: LatLng(-1, -1)),
        const SymbolOptions(geometry: LatLng(2, -2)),
      ]),
      'addSymbols',
    );
    expect(more, hasLength(2));
    expect(controller.symbols, {first, ...more});
    expect(controller.getSymbolLatLng(first), const LatLng(1, 1));

    var features = await _waitForIds(tester, controller, sourceId, {
      first.id,
      ...more.map((s) => s.id),
    }, 'symbols added');
    // Data passed with the annotation travels as feature properties.
    expect(features[first.id]!['properties']['tag'], 'first');

    await pumpUntil(
      tester,
      controller.updateSymbol(
        first,
        const SymbolOptions(geometry: LatLng(3, 4)),
      ),
      'updateSymbol',
    );
    expect(controller.getSymbolLatLng(first), const LatLng(3, 4));
    features = await pumpUntilValue(
      tester,
      () => _featuresById(controller, sourceId),
      (byId) => _isNear(byId[first.id], 4, 3),
      'updated symbol moved in the source',
    );
    expect(features.keys.toSet(), {first.id, ...more.map((s) => s.id)});

    await pumpUntil(tester, controller.removeSymbol(more.first), 'remove');
    expect(controller.symbols, {first, more.last});
    await _waitForIds(tester, controller, sourceId, {
      first.id,
      more.last.id,
    }, 'symbol removed');

    await pumpUntil(tester, controller.clearSymbols(), 'clearSymbols');
    expect(controller.symbols, isEmpty);
    await _waitForIds(tester, controller, sourceId, {}, 'symbols cleared');

    // Clearing empties the source but keeps the layer for later symbols.
    final after = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    expect(after, contains(sourceId));
  });

  testWidgets('lines: add, update, remove and clear reach the source', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);
    // Index 0 holds lines without a pattern; index 1 is the pattern layer.
    final sourceId = controller.lineManager!.layerIds.first;

    final first = await pumpUntil(
      tester,
      controller.addLine(
        const LineOptions(
          geometry: [LatLng(0, -3), LatLng(0, 3)],
          lineWidth: 4,
          lineColor: '#ff0000',
        ),
      ),
      'addLine',
    );
    final more = await pumpUntil(
      tester,
      controller.addLines([
        const LineOptions(geometry: [LatLng(-2, -2), LatLng(2, 2)]),
        const LineOptions(geometry: [LatLng(2, -2), LatLng(-2, 2)]),
      ]),
      'addLines',
    );
    expect(controller.lines, {first, ...more});
    expect(controller.getLineLatLngs(first), const [
      LatLng(0, -3),
      LatLng(0, 3),
    ]);

    var features = await _waitForIds(tester, controller, sourceId, {
      first.id,
      ...more.map((l) => l.id),
    }, 'lines added');
    expect(features[first.id]!['properties']['lineWidth'], 4);

    await pumpUntil(
      tester,
      controller.updateLine(first, const LineOptions(lineWidth: 9)),
      'updateLine',
    );
    features = await pumpUntilValue(
      tester,
      () => _featuresById(controller, sourceId),
      (byId) => byId[first.id]?['properties']['lineWidth'] == 9,
      'updated line width in the source',
    );
    // An update touches only its own feature.
    expect(features.keys.toSet(), {first.id, ...more.map((l) => l.id)});

    await pumpUntil(tester, controller.removeLine(first), 'removeLine');
    expect(controller.lines, more.toSet());
    await _waitForIds(
      tester,
      controller,
      sourceId,
      more.map((l) => l.id).toSet(),
      'line removed',
    );

    await pumpUntil(tester, controller.clearLines(), 'clearLines');
    expect(controller.lines, isEmpty);
    await _waitForIds(tester, controller, sourceId, {}, 'lines cleared');
  });

  testWidgets('circles: add, update, remove, clear and render', (tester) async {
    final controller = await _pumpAnnotationMap(tester);
    final sourceId = controller.circleManager!.layerIds.single;

    final first = await pumpUntil(
      tester,
      controller.addCircle(
        const CircleOptions(
          geometry: LatLng(0, 0),
          circleRadius: 20,
          circleColor: '#0000ff',
        ),
      ),
      'addCircle',
    );
    final more = await pumpUntil(
      tester,
      controller.addCircles([
        const CircleOptions(geometry: LatLng(3, 3), circleRadius: 5),
        const CircleOptions(geometry: LatLng(-3, -3), circleRadius: 5),
      ]),
      'addCircles',
    );
    expect(controller.circles, {first, ...more});
    expect(controller.getCircleLatLng(first), const LatLng(0, 0));

    await _waitForIds(tester, controller, sourceId, {
      first.id,
      ...more.map((c) => c.id),
    }, 'circles added');

    // The circle is drawn by the manager's layer, so it is hit at its own
    // screen position (both values in the platform's own pixel units).
    await _waitForRendered(
      tester,
      controller,
      const LatLng(0, 0),
      sourceId,
      first.id,
      'circle rendered',
    );

    await pumpUntil(
      tester,
      controller.updateCircle(
        first,
        const CircleOptions(geometry: LatLng(1, 2), circleRadius: 12),
      ),
      'updateCircle',
    );
    expect(controller.getCircleLatLng(first), const LatLng(1, 2));
    await pumpUntilValue(
      tester,
      () => _featuresById(controller, sourceId),
      (byId) =>
          _isNear(byId[first.id], 2, 1) &&
          byId[first.id]!['properties']['circleRadius'] == 12,
      'updated circle in the source',
    );

    await pumpUntil(tester, controller.removeCircle(first), 'removeCircle');
    expect(controller.circles, more.toSet());
    await _waitForIds(
      tester,
      controller,
      sourceId,
      more.map((c) => c.id).toSet(),
      'circle removed',
    );

    await pumpUntil(tester, controller.clearCircles(), 'clearCircles');
    expect(controller.circles, isEmpty);
    await _waitForIds(tester, controller, sourceId, {}, 'circles cleared');
  });

  testWidgets('fills: add, update, remove, clear and render', (tester) async {
    final controller = await _pumpAnnotationMap(tester);
    // Index 0 holds fills without a pattern; index 1 is the pattern layer.
    final sourceId = controller.fillManager!.layerIds.first;

    // Rings are closed explicitly: the manager sends them as given.
    final first = await pumpUntil(
      tester,
      controller.addFill(
        const FillOptions(
          geometry: [
            [
              LatLng(-2, -2),
              LatLng(-2, 2),
              LatLng(2, 2),
              LatLng(2, -2),
              LatLng(-2, -2),
            ],
          ],
          fillColor: '#00ff00',
          fillOpacity: 0.5,
        ),
      ),
      'addFill',
    );
    final more = await pumpUntil(
      tester,
      controller.addFills([
        const FillOptions(
          geometry: [
            [LatLng(4, 4), LatLng(4, 5), LatLng(5, 5), LatLng(4, 4)],
          ],
        ),
      ]),
      'addFills',
    );
    expect(controller.fills, {first, ...more});
    expect(controller.getFillLatLngs(first).single, hasLength(5));

    var features = await _waitForIds(tester, controller, sourceId, {
      first.id,
      more.single.id,
    }, 'fills added');
    expect(features[first.id]!['properties']['fillOpacity'], 0.5);

    await _waitForRendered(
      tester,
      controller,
      const LatLng(0, 0),
      sourceId,
      first.id,
      'fill rendered',
    );

    await pumpUntil(
      tester,
      controller.updateFill(first, const FillOptions(fillOpacity: 0.8)),
      'updateFill',
    );
    features = await pumpUntilValue(
      tester,
      () => _featuresById(controller, sourceId),
      (byId) => byId[first.id]?['properties']['fillOpacity'] == 0.8,
      'updated fill in the source',
    );
    expect(features.keys.toSet(), {first.id, more.single.id});

    await pumpUntil(tester, controller.removeFill(first), 'removeFill');
    expect(controller.fills, more.toSet());
    await _waitForIds(tester, controller, sourceId, {
      more.single.id,
    }, 'fill removed');

    await pumpUntil(tester, controller.clearFills(), 'clearFills');
    expect(controller.fills, isEmpty);
    await _waitForIds(tester, controller, sourceId, {}, 'fills cleared');
  });

  testWidgets('addImage makes a PNG drawable as a symbol icon, sdf included', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);
    final layerId = controller.symbolManager!.layerIds.single;
    final png =
        (await rootBundle.load(
          'assets/symbols/custom-marker.png',
        )).buffer.asUint8List();

    await pumpUntil(tester, controller.addImage('marker', png), 'addImage');
    await pumpUntil(
      tester,
      controller.addImage('marker-sdf', png, true),
      'addImage sdf',
    );

    // Far enough apart that neither icon hides the other in collision.
    final plain = await pumpUntil(
      tester,
      controller.addSymbol(
        const SymbolOptions(geometry: LatLng(0, -4), iconImage: 'marker'),
      ),
      'plain icon symbol',
    );
    final sdf = await pumpUntil(
      tester,
      controller.addSymbol(
        const SymbolOptions(
          geometry: LatLng(0, 4),
          iconImage: 'marker-sdf',
          iconColor: '#ff00ff',
        ),
      ),
      'sdf icon symbol',
    );

    // A symbol whose icon image is missing is not drawn, so a hit proves the
    // image was registered with the style.
    await _waitForRendered(
      tester,
      controller,
      const LatLng(0, -4),
      layerId,
      plain.id,
      'plain icon rendered',
    );
    await _waitForRendered(
      tester,
      controller,
      const LatLng(0, 4),
      layerId,
      sdf.id,
      'sdf icon rendered',
    );
  });

  testWidgets('addImage rejects bytes that are not an image', (tester) async {
    final controller = await _pumpAnnotationMap(tester);

    // Nothing could be drawn from these, so the caller should hear about it
    // rather than get a silent success (or no answer at all).
    await expectPlatformError(
      tester,
      controller.addImage('broken', Uint8List.fromList([1, 2, 3, 4])),
      'addImage with garbage bytes',
    );
  });

  testWidgets('symbol overlap setters apply to the symbol layer', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);
    final layerId = controller.symbolManager!.layerIds.single;

    final symbol = await pumpUntil(
      tester,
      controller.addSymbol(const SymbolOptions(geometry: LatLng(1, 1))),
      'addSymbol',
    );

    await pumpUntil(
      tester,
      controller.setSymbolIconAllowOverlap(true),
      'iconAllowOverlap',
    );
    await pumpUntil(
      tester,
      controller.setSymbolIconIgnorePlacement(true),
      'iconIgnorePlacement',
    );
    await pumpUntil(
      tester,
      controller.setSymbolTextAllowOverlap(true),
      'textAllowOverlap',
    );
    await pumpUntil(
      tester,
      controller.setSymbolTextIgnorePlacement(true),
      'textIgnorePlacement',
    );

    // The setters rebuild the layer; it must come back, still on its source,
    // with the symbols that were already there.
    final layers = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    expect(layers, contains(layerId));
    await _waitForIds(tester, controller, layerId, {
      symbol.id,
    }, 'symbol kept across the rebuild');

    final properties = await pumpUntil(
      tester,
      controller.getLayerProperties(layerId),
      'getLayerProperties',
    );
    if (testPlatform == TestPlatform.ios) {
      // Documented: iOS only reads layers that came with the style, so a
      // runtime layer answers null there (#985).
      expect(properties, isNull);
      return;
    }
    expect(properties, isNotNull);
    expect(properties!['type'], 'symbol');
    expect(properties['source'], layerId);
    final layout = properties['layout'] as Map;
    expect(layout['icon-allow-overlap'], isTrue);
    expect(layout['icon-ignore-placement'], isTrue);
    expect(layout['text-allow-overlap'], isTrue);
    expect(layout['text-ignore-placement'], isTrue);
  });

  testWidgets('default annotationOrder stacks line, symbol, circle, fill', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);

    final layers = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    final managers = <AnnotationManager>[
      controller.lineManager!,
      controller.symbolManager!,
      controller.circleManager!,
      controller.fillManager!,
    ];
    _expectStacked(layers, managers);

    // Every type consumes taps by default.
    for (final manager in managers) {
      expect(manager.enableInteraction, isTrue);
    }
  });

  testWidgets('custom annotationOrder and annotationConsumeTapEvents', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(
      tester,
      order: const [AnnotationType.fill, AnnotationType.circle],
      consumeTapEvents: const [AnnotationType.circle],
    );

    // Only the listed types get a manager, in the listed order.
    expect(controller.lineManager, isNull);
    expect(controller.symbolManager, isNull);
    final layers = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    _expectStacked(layers, [
      controller.fillManager!,
      controller.circleManager!,
    ]);
    expect(controller.circleManager!.enableInteraction, isTrue);
    expect(controller.fillManager!.enableInteraction, isFalse);

    // A type left out of the order cannot be used.
    await expectFails(
      tester,
      controller.addLine(
        const LineOptions(geometry: [LatLng(0, 0), LatLng(1, 1)]),
      ),
      'addLine without a line manager',
      isA<Exception>(),
    );

    // The managers that exist still work.
    final circle = await pumpUntil(
      tester,
      controller.addCircle(const CircleOptions(geometry: LatLng(0, 0))),
      'addCircle',
    );
    await _waitForIds(
      tester,
      controller,
      controller.circleManager!.layerIds.single,
      {circle.id},
      'circle added',
    );
  });

  testWidgets('symbol overlap setters keep the annotationOrder stacking', (
    tester,
  ) async {
    final controller = await _pumpAnnotationMap(tester);

    // Rebuilding the symbol layer must not lift it above the managers that
    // annotationOrder put on top of it.
    await pumpUntil(
      tester,
      controller.setSymbolIconAllowOverlap(true),
      'iconAllowOverlap',
    );

    final layers = await pumpUntil(tester, controller.getLayerIds(), 'layers');
    _expectStacked(layers, [
      controller.lineManager!,
      controller.symbolManager!,
      controller.circleManager!,
      controller.fillManager!,
    ]);
  });
}

/// Pumps a map from [_annotationStyle] with the given annotation options
/// (the widget defaults when omitted).
Future<MapLibreMapController> _pumpAnnotationMap(
  WidgetTester tester, {
  List<AnnotationType> order = _defaultOrder,
  List<AnnotationType>? consumeTapEvents,
}) {
  return pumpMap(
    tester,
    builder:
        (onMapCreated, onStyleLoaded) => MapLibreMap(
          styleString: _annotationStyle,
          initialCameraPosition: _initialCamera,
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onStyleLoaded,
          annotationOrder: order,
          annotationConsumeTapEvents: consumeTapEvents ?? _defaultOrder,
        ),
  );
}

/// Features of [sourceId] keyed by annotation id.
///
/// The manager promotes the `id` property, so it is the stable key on every
/// platform. A feature that spans tiles can come back once per tile, which
/// keying by id folds together.
Future<Map<String, Map>> _featuresById(
  MapLibreMapController controller,
  String sourceId,
) async {
  final features = await controller.querySourceFeatures(sourceId, null, null);
  return {
    for (final feature in features.cast<Map>())
      (feature['properties'] as Map)['id'].toString(): feature,
  };
}

/// Waits until the ids in [sourceId] are exactly [expected], which only
/// happens once the data the manager pushed has reached the native source.
Future<Map<String, Map>> _waitForIds(
  WidgetTester tester,
  MapLibreMapController controller,
  String sourceId,
  Set<String> expected,
  String label,
) {
  return pumpUntilValue(
    tester,
    () => _featuresById(controller, sourceId),
    (byId) => setEquals(byId.keys.toSet(), expected),
    label,
  );
}

/// Whether [feature] is a point at ([lng], [lat]), with room for the tile
/// quantization querySourceFeatures applies on native.
bool _isNear(Map? feature, double lng, double lat) {
  if (feature == null) return false;
  final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
  return ((coordinates[0] as num) - lng).abs() < 0.01 &&
      ((coordinates[1] as num) - lat).abs() < 0.01;
}

/// Waits until the feature [annotationId] is rendered by [layerId] at the
/// screen position of [at], failing the test on timeout.
Future<void> _waitForRendered(
  WidgetTester tester,
  MapLibreMapController controller,
  LatLng at,
  String layerId,
  String annotationId,
  String label,
) async {
  final screen = await pumpUntil(
    tester,
    controller.toScreenLocation(at),
    '$label: toScreenLocation',
  );
  final point = Point<double>(screen.x.toDouble(), screen.y.toDouble());
  await pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [layerId], null),
    (features) => features.cast<Map>().any(
      (f) => (f['properties'] as Map?)?['id'].toString() == annotationId,
    ),
    label,
  );
}

/// Expects every layer of each manager in [layers], above the background,
/// with the managers stacked bottom to top in the order given.
void _expectStacked(List layers, List<AnnotationManager> managers) {
  var below = layers.indexOf(backgroundLayerId);
  expect(below, isNot(-1));
  for (final manager in managers) {
    for (final layerId in manager.layerIds) {
      final index = layers.indexOf(layerId);
      expect(index, greaterThan(below), reason: '$layerId in $layers');
      below = index;
    }
  }
}
