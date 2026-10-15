// Integration tests on web that drive or read the map's DOM: hover listeners
// of a layer removed and added again, and the attribution control kept where
// the app put it across option updates.
//
// Flutter's synthesized pointers do not reach the map's DOM element, so the
// tests dispatch mouse events on the map canvas, as a mouse would.
//
// It imports package:web, which does not compile for Android or iOS, so it
// is not part of all_tests.dart. Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/web_map_dom_test.dart \
//     -d web-server --browser-name=chrome
//
// The assertions only run on web; elsewhere the tests are no-ops.
import 'dart:math' show Point;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web/web.dart' as web;

import 'support/map_harness.dart';

const _center = LatLng(0, 0);
const _sourceId = 'hover-source';
const _layerId = 'hover-layer';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a layer removed and added again reports each hover once', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final controller = await pumpMap(
      tester,
      initialCameraPosition: const CameraPosition(target: _center, zoom: 10),
    );
    final hovers = <HoverEventType>[];
    final taps = <String>[];
    controller.onFeatureHover.add(
      (point, latLng, id, annotation, eventType) => hovers.add(eventType),
    );
    controller.onFeatureTapped.add(
      (point, latLng, id, layerId, annotation) => taps.add(id),
    );

    await pumpUntil(
      tester,
      controller.addGeoJsonSource(_sourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 1,
            'geometry': {
              'type': 'Point',
              'coordinates': [_center.longitude, _center.latitude],
            },
            'properties': <String, dynamic>{},
          },
        ],
      }),
      'addGeoJsonSource',
    );
    final onCanvas = await _addCircleLayer(tester, controller);
    final mouse = _Mouse(_canvas());

    // One pass over the circle on the layer as first added.
    mouse.hover(onCanvas);
    mouse.hover(const Point<double>(5, 5));
    await _settle(tester);
    final firstPass = List.of(hovers);
    expect(firstPass, contains(HoverEventType.enter));
    expect(firstPass.last, HoverEventType.leave);
    hovers.clear();

    // What the annotation managers do when they rebuild a layer.
    for (var i = 0; i < 2; i++) {
      await pumpUntil(
        tester,
        controller.removeLayer(_layerId),
        'removeLayer $i',
      );
      await _addCircleLayer(tester, controller);
    }

    mouse.hover(onCanvas);
    mouse.hover(const Point<double>(5, 5));
    await _settle(tester);
    // Stacked listeners would run the hover handler once per add.
    expect(hovers, firstPass);
    expect(hovers.where((t) => t == HoverEventType.enter), hasLength(1));

    mouse.down(onCanvas);
    mouse.up(onCanvas);
    mouse.click(onCanvas);
    await _settle(tester);
    expect(taps, hasLength(1));
  });

  testWidgets('the attribution stays put when another option changes', (
    tester,
  ) async {
    if (!kIsWeb) return;
    late MapCreatedCallback created;
    late OnStyleLoadedCallback styleLoaded;
    MapLibreMap buildMap({required bool compassEnabled}) => MapLibreMap(
      styleString: offlineStyle,
      initialCameraPosition: const CameraPosition(target: _center, zoom: 3),
      attributionButtonPosition: AttributionButtonPosition.topLeft,
      compassEnabled: compassEnabled,
      onMapCreated: created,
      onStyleLoadedCallback: styleLoaded,
    );

    await pumpMap(
      tester,
      builder: (onMapCreated, onStyleLoaded) {
        created = onMapCreated;
        styleLoaded = onStyleLoaded;
        return buildMap(compassEnabled: true);
      },
    );
    expect(_attributionIn('top-left'), isTrue, reason: 'at creation');

    // The same tree as the harness pumps, so the map widget is updated in
    // place and only the changed option reaches the platform.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 300,
              child: buildMap(compassEnabled: false),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(_attributionIn('top-left'), isTrue, reason: 'after the update');
    expect(_attributionIn('bottom-right'), isFalse, reason: 'after the update');
  });
}

/// Adds the interactive circle layer over [_sourceId] and returns where the
/// circle is drawn on the canvas once it is.
Future<Point<double>> _addCircleLayer(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(circleRadius: 30, circleColor: '#e53935'),
      enableInteraction: true,
    ),
    'addCircleLayer',
  );
  final screen = await pumpUntil(
    tester,
    controller.toScreenLocation(_center),
    'toScreenLocation',
  );
  final point = Point<double>(screen.x.toDouble(), screen.y.toDouble());
  // Hover and tap only see what is drawn.
  await pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [_layerId], null),
    (features) => features.isNotEmpty,
    'circle rendered',
  );
  return point;
}

web.HTMLCanvasElement _canvas() {
  final canvas = web.document.querySelector('canvas.maplibregl-canvas');
  expect(canvas, isNotNull, reason: 'the map canvas');
  return canvas! as web.HTMLCanvasElement;
}

/// Whether the attribution control sits in the [corner] container, such as
/// `top-left`.
bool _attributionIn(String corner) =>
    web.document.querySelector(
      '.maplibregl-ctrl-$corner .maplibregl-ctrl-attrib',
    ) !=
    null;

/// Lets the hover and tap callbacks and option updates reach their target.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 300));

/// Dispatches mouse events on [canvas], at positions relative to its top left
/// corner in CSS pixels.
class _Mouse {
  _Mouse(this.canvas);

  final web.HTMLCanvasElement canvas;

  void down(Point<double> at) => _send('mousedown', at, buttons: 1);

  void up(Point<double> at) => _send('mouseup', at, buttons: 0);

  void click(Point<double> at) => _send('click', at, buttons: 0);

  void hover(Point<double> at) => _send('mousemove', at, buttons: 0);

  void _send(String type, Point<double> at, {required int buttons}) {
    final rect = canvas.getBoundingClientRect();
    canvas.dispatchEvent(
      web.MouseEvent(
        type,
        web.MouseEventInit(
          bubbles: true,
          cancelable: true,
          clientX: (rect.left + at.x).round(),
          clientY: (rect.top + at.y).round(),
          button: 0,
          buttons: buttons,
        ),
      ),
    );
  }
}
