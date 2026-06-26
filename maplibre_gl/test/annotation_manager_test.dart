import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

/// Creates a [MapLibreMapController] backed by the given [FakeMapLibrePlatform]
/// with all annotation types enabled for interaction, and manually initializes
/// all annotation managers (bypassing the async style-loaded callback).
Future<MapLibreMapController> _createController(
  FakeMapLibrePlatform platform,
) async {
  final controller = MapLibreMapController(
    maplibrePlatform: platform,
    initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
    annotationOrder: AnnotationType.values,
    annotationConsumeTapEvents: AnnotationType.values,
  );

  // Manually initialize managers (the style-loaded callback is async and
  // cannot be awaited through ArgumentCallbacks.call).
  controller.fillManager = FillManager(controller);
  await controller.fillManager!.initialize();
  controller.lineManager = LineManager(controller);
  await controller.lineManager!.initialize();
  controller.circleManager = CircleManager(controller);
  await controller.circleManager!.initialize();
  controller.symbolManager = SymbolManager(controller);
  await controller.symbolManager!.initialize();

  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;
  late MapLibreMapController controller;

  setUp(() async {
    platform = FakeMapLibrePlatform();
    controller = await _createController(platform);
    platform.reset();
  });

  group('CircleManager', () {
    test('add creates a circle and calls setGeoJsonSource', () async {
      final circle = await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );

      expect(circle, isA<Circle>());
      expect(circle.options.geometry, const LatLng(10, 20));
      expect(controller.circles, contains(circle));
    });

    test('addCircles creates multiple circles', () async {
      final circles = await controller.addCircles([
        const CircleOptions(geometry: LatLng(1, 2)),
        const CircleOptions(geometry: LatLng(3, 4)),
      ]);

      expect(circles.length, 2);
      expect(controller.circles.length, 2);
    });

    test('removeCircle removes from the set', () async {
      final circle = await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );
      await controller.removeCircle(circle);

      expect(controller.circles, isEmpty);
    });

    test('removeCircles removes multiple', () async {
      final circles = await controller.addCircles([
        const CircleOptions(geometry: LatLng(1, 2)),
        const CircleOptions(geometry: LatLng(3, 4)),
      ]);
      await controller.removeCircles(circles);

      expect(controller.circles, isEmpty);
    });

    test('clearCircles removes all circles', () async {
      await controller.addCircles([
        const CircleOptions(geometry: LatLng(1, 2)),
        const CircleOptions(geometry: LatLng(3, 4)),
      ]);
      await controller.clearCircles();

      expect(controller.circles, isEmpty);
    });

    test('updateCircle updates circle options', () async {
      final circle = await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );
      await controller.updateCircle(
        circle,
        const CircleOptions(circleRadius: 15.0),
      );

      final updated = controller.circles.first;
      expect(updated.options.circleRadius, 15.0);
    });
  });

  group('LineManager', () {
    test('add creates a line', () async {
      final line = await controller.addLine(
        const LineOptions(
          geometry: [LatLng(0, 0), LatLng(1, 1)],
        ),
      );

      expect(line, isA<Line>());
      expect(controller.lines, contains(line));
    });

    test('addLines creates multiple lines', () async {
      final lines = await controller.addLines([
        const LineOptions(geometry: [LatLng(0, 0), LatLng(1, 1)]),
        const LineOptions(geometry: [LatLng(2, 2), LatLng(3, 3)]),
      ]);

      expect(lines.length, 2);
      expect(controller.lines.length, 2);
    });

    test('removeLine removes from the set', () async {
      final line = await controller.addLine(
        const LineOptions(geometry: [LatLng(0, 0), LatLng(1, 1)]),
      );
      await controller.removeLine(line);

      expect(controller.lines, isEmpty);
    });

    test('clearLines removes all lines', () async {
      await controller.addLines([
        const LineOptions(geometry: [LatLng(0, 0), LatLng(1, 1)]),
        const LineOptions(geometry: [LatLng(2, 2), LatLng(3, 3)]),
      ]);
      await controller.clearLines();

      expect(controller.lines, isEmpty);
    });

    test('line with pattern goes to second layer bucket', () async {
      platform.reset();
      await controller.addLine(
        const LineOptions(
          geometry: [LatLng(0, 0), LatLng(1, 1)],
          linePattern: 'pattern-image',
        ),
      );

      // The selectLayer function should route pattern lines to layer index 1
      expect(platform.wasCalled('setGeoJsonSource'), isTrue);
    });
  });

  group('FillManager', () {
    test('add creates a fill', () async {
      final fill = await controller.addFill(
        const FillOptions(
          geometry: [
            [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 0)],
          ],
        ),
      );

      expect(fill, isA<Fill>());
      expect(controller.fills, contains(fill));
    });

    test('addFills creates multiple fills', () async {
      final fills = await controller.addFills([
        const FillOptions(
          geometry: [
            [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 0)],
          ],
        ),
        const FillOptions(
          geometry: [
            [LatLng(2, 2), LatLng(3, 2), LatLng(3, 3), LatLng(2, 2)],
          ],
        ),
      ]);

      expect(fills.length, 2);
      expect(controller.fills.length, 2);
    });

    test('removeFill removes from the set', () async {
      final fill = await controller.addFill(
        const FillOptions(
          geometry: [
            [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 0)],
          ],
        ),
      );
      await controller.removeFill(fill);

      expect(controller.fills, isEmpty);
    });

    test('clearFills removes all fills', () async {
      await controller.addFills([
        const FillOptions(
          geometry: [
            [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 0)],
          ],
        ),
        const FillOptions(
          geometry: [
            [LatLng(2, 2), LatLng(3, 2), LatLng(3, 3), LatLng(2, 2)],
          ],
        ),
      ]);
      await controller.clearFills();

      expect(controller.fills, isEmpty);
    });

    test('fill with pattern goes to second layer bucket', () async {
      platform.reset();
      await controller.addFill(
        const FillOptions(
          geometry: [
            [LatLng(0, 0), LatLng(1, 0), LatLng(1, 1), LatLng(0, 0)],
          ],
          fillPattern: 'pattern-image',
        ),
      );

      expect(platform.wasCalled('setGeoJsonSource'), isTrue);
    });
  });

  group('SymbolManager', () {
    test('add creates a symbol', () async {
      final symbol = await controller.addSymbol(
        const SymbolOptions(geometry: LatLng(10, 20)),
      );

      expect(symbol, isA<Symbol>());
      expect(controller.symbols, contains(symbol));
    });

    test('addSymbols creates multiple symbols', () async {
      final symbols = await controller.addSymbols([
        const SymbolOptions(geometry: LatLng(1, 2)),
        const SymbolOptions(geometry: LatLng(3, 4)),
      ]);

      expect(symbols.length, 2);
      expect(controller.symbols.length, 2);
    });

    test('removeSymbol removes from the set', () async {
      final symbol = await controller.addSymbol(
        const SymbolOptions(geometry: LatLng(10, 20)),
      );
      await controller.removeSymbol(symbol);

      expect(controller.symbols, isEmpty);
    });

    test('clearSymbols removes all symbols', () async {
      await controller.addSymbols([
        const SymbolOptions(geometry: LatLng(1, 2)),
        const SymbolOptions(geometry: LatLng(3, 4)),
      ]);
      await controller.clearSymbols();

      expect(controller.symbols, isEmpty);
    });
  });

  group('AnnotationManager initialization', () {
    test('managers are initialized', () {
      expect(controller.circleManager, isNotNull);
      expect(controller.circleManager!.isInitialized, isTrue);
      expect(controller.lineManager, isNotNull);
      expect(controller.lineManager!.isInitialized, isTrue);
      expect(controller.fillManager, isNotNull);
      expect(controller.fillManager!.isInitialized, isTrue);
      expect(controller.symbolManager, isNotNull);
      expect(controller.symbolManager!.isInitialized, isTrue);
    });

    test('layer counts per manager type', () {
      expect(controller.circleManager!.layerIds.length, 1);
      expect(controller.lineManager!.layerIds.length, 2);
      expect(controller.fillManager!.layerIds.length, 2);
      expect(controller.symbolManager!.layerIds.length, 1);
    });

    test('adding annotation before init throws', () {
      final freshPlatform = FakeMapLibrePlatform();
      final freshController = MapLibreMapController(
        maplibrePlatform: freshPlatform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(
        () => freshController.addCircle(
          const CircleOptions(geometry: LatLng(0, 0)),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('AnnotationManager drag callback lifecycle', () {
    test('initialize registers one drag callback per manager', () {
      // setUp() initializes 4 managers (fill, line, circle, symbol).
      expect(controller.onFeatureDrag.length, 4);
    });

    test('repeated initialize is idempotent', () async {
      final before = controller.onFeatureDrag.length;
      await controller.symbolManager!.initialize();
      await controller.symbolManager!.initialize();
      expect(controller.onFeatureDrag.length, before);
    });

    test('dispose removes the manager drag callback', () async {
      final before = controller.onFeatureDrag.length;
      await controller.symbolManager!.dispose();
      expect(controller.onFeatureDrag.length, before - 1);

      await controller.lineManager!.dispose();
      expect(controller.onFeatureDrag.length, before - 2);
    });

    test('dispose preserves other managers and user-added callbacks', () async {
      void userCallback(_, _, _, _, _, _, _) {}
      controller.onFeatureDrag.add(userCallback);

      await controller.symbolManager!.dispose();

      // Symbol manager removed, but the other 3 + user callback remain.
      expect(controller.onFeatureDrag.length, 4);
      expect(controller.onFeatureDrag, contains(userCallback));
    });

    test('style-reload cycle does not leak stale drag callbacks', () async {
      // Reproduces the scenario from PR #806: on every style reload the
      // controller disposes existing managers and creates new ones. Without
      // the fix, each reload would leave the previous _onDrag registered,
      // accumulating duplicates.
      final initial = controller.onFeatureDrag.length;

      for (var i = 0; i < 3; i++) {
        platform.onMapStyleLoadedPlatform.call(null);
        // The handler is async fire-and-forget through ArgumentCallbacks;
        // drain the microtask queue until dispose+initialize complete.
        await pumpEventQueue();
      }

      expect(controller.onFeatureDrag.length, initial);
    });

    test(
      'drag event after style reload does not target a disposed manager',
      () async {
        final oldSymbol = await controller.addSymbol(
          const SymbolOptions(geometry: LatLng(0, 0), draggable: true),
        );

        // Trigger the real style-reload code path on the controller.
        platform.onMapStyleLoadedPlatform.call(null);
        await pumpEventQueue();

        final newSymbol = await controller.addSymbol(
          const SymbolOptions(geometry: LatLng(10, 20), draggable: true),
        );

        final dragged = <String>[];
        controller.onFeatureDrag.add(
          (point, origin, current, delta, id, annotation, eventType) {
            dragged.add(id);
          },
        );

        platform.onFeatureDraggedPlatform.call({
          'id': newSymbol.id,
          'eventType': DragEventType.drag.name,
          'point': const Point(0.0, 0.0),
          'origin': const LatLng(10, 20),
          'current': const LatLng(10.001, 20.001),
          'delta': const LatLng(0.001, 0.001),
        });

        // Only the new manager (and our observer) should have been notified.
        // With the bug, the old manager's stale _onDrag would also fire.
        expect(dragged, [newSymbol.id]);
        expect(controller.symbolManager!.byId(newSymbol.id), isNotNull);
        // Old symbol's id is unrelated to anything live now.
        expect(controller.symbolManager!.byId(oldSymbol.id), isNull);
      },
    );
  });

  group('AnnotationManager GeoJSON output', () {
    test('setGeoJsonSource is called with FeatureCollection on add', () async {
      platform.reset();
      await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );

      final calls = platform.callsFor('setGeoJsonSource');
      expect(calls, isNotEmpty);

      final geojson = calls.last.positionalArgs[1] as Map<String, dynamic>;
      expect(geojson['type'], 'FeatureCollection');
      expect((geojson['features'] as List).length, 1);
    });

    test('features contain correct id and geometry', () async {
      platform.reset();
      await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );

      final calls = platform.callsFor('setGeoJsonSource');
      final features =
          (calls.last.positionalArgs[1] as Map)['features'] as List;
      final feature = features.first as Map<String, dynamic>;

      expect(feature['type'], 'Feature');
      expect(feature['id'], isNotNull);
      expect(feature['geometry']['type'], 'Point');
      // GeoJSON coordinates are [lng, lat]
      expect(feature['geometry']['coordinates'], [20.0, 10.0]);
    });

    test('clear produces empty FeatureCollection', () async {
      await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );
      platform.reset();
      await controller.clearCircles();

      final calls = platform.callsFor('setGeoJsonSource');
      final geojson = calls.last.positionalArgs[1] as Map<String, dynamic>;
      expect(geojson['features'] as List, isEmpty);
    });
  });

  group('Annotation tap callbacks', () {
    test('onCircleTapped fires when feature tapped', () async {
      final circle = await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );

      Circle? tappedCircle;
      controller.onCircleTapped.add((c) => tappedCircle = c);

      platform.onFeatureTappedPlatform.call({
        'id': circle.id,
        'layerId': controller.circleManager!.layerIds.first,
        'point': const Point(100.0, 200.0),
        'latLng': const LatLng(10, 20),
      });

      expect(tappedCircle, circle);
    });

    test('onLineTapped fires when line feature tapped', () async {
      final line = await controller.addLine(
        const LineOptions(geometry: [LatLng(0, 0), LatLng(1, 1)]),
      );

      Line? tappedLine;
      controller.onLineTapped.add((l) => tappedLine = l);

      platform.onFeatureTappedPlatform.call({
        'id': line.id,
        'layerId': controller.lineManager!.layerIds.first,
        'point': const Point(100.0, 200.0),
        'latLng': const LatLng(0.5, 0.5),
      });

      expect(tappedLine, line);
    });

    test('onFeatureTapped fires for any tapped feature', () async {
      final circle = await controller.addCircle(
        const CircleOptions(geometry: LatLng(10, 20)),
      );

      String? tappedId;
      controller.onFeatureTapped.add((point, coords, id, layerId, ann) {
        tappedId = id;
      });

      platform.onFeatureTappedPlatform.call({
        'id': circle.id,
        'layerId': controller.circleManager!.layerIds.first,
        'point': const Point(100.0, 200.0),
        'latLng': const LatLng(10, 20),
      });

      expect(tappedId, circle.id);
    });
  });
}
