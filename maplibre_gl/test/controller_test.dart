import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show EdgeInsets;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'helpers/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform platform;
  late MapLibreMapController controller;

  setUp(() {
    platform = FakeMapLibrePlatform();
    controller = MapLibreMapController(
      maplibrePlatform: platform,
      initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
      annotationOrder: AnnotationType.values,
      annotationConsumeTapEvents: AnnotationType.values,
    );
    platform.reset();
  });

  group('Camera delegation', () {
    test('animateCamera delegates to platform', () async {
      final update = CameraUpdate.newLatLng(const LatLng(10, 20));
      await controller.animateCamera(update);

      final calls = platform.callsFor('animateCamera');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, update);
      expect(calls.first.namedArgs['duration'], isNull);
    });

    test('animateCamera with duration', () async {
      final update = CameraUpdate.zoomIn();
      await controller.animateCamera(
        update,
        duration: const Duration(milliseconds: 500),
      );

      final calls = platform.callsFor('animateCamera');
      expect(
        calls.first.namedArgs['duration'],
        const Duration(milliseconds: 500),
      );
    });

    test('moveCamera delegates to platform', () async {
      final update = CameraUpdate.newLatLng(const LatLng(10, 20));
      await controller.moveCamera(update);

      final calls = platform.callsFor('moveCamera');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, update);
    });

    test('easeCamera delegates to platform', () async {
      final update = CameraUpdate.zoomTo(12);
      await controller.easeCamera(update, duration: const Duration(seconds: 1));

      final calls = platform.callsFor('easeCamera');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, update);
      expect(calls.first.namedArgs['duration'], const Duration(seconds: 1));
    });

    test('setTrackingCameraOptions delegates to platform', () async {
      final applied = await controller.setTrackingCameraOptions(
        tilt: 45,
        duration: const Duration(milliseconds: 250),
      );

      final calls = platform.callsFor('setTrackingCameraOptions');
      expect(calls.length, 1);
      expect(calls.first.namedArgs['tilt'], 45.0);
      expect(
        calls.first.namedArgs['duration'],
        const Duration(milliseconds: 250),
      );
      expect(applied, isTrue);
    });

    test('setTrackingCameraOptions passes a null duration through', () async {
      await controller.setTrackingCameraOptions(tilt: 0);

      final calls = platform.callsFor('setTrackingCameraOptions');
      expect(calls.first.namedArgs['duration'], isNull);
    });

    test('setTrackingCameraOptions reports a cancelled animation', () async {
      platform.trackingCameraOptionsResult = false;

      expect(await controller.setTrackingCameraOptions(tilt: 45), isFalse);
    });

    test('setTrackingCameraOptions rejects a tilt out of range', () async {
      // 60 degrees is the maximum pitch both native SDKs allow.
      for (final tilt in <double>[-1, 60.5, double.nan]) {
        expect(
          () => controller.setTrackingCameraOptions(tilt: tilt),
          throwsArgumentError,
          reason: 'tilt $tilt should be rejected',
        );
      }
      expect(platform.wasCalled('setTrackingCameraOptions'), isFalse);
    });

    test('setTrackingCameraOptions accepts the range boundaries', () async {
      await controller.setTrackingCameraOptions(tilt: 0);
      await controller.setTrackingCameraOptions(tilt: 60);

      expect(platform.callsFor('setTrackingCameraOptions').length, 2);
    });

    test('setTrackingCameraOptions rejects a negative duration', () async {
      expect(
        () => controller.setTrackingCameraOptions(
          tilt: 45,
          duration: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
      expect(platform.wasCalled('setTrackingCameraOptions'), isFalse);
    });

    test('queryCameraPosition delegates to platform', () async {
      final result = await controller.queryCameraPosition();

      expect(platform.wasCalled('queryCameraPosition'), isTrue);
      expect(result, isNotNull);
      expect(result!.target, const LatLng(0, 0));
    });
  });

  group('Source management delegation', () {
    test('addGeoJsonSource delegates to platform', () async {
      final geojson = buildFeatureCollection([]);
      await controller.addGeoJsonSource('src-1', geojson, promoteId: 'id');

      final calls = platform.callsFor('addGeoJsonSource');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], geojson);
      expect(calls.first.namedArgs['promoteId'], 'id');
    });

    test('setGeoJsonSource delegates to platform', () async {
      final geojson = buildFeatureCollection([]);
      await controller.setGeoJsonSource('src-1', geojson);

      final calls = platform.callsFor('setGeoJsonSource');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
    });

    test('addSource delegates to platform', () async {
      const props = VectorSourceProperties(
        url: 'https://example.com/tiles.json',
      );
      await controller.addSource('vec-1', props);

      final calls = platform.callsFor('addSource');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'vec-1');
    });

    test('removeSource delegates to platform', () async {
      await controller.removeSource('src-1');

      final calls = platform.callsFor('removeSource');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, 'src-1');
    });

    test('setGeoJsonFeature delegates to setFeatureForGeoJsonSource', () async {
      final feature = <String, dynamic>{
        'type': 'Feature',
        'id': 'f1',
        'properties': <String, dynamic>{},
      };
      await controller.setGeoJsonFeature('src-1', feature);

      final calls = platform.callsFor('setFeatureForGeoJsonSource');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], feature);
    });
  });

  group('Layer management delegation', () {
    test('addCircleLayer delegates to platform', () async {
      await controller.addCircleLayer(
        'src-1',
        'layer-1',
        const CircleLayerProperties(circleColor: '#ff0000'),
      );

      final calls = platform.callsFor('addCircleLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], 'layer-1');
    });

    test('addLineLayer delegates to platform', () async {
      await controller.addLineLayer(
        'src-1',
        'layer-1',
        const LineLayerProperties(lineColor: '#00ff00'),
      );

      final calls = platform.callsFor('addLineLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], 'layer-1');
    });

    test('addFillLayer delegates to platform', () async {
      await controller.addFillLayer(
        'src-1',
        'layer-1',
        const FillLayerProperties(fillColor: '#0000ff'),
      );

      final calls = platform.callsFor('addFillLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], 'layer-1');
    });

    test('addSymbolLayer delegates to platform', () async {
      await controller.addSymbolLayer(
        'src-1',
        'layer-1',
        const SymbolLayerProperties(iconImage: 'marker'),
      );

      final calls = platform.callsFor('addSymbolLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'src-1');
      expect(calls.first.positionalArgs[1], 'layer-1');
    });

    test('addLayer dispatches to correct typed method', () async {
      await controller.addLayer(
        'src-1',
        'layer-1',
        const FillLayerProperties(fillColor: '#0000ff'),
      );

      expect(platform.wasCalled('addFillLayer'), isTrue);
    });

    test('addColorReliefLayer delegates to platform', () async {
      await controller.addColorReliefLayer(
        'dem-1',
        'layer-1',
        const ColorReliefLayerProperties(colorReliefOpacity: 0.7),
      );

      final calls = platform.callsFor('addColorReliefLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'dem-1');
      expect(calls.first.positionalArgs[1], 'layer-1');
      expect(
        (calls.first.positionalArgs[2] as Map)['color-relief-opacity'],
        0.7,
      );
    });

    test('addLayer with ColorReliefLayerProperties', () async {
      await controller.addLayer(
        'dem-1',
        'layer-1',
        const ColorReliefLayerProperties(colorReliefOpacity: 0.7),
      );

      expect(platform.wasCalled('addColorReliefLayer'), isTrue);
    });

    test('addLayer rejects a filter on ColorReliefLayerProperties', () async {
      expect(
        () => controller.addLayer(
          'dem-1',
          'layer-1',
          const ColorReliefLayerProperties(),
          filter: ['==', 'foo', 'bar'],
        ),
        throwsUnimplementedError,
      );
      expect(platform.wasCalled('addColorReliefLayer'), isFalse);
    });

    test('addBackgroundLayer delegates to platform', () async {
      await controller.addBackgroundLayer(
        'layer-1',
        const BackgroundLayerProperties(backgroundColor: '#ff0000'),
      );

      final calls = platform.callsFor('addBackgroundLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'layer-1');
      expect(calls.first.positionalArgs[1], {'background-color': '#ff0000'});
    });

    test('addLayer with BackgroundLayerProperties', () async {
      await controller.addLayer(
        'unused-source',
        'layer-1',
        const BackgroundLayerProperties(backgroundOpacity: 0.5),
      );

      final calls = platform.callsFor('addBackgroundLayer');
      expect(calls.length, 1);
      // The background layer has no source, so the source id is dropped and
      // the layer id stays the first argument.
      expect(calls.first.positionalArgs, [
        'layer-1',
        {'background-opacity': 0.5},
      ]);
    });

    test('addLayer rejects a filter on BackgroundLayerProperties', () async {
      expect(
        () => controller.addLayer(
          'unused-source',
          'layer-1',
          const BackgroundLayerProperties(),
          filter: ['==', 'foo', 'bar'],
        ),
        throwsUnimplementedError,
      );
      expect(platform.wasCalled('addBackgroundLayer'), isFalse);
    });

    test('setSky delegates to platform', () async {
      await controller.setSky(const SkyProperties(skyColor: '#88C6FC'));

      final calls = platform.callsFor('setSky');
      expect(calls.length, 1);
      expect(
        (calls.first.positionalArgs.first as SkyProperties).skyColor,
        '#88C6FC',
      );
    });

    test('setTerrain delegates to platform', () async {
      await controller.setTerrain(
        const TerrainProperties(source: 'dem-1', exaggeration: 1.5),
      );
      await controller.setTerrain(null);

      final calls = platform.callsFor('setTerrain');
      expect(calls.length, 2);
      expect(
        (calls.first.positionalArgs.first as TerrainProperties).source,
        'dem-1',
      );
      expect(calls[1].positionalArgs.first, isNull);
    });

    test('setProjection delegates to platform', () async {
      await controller.setProjection('globe');

      final calls = platform.callsFor('setProjection');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, 'globe');
    });

    test('setLight delegates to platform', () async {
      await controller.setLight(const LightProperties(intensity: 0.4));

      final calls = platform.callsFor('setLight');
      expect(calls.length, 1);
      expect(
        (calls.first.positionalArgs.first as LightProperties).intensity,
        0.4,
      );
    });

    test('setGlobalStateProperty delegates to platform', () async {
      await controller.setGlobalStateProperty('theme', 'dark');

      final calls = platform.callsFor('setGlobalStateProperty');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs, ['theme', 'dark']);
    });

    test('addLayer with CircleLayerProperties', () async {
      await controller.addLayer(
        'src-1',
        'layer-1',
        const CircleLayerProperties(circleColor: '#ff0000'),
      );

      expect(platform.wasCalled('addCircleLayer'), isTrue);
    });

    test('removeLayer delegates to platform', () async {
      await controller.removeLayer('layer-1');

      final calls = platform.callsFor('removeLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, 'layer-1');
    });

    test('setLayerVisibility delegates to platform', () async {
      await controller.setLayerVisibility('layer-1', false);

      final calls = platform.callsFor('setLayerVisibility');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'layer-1');
      expect(calls.first.positionalArgs[1], false);
    });

    test('addImageLayer delegates to addLayer on platform', () async {
      await controller.addImageLayer('img-layer', 'img-source');

      final calls = platform.callsFor('addLayer');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs[0], 'img-layer');
      expect(calls.first.positionalArgs[1], 'img-source');
    });
  });

  group('Map queries delegation', () {
    test('toScreenLocation delegates to platform', () async {
      final result = await controller.toScreenLocation(const LatLng(10, 20));

      expect(result, const Point(0, 0));
    });

    test('toLatLng delegates to platform', () async {
      final result = await controller.toLatLng(const Point(100, 200));

      expect(result, const LatLng(0, 0));
    });

    test('getVisibleRegion delegates to platform', () async {
      final bounds = await controller.getVisibleRegion();

      expect(bounds.southwest, const LatLng(-1, -1));
      expect(bounds.northeast, const LatLng(1, 1));
    });

    test('requestMyLocationLatLng delegates to platform', () async {
      final loc = await controller.requestMyLocationLatLng();

      expect(loc, const LatLng(0, 0));
    });
  });

  group('Cluster inspection delegation', () {
    test('getClusterExpansionZoom delegates to platform', () async {
      platform.clusterExpansionZoom = 11;

      final zoom = await controller.getClusterExpansionZoom('events', 42);

      final calls = platform.callsFor('getClusterExpansionZoom');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs, ['events', 42]);
      expect(zoom, 11);
    });

    test('getClusterChildren delegates to platform', () async {
      platform.clusterFeatures = [
        {
          'type': 'Feature',
          'properties': {'cluster_id': 7},
        },
      ];

      final children = await controller.getClusterChildren('events', 42);

      final calls = platform.callsFor('getClusterChildren');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs, ['events', 42]);
      expect(children, platform.clusterFeatures);
    });

    test('getClusterLeaves defaults limit to 10 and offset to 0', () async {
      await controller.getClusterLeaves('events', 42);

      final calls = platform.callsFor('getClusterLeaves');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs, ['events', 42]);
      expect(calls.first.namedArgs['limit'], 10);
      expect(calls.first.namedArgs['offset'], 0);
    });

    test('getClusterLeaves forwards limit and offset', () async {
      await controller.getClusterLeaves('events', 42, limit: 50, offset: 100);

      final calls = platform.callsFor('getClusterLeaves');
      expect(calls.first.namedArgs['limit'], 50);
      expect(calls.first.namedArgs['offset'], 100);
    });
  });

  group('Snapshot delegation', () {
    test(
      'takeSnapshot captures current view when no dimensions given',
      () async {
        final result = await controller.takeSnapshot();

        final calls = platform.callsFor('takeSnapshot');
        expect(calls.length, 1);
        expect(calls.first.namedArgs['width'], isNull);
        expect(calls.first.namedArgs['height'], isNull);
        expect(result, isA<Uint8List>());
        expect(result.isNotEmpty, isTrue);
      },
    );

    test('takeSnapshot at landscape resolution', () async {
      final result = await controller.takeSnapshot(width: 800, height: 600);

      final calls = platform.callsFor('takeSnapshot');
      expect(calls.length, 1);
      expect(calls.first.namedArgs['width'], 800);
      expect(calls.first.namedArgs['height'], 600);
      expect(result, isA<Uint8List>());
      expect(result.isNotEmpty, isTrue);
    });

    test('takeSnapshot at portrait resolution', () async {
      final result = await controller.takeSnapshot(width: 360, height: 800);

      final calls = platform.callsFor('takeSnapshot');
      expect(calls.length, 1);
      expect(calls.first.namedArgs['width'], 360);
      expect(calls.first.namedArgs['height'], 800);
      expect(result, isA<Uint8List>());
      expect(result.isNotEmpty, isTrue);
    });

    test('takeSnapshot with only width forwards partial dimensions', () async {
      await controller.takeSnapshot(width: 1024);

      final calls = platform.callsFor('takeSnapshot');
      expect(calls.length, 1);
      expect(calls.first.namedArgs['width'], 1024);
      expect(calls.first.namedArgs['height'], isNull);
    });

    test('takeSnapshot with only height forwards partial dimensions', () async {
      await controller.takeSnapshot(height: 768);

      final calls = platform.callsFor('takeSnapshot');
      expect(calls.length, 1);
      expect(calls.first.namedArgs['width'], isNull);
      expect(calls.first.namedArgs['height'], 768);
    });
  });

  group('Style delegation', () {
    test('setStyle delegates to platform', () async {
      await controller.setStyle('mapbox://styles/test');

      final calls = platform.callsFor('setStyle');
      expect(calls.length, 1);
      expect(calls.first.positionalArgs.first, 'mapbox://styles/test');
    });
  });

  group('Camera state tracking', () {
    test('initial cameraPosition matches constructor', () {
      expect(controller.cameraPosition, isNotNull);
      expect(controller.cameraPosition!.target, const LatLng(0, 0));
    });

    test('isCameraMoving is initially false', () {
      expect(controller.isCameraMoving, isFalse);
    });

    test('camera move started sets isCameraMoving to true', () {
      platform.onCameraMoveStartedPlatform.call(null);

      expect(controller.isCameraMoving, isTrue);
    });

    test('camera idle sets isCameraMoving to false', () {
      platform.onCameraMoveStartedPlatform.call(null);
      platform.onCameraIdlePlatform.call(
        const CameraPosition(target: LatLng(5, 5)),
      );

      expect(controller.isCameraMoving, isFalse);
    });

    test('camera move updates cameraPosition', () {
      const newPos = CameraPosition(target: LatLng(10, 20), zoom: 12);
      platform.onCameraMovePlatform.call(newPos);

      expect(controller.cameraPosition, newPos);
    });
  });

  group('Callback wiring', () {
    test('onMapClick fires from platform event', () {
      Point<double>? clickPoint;
      LatLng? clickLatLng;

      final clickController = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onMapClick: (point, latLng) {
          clickPoint = point;
          clickLatLng = latLng;
        },
      );

      platform.onMapClickPlatform.call({
        'point': const Point<double>(100, 200),
        'latLng': const LatLng(10, 20),
      });

      expect(clickPoint, const Point<double>(100, 200));
      expect(clickLatLng, const LatLng(10, 20));

      // Avoid leak
      clickController.dispose();
    });

    test('onMapLongClick fires from platform event', () {
      LatLng? longClickLatLng;

      final longClickController = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onMapLongClick: (point, latLng) {
          longClickLatLng = latLng;
        },
      );

      platform.onMapLongClickPlatform.call({
        'point': const Point<double>(100, 200),
        'latLng': const LatLng(30, 40),
      });

      expect(longClickLatLng, const LatLng(30, 40));

      longClickController.dispose();
    });

    test('onCameraTrackingChanged fires from platform event', () {
      MyLocationTrackingMode? receivedMode;

      final trackingController = MapLibreMapController(
        maplibrePlatform: platform,
        initialCameraPosition: const CameraPosition(target: LatLng(0, 0)),
        annotationOrder: AnnotationType.values,
        annotationConsumeTapEvents: AnnotationType.values,
        onCameraTrackingChanged: (mode) {
          receivedMode = mode;
        },
      );

      platform.onCameraTrackingChangedPlatform.call(
        MyLocationTrackingMode.tracking,
      );

      expect(receivedMode, MyLocationTrackingMode.tracking);

      trackingController.dispose();
    });
  });

  group('Dispose', () {
    test('isDisposed is initially false', () {
      expect(controller.isDisposed, isFalse);
    });

    test('isDisposed is true after dispose', () {
      controller.dispose();

      expect(controller.isDisposed, isTrue);
    });
  });

  group('Rendering control delegation', () {
    test('pauseMap delegates to platform', () async {
      await controller.pauseMap();

      expect(platform.callsFor('pauseMap').length, 1);
    });

    test('resumeMap delegates to platform', () async {
      await controller.resumeMap();

      expect(platform.callsFor('resumeMap').length, 1);
    });
  });

  group('Padding', () {
    test(
      'setPadding maps named edges to EdgeInsets via updateContentInsets',
      () async {
        await controller.setPadding(
          left: 10,
          top: 20,
          right: 30,
          bottom: 40,
          animated: true,
        );

        final calls = platform.callsFor('updateContentInsets');
        expect(calls.length, 1);
        expect(
          calls.first.positionalArgs.first,
          const EdgeInsets.only(left: 10, top: 20, right: 30, bottom: 40),
        );
        expect(calls.first.namedArgs['animated'], isTrue);
      },
    );

    test(
      'setPadding defaults missing edges to zero and not animated',
      () async {
        await controller.setPadding(bottom: 50);

        final calls = platform.callsFor('updateContentInsets');
        expect(calls.length, 1);
        expect(
          calls.first.positionalArgs.first,
          const EdgeInsets.only(bottom: 50),
        );
        expect(calls.first.namedArgs['animated'], isFalse);
      },
    );
  });
}
