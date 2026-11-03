import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;

  setUp(() {
    platform = FakeMapLibrePlatform();
    final previousFactory = MapLibrePlatform.createInstance;
    addTearDown(() {
      MapLibrePlatform.createInstance = previousFactory;
    });
    MapLibrePlatform.createInstance = () => platform;
  });

  group('initialCameraPosition', () {
    testWidgets('is included in creationParams when set', (tester) async {
      const camera = CameraPosition(
        target: LatLng(37.7749, -122.4194),
        zoom: 12,
        bearing: 45,
        tilt: 30,
      );

      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap(initialCameraPosition: camera)),
      );

      final params = platform.lastCreationParams;
      expect(params, isNotNull);
      expect(params!.containsKey('initialCameraPosition'), isTrue);

      final cameraMap = params['initialCameraPosition'] as Map<String, dynamic>;
      expect(cameraMap['bearing'], 45.0);
      expect(cameraMap['zoom'], 12.0);
      expect(cameraMap['tilt'], 30.0);
      final target = cameraMap['target'] as List;
      expect(target[0], 37.7749); // lat
      expect(target[1], -122.4194); // lng
    });

    testWidgets('is omitted from creationParams when null', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

      final params = platform.lastCreationParams;
      expect(params, isNotNull);
      expect(params!.containsKey('initialCameraPosition'), isFalse);
    });

    testWidgets('no initialCameraPosition and style without camera settings '
        'falls back to platform default', (tester) async {
      // Style has no center/zoom/bearing/pitch — platform must fall back
      // to its own defaults (typically center [0,0], zoom 0).
      const noCameraStyle =
          '{"version":8,"sources":{},"layers":[{"id":"bg","type":"background","paint":{"background-color":"#fff"}}]}';

      platform.triggerPlatformViewCreated = true;
      MapLibreMapController? controller;

      await tester.pumpWidget(
        MaterialApp(
          home: MapLibreMap(
            styleString: noCameraStyle,
            onMapCreated: (c) => controller = c,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // creationParams should have no camera
      final params = platform.lastCreationParams!;
      expect(params.containsKey('initialCameraPosition'), isFalse);
      expect(params['styleString'], noCameraStyle);

      // Controller starts with no camera knowledge
      expect(controller, isNotNull);
      expect(controller!.cameraPosition, isNull);

      // Platform settles on default [0,0] zoom 0 (no style camera either)
      const platformDefault = CameraPosition(target: LatLng(0, 0));
      platform.onCameraIdlePlatform.call(platformDefault);

      expect(controller!.cameraPosition, isNotNull);
      expect(controller!.cameraPosition!.target, const LatLng(0, 0));
      expect(controller!.cameraPosition!.zoom, 0);
    });

    testWidgets('camera with default values is still sent to platform', (
      tester,
    ) async {
      // User explicitly sets center [0,0] — this IS an intentional
      // camera position and must be forwarded to the platform.
      const camera = CameraPosition(target: LatLng(0, 0));

      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap(initialCameraPosition: camera)),
      );

      final params = platform.lastCreationParams!;
      expect(params.containsKey('initialCameraPosition'), isTrue);
      final cameraMap = params['initialCameraPosition'] as Map<String, dynamic>;
      expect(cameraMap['zoom'], 0.0);
      expect(cameraMap['bearing'], 0.0);
      expect(cameraMap['tilt'], 0.0);
      final target = cameraMap['target'] as List;
      expect(target[0], 0.0);
      expect(target[1], 0.0);
    });
  });

  group('androidView', () {
    testWidgets('reaches the platform when set', (tester) async {
      const view = AndroidMapView(
        surface: AndroidMapSurface.textureView,
        composition: AndroidComposition.hybridComposition,
      );

      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap(androidView: view)),
      );

      expect(platform.lastCreationParams!['androidView'], view);
    });

    test('compares by value', () {
      const a = AndroidMapView(surface: AndroidMapSurface.textureView);
      const b = AndroidMapView(surface: AndroidMapSurface.textureView);
      const c = AndroidMapView(
        surface: AndroidMapSurface.textureView,
        composition: AndroidComposition.hybridComposition,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(
        c.toString(),
        'AndroidMapView(surface: AndroidMapSurface.textureView, '
        'composition: AndroidComposition.hybridComposition)',
      );
    });

    testWidgets('is left out when null', (tester) async {
      await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

      expect(platform.lastCreationParams!.containsKey('androidView'), isFalse);
    });
  });

  group('disposed before the platform view is created', () {
    testWidgets('does not wire up the platform afterwards (#1048)', (
      tester,
    ) async {
      MapLibreMapController? created;
      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap(onMapCreated: (c) => created = c)),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(platform.wasCalled('initPlatform'), isFalse);

      // The platform view shows up after the widget is gone.
      platform.lastOnPlatformViewCreated!(0);
      await tester.pump();

      expect(platform.wasCalled('initPlatform'), isFalse);
      expect(platform.onMapStyleLoadedPlatform.isEmpty, isTrue);
      expect(platform.onCameraMovePlatform.isEmpty, isTrue);
      expect(created, isNull);
    });

    testWidgets('a style load during the map creation stops quietly when the '
        'widget goes away', (tester) async {
      // The controller listens to the platform before the map is created, so
      // a style can load while initPlatform is still running. If the widget
      // goes away then, the annotation setup that load started fails because
      // the map is gone and must not surface as an unhandled error.
      final initDone = Completer<void>();
      platform.onInitPlatform = (_) => initDone.future;
      final sourceAdded = Completer<void>();
      platform.onAddGeoJsonSource = (_) => sourceAdded.future;
      MapLibreMapController? created;

      await tester.pumpWidget(
        MaterialApp(home: MapLibreMap(onMapCreated: (c) => created = c)),
      );
      platform.lastOnPlatformViewCreated!(0);
      await tester.pump();
      platform.onMapStyleLoadedPlatform.call(null);
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      sourceAdded.completeError(PlatformException(code: 'MAP_DISPOSED'));
      initDone.complete();
      await tester.pump();

      expect(created, isNull);
      expect(platform.wasCalled('addFillLayer'), isFalse);
    });
  });

  group('onStyleLoaded manager disposal', () {
    test('disposes old managers and re-creates them on style reload', () async {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      // First style load — creates managers.
      platform.onMapStyleLoadedPlatform.call(null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.fillManager, isNotNull);
      expect(controller.lineManager, isNotNull);
      expect(controller.circleManager, isNotNull);
      expect(controller.symbolManager, isNotNull);

      final oldFill = controller.fillManager;
      final oldLine = controller.lineManager;

      // Second style load — disposes old managers, creates new ones.
      platform.onMapStyleLoadedPlatform.call(null);
      await Future<void>.delayed(Duration.zero);

      expect(controller.fillManager, isNotNull);
      expect(controller.fillManager, isNot(same(oldFill)));
      expect(controller.lineManager, isNot(same(oldLine)));

      controller.dispose();
    });
  });

  group('onStyleLoaded when the style is gone (#992)', () {
    MapLibreMapController createController(void Function() onStyleLoaded) {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onStyleLoadedCallback: onStyleLoaded,
      );
      addTearDown(controller.dispose);
      return controller;
    }

    test(
      'a STYLE_NOT_READY error is not reported and the next load recovers',
      () async {
        var styleLoads = 0;
        final controller = createController(() => styleLoads++);
        final errors = <Object>[];

        final logs = <String?>[];
        final previousDebugPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) => logs.add(message);
        addTearDown(() => debugPrint = previousDebugPrint);

        platform.onAddGeoJsonSource = (_) async {
          throw PlatformException(
            code: 'STYLE_NOT_READY',
            message: 'Style is null or not fully loaded.',
          );
        };
        await runZonedGuarded(() async {
          platform.onMapStyleLoadedPlatform.call(null);
          await pumpEventQueue();
        }, (error, _) => errors.add(error));
        debugPrint = previousDebugPrint;

        expect(errors, isEmpty);
        expect(logs, [contains('STYLE_NOT_READY')]);
        expect(styleLoads, 0);
        expect(controller.fillManager?.isInitialized ?? false, isFalse);

        // The style is there by the next load.
        platform.onAddGeoJsonSource = null;
        platform.onMapStyleLoadedPlatform.call(null);
        await pumpEventQueue();

        expect(styleLoads, 1);
        expect(controller.fillManager!.isInitialized, isTrue);
        expect(controller.symbolManager!.isInitialized, isTrue);
      },
    );

    test('any other error is still reported', () async {
      createController(() {});
      final errors = <Object>[];

      platform.onAddGeoJsonSource = (_) async {
        throw PlatformException(code: 'SOURCE_ALREADY_EXISTS');
      };
      await runZonedGuarded(() async {
        platform.onMapStyleLoadedPlatform.call(null);
        await pumpEventQueue();
      }, (error, _) => errors.add(error));

      expect(errors, [
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'SOURCE_ALREADY_EXISTS',
        ),
      ]);
    });

    test('a setup overtaken by a newer style load stops quietly', () async {
      var styleLoads = 0;
      final controller = createController(() => styleLoads++);
      final errors = <Object>[];

      // The first load's setup is held back until the style has been
      // replaced, and then fails against the style that is gone.
      final release = Completer<void>();
      var first = true;
      platform.onAddGeoJsonSource = (_) async {
        if (!first) return;
        first = false;
        await release.future;
        throw PlatformException(code: 'LAYER_NOT_FOUND_ERROR');
      };
      await runZonedGuarded(() async {
        platform.onMapStyleLoadedPlatform.call(null);
        await pumpEventQueue();
        platform.onMapStyleLoadedPlatform.call(null);
        await pumpEventQueue();
        release.complete();
        await pumpEventQueue();
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty);
      expect(styleLoads, 1);
      expect(controller.fillManager!.isInitialized, isTrue);
      expect(controller.symbolManager!.isInitialized, isTrue);
    });

    test('a setup that succeeds after being overtaken does not call back for '
        'the old style', () async {
      var styleLoads = 0;
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        // One manager, so the held call is inside the last initialize().
        annotationOrder: const [AnnotationType.fill],
        annotationConsumeTapEvents: const [AnnotationType.fill],
        onStyleLoadedCallback: () => styleLoads++,
      );
      addTearDown(controller.dispose);

      final release = Completer<void>();
      var first = true;
      platform.onAddGeoJsonSource = (_) async {
        if (!first) return;
        first = false;
        await release.future;
      };
      platform.onMapStyleLoadedPlatform.call(null);
      await pumpEventQueue();
      platform.onMapStyleLoadedPlatform.call(null);
      await pumpEventQueue();
      expect(styleLoads, 1);

      release.complete();
      await pumpEventQueue();

      expect(styleLoads, 1);
      expect(controller.fillManager!.isInitialized, isTrue);
    });
  });

  group('Controller initialCameraPosition', () {
    test('cameraPosition is null when initialCameraPosition is null', () {
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, isNull);
      controller.dispose();
    });

    test('cameraPosition matches provided initialCameraPosition', () {
      const camera = CameraPosition(target: LatLng(10, 20), zoom: 5);

      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: camera,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, camera);
      controller.dispose();
    });

    test('null camera with no style camera — '
        'platform reports default position on idle', () {
      // Neither initialCameraPosition nor style camera is set.
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      // Before any platform event, controller has no camera knowledge.
      expect(controller.cameraPosition, isNull);

      // The platform settles on its default (center [0,0], zoom 0).
      const platformDefault = CameraPosition(target: LatLng(0, 0));
      platform.onCameraIdlePlatform.call(platformDefault);

      expect(controller.cameraPosition, isNotNull);
      expect(controller.cameraPosition!.target, const LatLng(0, 0));
      expect(controller.cameraPosition!.zoom, 0);

      controller.dispose();
    });

    test('null camera with style camera — '
        'platform reports style position on idle', () {
      // initialCameraPosition is null; style has center/zoom.
      // The platform should use the style camera and report it back.
      final controller = MapLibreMapController(
        maplibrePlatform: platform,
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
      );

      expect(controller.cameraPosition, isNull);

      // Simulate the platform applying the style's camera.
      const styleCamera = CameraPosition(
        target: LatLng(17.654, 32.954),
        zoom: 0.86,
      );
      platform.onCameraIdlePlatform.call(styleCamera);

      expect(controller.cameraPosition, isNotNull);
      expect(controller.cameraPosition!.target.latitude, closeTo(17.654, 1e-6));
      expect(
        controller.cameraPosition!.target.longitude,
        closeTo(32.954, 1e-6),
      );
      expect(controller.cameraPosition!.zoom, closeTo(0.86, 1e-6));

      controller.dispose();
    });
  });
}
