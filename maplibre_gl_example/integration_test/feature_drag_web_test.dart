// Integration test for dragging a feature on web.
//
// The drag lives in maplibre_gl_web, between the mouse events maplibre-gl-js
// reports and the feature#onDrag payloads; the unit tests cover the tracker
// on its own, this covers it wired to a real map. Flutter's synthesized
// pointers do not reach the map's DOM element, so the test dispatches mouse
// events on the map canvas, as a mouse would.
//
// It imports package:web, which does not compile for Android or iOS, so it
// is not part of all_tests.dart. Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/feature_drag_web_test.dart \
//     -d web-server --browser-name=chrome
//
// The assertions only run on web; elsewhere the tests are no-ops.
import 'dart:math' show Point;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web/web.dart' as web;

import 'support/map_harness.dart';

const _center = LatLng(0, 0);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a click on a draggable feature taps it, no drag', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final mouse = _Mouse(map.canvas);
    mouse.down(map.circleOnCanvas);
    mouse.up(map.circleOnCanvas);
    mouse.click(map.circleOnCanvas);
    await _settle(tester);

    expect(map.drags, isEmpty);
    expect(map.featureTaps, hasLength(1));
  });

  testWidgets('a press that moves less than 3 px is still a click', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final mouse = _Mouse(map.canvas);
    final nudged = map.circleOnCanvas + const Point<double>(2, 0);
    mouse.down(map.circleOnCanvas);
    mouse.move(nudged);
    mouse.up(nudged);
    mouse.click(nudged);
    await _settle(tester);

    expect(map.drags, isEmpty);
    expect(map.featureTaps, hasLength(1));
  });

  testWidgets('a drag moves the feature, not the map, and is no tap', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final map = await _pumpMapWithDraggableCircle(tester);
    final before = await pumpUntil(
      tester,
      map.controller.getVisibleRegion(),
      'getVisibleRegion before',
    );

    final mouse = _Mouse(map.canvas);
    var at = map.circleOnCanvas;
    mouse.down(at);
    for (var i = 0; i < 10; i++) {
      at += const Point<double>(2, 0);
      mouse.move(at);
      await tester.pump(const Duration(milliseconds: 16));
    }
    mouse.up(at);
    // A browser still sends a click after a press that moved.
    mouse.click(at);
    await _settle(tester);

    expect(
      await pumpUntil(
        tester,
        map.controller.getVisibleRegion(),
        'getVisibleRegion after',
      ),
      before,
    );
    final types = map.drags.map((d) => d.type).toList();
    expect(types.first, DragEventType.start);
    expect(types, contains(DragEventType.drag));
    expect(types.last, DragEventType.end);
    expect(types.where((t) => t == DragEventType.start), hasLength(1));
    // The release on the map ends the drag; the window does not end it again.
    expect(types.where((t) => t == DragEventType.end), hasLength(1));
    expect(map.featureTaps, isEmpty);
    expect(map.clicks, isEmpty);

    // As on Android and iOS: the drag starts where the pointer crossed the
    // threshold, with no movement of its own.
    final start = map.drags.first;
    expect(start.delta, const LatLng(0, 0));
    expect(start.origin, start.current);
    final end = map.drags.last;
    expect(end.origin, start.origin);
    expect(end.current.longitude, greaterThan(start.current.longitude));
  });

  testWidgets('a click after a drag taps the feature again', (tester) async {
    if (!kIsWeb) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final mouse = _Mouse(map.canvas);
    var at = map.circleOnCanvas;
    mouse.down(at);
    for (var i = 0; i < 5; i++) {
      at += const Point<double>(2, 0);
      mouse.move(at);
      await tester.pump(const Duration(milliseconds: 16));
    }
    mouse.up(at);
    await _settle(tester);
    expect(map.drags.last.type, DragEventType.end);
    map.drags.clear();

    // The drag moved the circle 10 px right; its 30 px radius still covers
    // the old center.
    mouse.down(map.circleOnCanvas);
    mouse.up(map.circleOnCanvas);
    mouse.click(map.circleOnCanvas);
    await _settle(tester);

    expect(map.drags, isEmpty);
    expect(map.featureTaps, hasLength(1));
  });

  testWidgets('a release outside the map ends the drag', (tester) async {
    if (!kIsWeb) return;
    final map = await _pumpMapWithDraggableCircle(tester);

    final mouse = _Mouse(map.canvas);
    var at = map.circleOnCanvas;
    mouse.down(at);
    for (var i = 0; i < 5; i++) {
      at += const Point<double>(2, 0);
      mouse.move(at);
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Released off the map: only the window sees the mouseup.
    mouse.upOnWindow();
    await _settle(tester);

    final types = map.drags.map((d) => d.type).toList();
    expect(types.first, DragEventType.start);
    expect(types.last, DragEventType.end);
    expect(types.where((t) => t == DragEventType.end), hasLength(1));
    expect(map.drags.last.delta, const LatLng(0, 0));
    map.drags.clear();

    // Back over the map with the button up: the feature stays put.
    for (var i = 0; i < 5; i++) {
      at += const Point<double>(2, 0);
      mouse.hover(at);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await _settle(tester);
    expect(map.drags, isEmpty);

    // And the next press on it is a click again.
    mouse.down(map.circleOnCanvas);
    mouse.up(map.circleOnCanvas);
    mouse.click(map.circleOnCanvas);
    await _settle(tester);
    expect(map.drags, isEmpty);
    expect(map.featureTaps, hasLength(1));
  });

  testWidgets('taps, drags and hovers report the feature id as text', (
    tester,
  ) async {
    if (!kIsWeb) return;
    final taps = <String>[];
    final drags = <String>{};
    final hovers = <String>{};
    final controller = await pumpMap(tester);
    controller.onFeatureTapped.add(
      (point, latLng, id, layerId, annotation) => taps.add(id),
    );
    controller.onFeatureDrag.add(
      (point, origin, current, delta, id, annotation, type) => drags.add(id),
    );
    controller.onFeatureHover.add(
      (point, latLng, id, annotation, type) => hovers.add(id),
    );
    // The ids a GeoJSON feature can have, by where the feature is.
    final features = <LatLng, Object>{
      const LatLng(5, -8): 2,
      const LatLng(5, 8): '2',
      const LatLng(-6, -8): 2.5,
      const LatLng(-6, 8): 'poi-12',
    };
    await pumpUntil(
      tester,
      controller.addGeoJsonSource('ids', {
        'type': 'FeatureCollection',
        'features': [
          for (final MapEntry(:key, :value) in features.entries)
            {
              'type': 'Feature',
              'id': value,
              'geometry': {
                'type': 'Point',
                'coordinates': [key.longitude, key.latitude],
              },
              'properties': {'draggable': true},
            },
        ],
      }),
      'addGeoJsonSource',
    );
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        'ids',
        'ids-circle',
        const CircleLayerProperties(circleRadius: 15),
      ),
      'addCircleLayer',
    );
    final canvas =
        web.document.querySelector('canvas.maplibregl-canvas')!
            as web.HTMLCanvasElement;
    final mouse = _Mouse(canvas);

    for (final MapEntry(:key, :value) in features.entries) {
      final screen = await pumpUntil(
        tester,
        controller.toScreenLocation(key),
        'toScreenLocation',
      );
      var at = Point<double>(screen.x.toDouble(), screen.y.toDouble());
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeatures(at, ['ids-circle'], null),
        (features) => features.isNotEmpty,
        'feature $value drawn',
      );

      mouse.hover(at);
      mouse.down(at);
      mouse.up(at);
      mouse.click(at);
      await _settle(tester);
      expect(taps, [value.toString()], reason: 'tap on $value');
      expect(hovers, {value.toString()}, reason: 'hover over $value');

      mouse.down(at);
      for (var i = 0; i < 5; i++) {
        at += const Point<double>(2, 0);
        mouse.move(at);
        await tester.pump(const Duration(milliseconds: 16));
      }
      mouse.up(at);
      await _settle(tester);
      expect(drags, {value.toString()}, reason: 'drag of $value');

      // Off every feature, so the next one starts from nothing hovered.
      mouse.hover(const Point<double>(5, 5));
      await _settle(tester);
      taps.clear();
      drags.clear();
      hovers.clear();
    }
  });
}

/// Lets the drag and tap callbacks reach Dart.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 300));

/// Dispatches the mouse events a left button press sends, on [canvas], at
/// positions relative to its top left corner in CSS pixels.
class _Mouse {
  _Mouse(this.canvas);

  final web.HTMLCanvasElement canvas;

  void down(Point<double> at) => _send('mousedown', at, buttons: 1);

  void move(Point<double> at) => _send('mousemove', at, buttons: 1);

  void up(Point<double> at) => _send('mouseup', at, buttons: 0);

  void click(Point<double> at) => _send('click', at, buttons: 0);

  void hover(Point<double> at) => _send('mousemove', at, buttons: 0);

  /// A release outside the map, which only the window sees.
  void upOnWindow() => web.window.dispatchEvent(
    web.MouseEvent(
      'mouseup',
      web.MouseEventInit(bubbles: true, cancelable: true, button: 0),
    ),
  );

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

class _Drag {
  _Drag(this.type, this.origin, this.current, this.delta);

  final DragEventType type;
  final LatLng origin;
  final LatLng current;
  final LatLng delta;
}

class _MapProbe {
  final drags = <_Drag>[];
  final featureTaps = <String>[];
  final clicks = <LatLng>[];
  late MapLibreMapController controller;
  late web.HTMLCanvasElement canvas;
  late Point<double> circleOnCanvas;
}

Future<_MapProbe> _pumpMapWithDraggableCircle(WidgetTester tester) async {
  final probe = _MapProbe();

  final controller =
      probe.controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: _center,
                zoom: 10,
              ),
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
              onMapClick: (_, latLng) => probe.clicks.add(latLng),
            ),
      );
  controller.onFeatureDrag.add(
    (point, origin, current, delta, id, annotation, eventType) =>
        probe.drags.add(_Drag(eventType, origin, current, delta)),
  );
  controller.onFeatureTapped.add(
    (point, latLng, id, layerId, annotation) => probe.featureTaps.add(id),
  );
  final circle = await pumpUntil(
    tester,
    controller.addCircle(
      const CircleOptions(
        geometry: _center,
        circleRadius: 30,
        circleColor: '#e53935',
        draggable: true,
      ),
    ),
    'addCircle',
  );

  // The feature query behind a press only sees what is drawn.
  final screen = await pumpUntil(
    tester,
    controller.toScreenLocation(_center),
    'toScreenLocation',
  );
  final point = Point<double>(screen.x.toDouble(), screen.y.toDouble());
  final layerId = controller.circleManager!.layerIds.first;
  await pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [layerId], null),
    (features) => features.cast<Map>().any(
      (f) => (f['properties'] as Map?)?['id'].toString() == circle.id,
    ),
    'circle rendered',
  );

  final canvas = web.document.querySelector('canvas.maplibregl-canvas');
  expect(canvas, isNotNull, reason: 'the map canvas');
  probe.canvas = canvas! as web.HTMLCanvasElement;
  probe.circleOnCanvas = point;
  return probe;
}
