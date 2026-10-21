// The Android and iOS platform of each map: its calls go through the
// Pigeon-generated MapLibreMapHostApi, replaced here by a fake that records
// them, and native events arrive through MapLibreMapFlutterApi. Web has its
// own platform, hence vm only.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl/src/native/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewId = 7;

  late _FakeMapHostApi api;
  late List<int> hostApiIds;
  late MapLibrePlatform platform;
  late MapLibrePlatform Function() previousFactory;

  setUp(() async {
    previousFactory = MapLibrePlatform.createInstance;
    api = _FakeMapHostApi();
    hostApiIds = [];
    MapLibreNativePlugin.registerWith(
      mapHostApi: (id) {
        hostApiIds.add(id);
        return api;
      },
    );
    platform = MapLibrePlatform.createInstance();
  });

  tearDown(() {
    platform.dispose();
    MapLibrePlatform.createInstance = previousFactory;
  });

  /// Initializes the platform and forgets the waitForMap call.
  Future<void> init() async {
    await platform.initPlatform(viewId);
    api.calls.clear();
  }

  /// What native does to report an event: a message on the channel of the
  /// map, encoded the way the generated Kotlin and Swift encode it. Completes
  /// with the reply, null when nothing listens.
  Future<ByteData?> sendFromNative(String method, List<Object?>? args) async {
    final reply = Completer<ByteData?>();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          'dev.flutter.pigeon.maplibre_gl.MapLibreMapFlutterApi.$method.$viewId',
          MapLibreMapFlutterApi.pigeonChannelCodec.encodeMessage(args),
          reply.complete,
        );
    return reply.future;
  }

  group('registration', () {
    test('registerWith makes createInstance build the Pigeon platform', () {
      expect(platform, isA<MapLibreMapFlutterApi>());
      // The deprecated method channel platform is what must be gone.
      // ignore: deprecated_member_use
      expect(platform, isNot(isA<MapLibreMethodChannel>()));
    });

    testWidgets(
      'a map installs the Pigeon platform when the registrant did not run',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        // The default factory, as in an isolate where the registrant of the
        // app never ran.
        // ignore: deprecated_member_use
        MapLibrePlatform.createInstance = MapLibreMethodChannel.new;
        // The platform view itself has no native side here.
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async => null,
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          ),
        );

        await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

        expect(MapLibrePlatform.createInstance(), isA<MapLibreMapFlutterApi>());
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a map keeps a subclass of the method channel platform',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        // A package that installed its own platform, built on the deprecated
        // default, did so on purpose.
        MapLibrePlatform appFactory() => _AppMethodChannel();
        MapLibrePlatform.createInstance = appFactory;

        await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

        expect(find.byKey(_AppMethodChannel.viewKey), findsOneWidget);
        expect(MapLibrePlatform.createInstance, same(appFactory));
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('initPlatform', () {
    test('binds the client to the platform view id', () async {
      await platform.initPlatform(viewId);

      expect(hostApiIds, [viewId]);
      expect(api.calls, [
        ['mapWaitForMap'],
      ]);
    });

    test('listens to native before waiting for the map', () async {
      var styleLoads = 0;
      platform.onMapStyleLoadedPlatform.add((_) => styleLoads++);
      // Native may report the style before it answers waitForMap.
      api.onWaitForMap = () async {
        await sendFromNative('mapOnStyleLoaded', null);
      };

      await platform.initPlatform(viewId);

      expect(styleLoads, 1);
    });

    test('calls before it fail with a StateError', () {
      expect(() => platform.getLayerIds(), throwsStateError);
      expect(api.calls, isEmpty);
    });
  });

  group('dispose', () {
    test('before initPlatform does not throw', () {
      var styleLoads = 0;
      platform.onMapStyleLoadedPlatform.add((_) => styleLoads++);

      expect(platform.dispose, returnsNormally);

      platform.onMapStyleLoadedPlatform(null);
      expect(styleLoads, 0);
    });

    test('stops listening to native', () async {
      await init();
      expect(await sendFromNative('mapOnIdle', null), isNotNull);

      platform.dispose();

      expect(await sendFromNative('mapOnIdle', null), isNull);
    });
  });

  group('camera', () {
    setUp(init);

    test('animateCamera sends the update and the duration', () async {
      api.replies['cameraAnimate'] = true;

      final result = await platform.animateCamera(
        CameraUpdate.zoomTo(5),
        duration: const Duration(milliseconds: 300),
      );

      expect(result, isTrue);
      expect(api.calls, [
        [
          'cameraAnimate',
          ['zoomTo', 5.0],
          300,
        ],
      ]);
    });

    test('animateCamera sends a null duration when unset', () async {
      await platform.animateCamera(CameraUpdate.zoomIn());

      expect(api.calls, [
        [
          'cameraAnimate',
          ['zoomIn'],
          null,
        ],
      ]);
    });

    test('moveCamera sends the update', () async {
      api.replies['cameraMove'] = false;

      final result = await platform.moveCamera(
        CameraUpdate.newLatLng(const LatLng(1, 2)),
      );

      expect(result, isFalse);
      expect(api.calls, [
        [
          'cameraMove',
          [
            'newLatLng',
            [1.0, 2.0],
          ],
        ],
      ]);
    });

    test('easeCamera sends the interpolation by name', () async {
      api.replies['cameraEase'] = true;

      final result = await platform.easeCamera(
        CameraUpdate.bearingTo(90),
        duration: const Duration(milliseconds: 200),
        interpolation: CameraAnimationInterpolation.fastOutLinearIn,
      );

      expect(result, isTrue);
      expect(api.calls, [
        [
          'cameraEase',
          ['bearingTo', 90.0],
          200,
          'fastOutLinearIn',
        ],
      ]);
    });

    test('easeCamera sends null for what is unset', () async {
      api.replies['cameraEase'] = false;

      await platform.easeCamera(CameraUpdate.zoomOut());

      expect(api.calls, [
        [
          'cameraEase',
          ['zoomOut'],
          null,
          null,
        ],
      ]);
    });

    test('queryCameraPosition reads the camera map', () async {
      api.replies['mapQueryCameraPosition'] = <Object?, Object?>{
        'bearing': 10.0,
        // An integral value may arrive as an int after a JSON round trip.
        'target': <Object?>[45, 9.5],
        'tilt': 20.0,
        'zoom': 11.0,
      };

      final position = await platform.queryCameraPosition();

      expect(
        position,
        const CameraPosition(
          bearing: 10,
          target: LatLng(45, 9.5),
          tilt: 20,
          zoom: 11,
        ),
      );
    });
  });

  group('layers', () {
    setUp(init);

    test('addSymbolLayer encodes the filter', () async {
      await platform.addSymbolLayer(
        'source',
        'symbols',
        {'icon-image': 'pin'},
        belowLayerId: 'labels',
        sourceLayer: 'poi',
        minzoom: 2,
        maxzoom: 18,
        filter: [
          '==',
          ['get', 'kind'],
          'cafe',
        ],
        enableInteraction: true,
      );

      expect(api.calls, [
        [
          'symbolLayerAdd',
          'source',
          'symbols',
          'labels',
          'poi',
          2.0,
          18.0,
          '["==",["get","kind"],"cafe"]',
          true,
          {'icon-image': 'pin'},
        ],
      ]);
    });

    test('addLineLayer sends the string null without a filter', () async {
      await platform.addLineLayer(
        'source',
        'lines',
        const {},
        enableInteraction: false,
      );

      expect(api.calls.single[7], 'null');
    });

    test('addHeatmapLayer encodes the filter', () async {
      await platform.addHeatmapLayer(
        'source',
        'heat',
        const {},
        filter: ['has', 'weight'],
      );

      expect(api.calls, [
        [
          'heatmapLayerAdd',
          'source',
          'heat',
          null,
          null,
          null,
          null,
          '["has","weight"]',
          <String, Object?>{},
        ],
      ]);
    });

    test('moveLayer sends a null belowLayerId when unset', () async {
      await platform.moveLayer('a');
      await platform.moveLayer('a', belowLayerId: 'b');

      expect(api.calls, [
        ['styleMoveLayer', 'a', null],
        ['styleMoveLayer', 'a', 'b'],
      ]);
    });

    test('setLayersVisibility returns the missing ids', () async {
      api.replies['layerSetVisibilityBatch'] = <String>['gone'];

      final missing = await platform.setLayersVisibility(['a', 'gone'], false);

      expect(missing, ['gone']);
      expect(api.calls, [
        [
          'layerSetVisibilityBatch',
          ['a', 'gone'],
          false,
        ],
      ]);
    });

    test('getLayerIds reads the layers', () async {
      api.replies['styleGetLayerIds'] = <Object?, Object?>{
        'layers': <Object?>['water', 'roads'],
      };

      expect(await platform.getLayerIds(), ['water', 'roads']);
    });

    test('getLayerProperties decodes and shapes the layer', () async {
      api.replies['styleGetLayerProperties'] = <Object?, Object?>{
        'properties': '{"id":"water","minzoom":4.0}',
      };

      expect(await platform.getLayerProperties('water'), {
        'id': 'water',
        'minzoom': 4,
      });
      expect(api.calls, [
        ['styleGetLayerProperties', 'water'],
      ]);
    });

    test('getLayerProperties is null for a missing layer', () async {
      api.replies['styleGetLayerProperties'] = <Object?, Object?>{};

      expect(await platform.getLayerProperties('none'), isNull);
    });
  });

  group('GeoJSON sources', () {
    setUp(init);

    Map<String, dynamic> line(int points) => {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': List.generate(points, (i) => [i * 0.001, 0.0]),
          },
        },
      ],
    };

    test('addGeoJsonSource sends the encoded data', () async {
      final geojson = line(2);

      await platform.addGeoJsonSource('source', geojson);

      expect(api.calls, [
        ['sourceAddGeoJson', 'source', jsonEncode(geojson)],
      ]);
    });

    // The large payload is encoded on another isolate and finishes after the
    // small one, which must still reach native second.
    test('writes to the same source keep their order', () async {
      final big = line(40000);
      final small = line(1);

      final first = platform.addGeoJsonSource('source', big);
      final second = platform.setGeoJsonSource('source', small);
      await Future.wait([first, second]);

      expect(api.calls, [
        ['sourceAddGeoJson', 'source', jsonEncode(big)],
        ['sourceSetGeoJson', 'source', jsonEncode(small)],
      ]);
    });

    test('a failed write does not block the next one', () async {
      api.errors['sourceSetGeoJson'] = PlatformException(code: 'boom');

      await expectLater(
        platform.setGeoJsonSource('source', line(1)),
        throwsA(isA<PlatformException>()),
      );
      api.errors.clear();
      await platform.setFeatureForGeoJsonSource('source', {
        'type': 'Feature',
        'properties': <String, dynamic>{},
      });

      expect(api.calls.map((call) => call.first), [
        'sourceSetGeoJson',
        'sourceSetFeature',
      ]);
    });

    test('addSource rejects the custom raster-dem encoding', () {
      expect(
        () => platform.addSource(
          'dem',
          const RasterDemSourceProperties(
            tiles: ['https://example.com/{z}/{x}/{y}.png'],
            encoding: 'custom',
          ),
        ),
        throwsUnsupportedError,
      );
      expect(api.calls, isEmpty);
    });
  });

  group('queries', () {
    setUp(init);

    test('queryRenderedFeatures sends the filter list and decodes', () async {
      api.replies['mapQueryRenderedFeaturesAtPoint'] = <Object?, Object?>{
        'features': <Object?>['{"id":1,"type":"Feature"}'],
      };

      final features = await platform.queryRenderedFeatures(
        const Point(10, 20),
        ['layer'],
        [
          '==',
          ['get', 'kind'],
          'cafe',
        ],
      );

      expect(features, [
        {'id': 1, 'type': 'Feature'},
      ]);
      expect(api.calls, [
        [
          'mapQueryRenderedFeaturesAtPoint',
          10.0,
          20.0,
          ['layer'],
          [
            '==',
            ['get', 'kind'],
            'cafe',
          ],
        ],
      ]);
    });

    test('queryRenderedFeaturesInRect sends the filter string', () async {
      api.replies['mapQueryRenderedFeaturesInRect'] = <Object?, Object?>{
        'features': <Object?>[],
      };

      final features = await platform.queryRenderedFeaturesInRect(
        const Rect.fromLTRB(1, 2, 3, 4),
        const [],
        '["has","name"]',
      );

      expect(features, isEmpty);
      expect(api.calls, [
        [
          'mapQueryRenderedFeaturesInRect',
          1.0,
          2.0,
          3.0,
          4.0,
          <String>[],
          '["has","name"]',
        ],
      ]);
    });

    test('getClusterLeaves sends the paging and decodes', () async {
      api.replies['sourceGetClusterLeaves'] = <Object?, Object?>{
        'features': <Object?>['{"id":"a"}'],
      };

      final leaves = await platform.getClusterLeaves(
        'points',
        3,
        limit: 5,
        offset: 2,
      );

      expect(leaves, [
        {'id': 'a'},
      ]);
      expect(api.calls, [
        ['sourceGetClusterLeaves', 'points', 3, 5, 2],
      ]);
    });

    test('getVisibleRegion reads the corners', () async {
      api.replies['mapGetVisibleRegion'] = <Object?, Object?>{
        'sw': <Object?>[10.0, 20.0],
        'ne': <Object?>[30.0, 40.0],
      };

      final region = await platform.getVisibleRegion();

      expect(
        region,
        LatLngBounds(
          southwest: const LatLng(10, 20),
          northeast: const LatLng(30, 40),
        ),
      );
    });

    test('toScreenLocationBatch sends and reads flat pairs', () async {
      api.replies['mapToScreenLocationBatch'] = Float64List.fromList([
        1,
        2,
        3,
        4,
      ]);

      final points = await platform.toScreenLocationBatch(const [
        LatLng(10, 20),
        LatLng(30, 40),
      ]);

      expect(points, const [Point(1.0, 2.0), Point(3.0, 4.0)]);
      final coordinates = api.calls.single[1]! as Float64List;
      expect(coordinates, [10.0, 20.0, 30.0, 40.0]);
    });

    test('toLatLng sends doubles for an int point', () async {
      api.replies['mapToLatLng'] = <Object?, Object?>{
        'latitude': 1.5,
        'longitude': 2.5,
      };

      final latLng = await platform.toLatLng(const Point(3, 4));

      expect(latLng, const LatLng(1.5, 2.5));
      expect(api.calls, [
        ['mapToLatLng', 3.0, 4.0],
      ]);
    });

    test('requestMyLocationLatLng is null when native fails', () async {
      api.errors['locationComponentGetLastLocation'] = PlatformException(
        code: 'NO_LOCATION',
      );

      expect(await platform.requestMyLocationLatLng(), isNull);
    });

    test('getFeatureState decodes the state', () async {
      api.replies['sourceGetFeatureState'] = <Object?, Object?>{
        'state': '{"hover":true}',
      };

      final state = await platform.getFeatureState(
        'source',
        '1',
        sourceLayer: 'layer',
      );

      expect(state, {'hover': true});
      expect(api.calls, [
        ['sourceGetFeatureState', 'source', '1', 'layer'],
      ]);
    });

    test('feature state fails on iOS without reaching native', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => platform.setFeatureState('source', '1', {'hover': true}),
        throwsUnsupportedError,
      );
      expect(api.calls, isEmpty);
    });
  });

  group('takeSnapshot', () {
    setUp(init);

    test('sends null for an unset size', () async {
      api.replies['mapTakeSnapshot'] = Uint8List.fromList([1, 2]);

      final bytes = await platform.takeSnapshot();

      expect(bytes, [1, 2]);
      expect(api.calls, [
        ['mapTakeSnapshot', null, null],
      ]);
    });

    test('sends the size', () async {
      api.replies['mapTakeSnapshot'] = Uint8List(0);

      await platform.takeSnapshot(width: 100, height: 50);

      expect(api.calls, [
        ['mapTakeSnapshot', 100, 50],
      ]);
    });

    test('throws when native answers without an image', () {
      expect(platform.takeSnapshot, throwsException);
    });
  });

  group('events from native', () {
    setUp(init);

    MapLibreMapFlutterApi events() => platform as MapLibreMapFlutterApi;

    test('featureOnTap', () async {
      Map<String, dynamic>? received;
      platform.onFeatureTappedPlatform.add((event) => received = event);

      await events().featureOnTap(
        PgFeatureTap(
          id: 'f1',
          point: PgScreenPoint(x: 1, y: 2),
          latLng: PgLatLng(latitude: 3, longitude: 4),
          layerId: 'layer',
        ),
      );

      expect(received, {
        'id': 'f1',
        'point': const Point<double>(1, 2),
        'latLng': const LatLng(3, 4),
        'layerId': 'layer',
      });
    });

    test('featureOnDrag', () async {
      Map<String, dynamic>? received;
      platform.onFeatureDraggedPlatform.add((event) => received = event);

      await events().featureOnDrag(
        PgFeatureDrag(
          id: 2,
          point: PgScreenPoint(x: 1, y: 2),
          origin: PgLatLng(latitude: 10, longitude: 20),
          current: PgLatLng(latitude: 11, longitude: 21),
          delta: PgLatLng(latitude: 0.5, longitude: 0.25),
          eventType: 'drag',
        ),
      );

      expect(received, {
        'id': 2,
        'point': const Point<double>(1, 2),
        'origin': const LatLng(10, 20),
        'current': const LatLng(11, 21),
        'delta': const LatLng(0.5, 0.25),
        'eventType': 'drag',
      });
    });

    test('cameraOnMoveStarted, through the channel', () async {
      var calls = 0;
      platform.onCameraMoveStartedPlatform.add((_) => calls++);

      // Native tells a gesture from a call; Dart does not pass that on yet
      // (#1019), but takes both.
      expect(await sendFromNative('cameraOnMoveStarted', [true]), isNotNull);
      expect(await sendFromNative('cameraOnMoveStarted', [false]), isNotNull);

      expect(calls, 2);
    });

    test('cameraOnMove, through the channel', () async {
      CameraPosition? received;
      platform.onCameraMovePlatform.add((position) => received = position);

      await sendFromNative('cameraOnMove', [
        PgCameraPosition(
          bearing: 45,
          target: PgLatLng(latitude: 10, longitude: 20),
          tilt: 30,
          zoom: 15,
        ),
      ]);

      expect(
        received,
        const CameraPosition(
          bearing: 45,
          target: LatLng(10, 20),
          tilt: 30,
          zoom: 15,
        ),
      );
    });

    test('cameraOnIdle, with and without a position', () async {
      final received = <CameraPosition?>[];
      platform.onCameraIdlePlatform.add(received.add);

      await events().cameraOnIdle(
        PgCameraPosition(
          bearing: 0,
          target: PgLatLng(latitude: 0, longitude: 0),
          tilt: 0,
          zoom: 5,
        ),
      );
      await events().cameraOnIdle(null);

      expect(received, [
        const CameraPosition(target: LatLng(0, 0), zoom: 5),
        null,
      ]);
    });

    test('mapOnStyleLoaded', () async {
      var calls = 0;
      platform.onMapStyleLoadedPlatform.add((_) => calls++);

      await events().mapOnStyleLoaded();

      expect(calls, 1);
    });

    test('mapOnMapClick and mapOnMapLongClick', () async {
      Map<String, dynamic>? click;
      Map<String, dynamic>? longClick;
      platform.onMapClickPlatform.add((event) => click = event);
      platform.onMapLongClickPlatform.add((event) => longClick = event);

      await events().mapOnMapClick(
        PgScreenPoint(x: 1, y: 2),
        PgLatLng(latitude: 3, longitude: 4),
      );
      await events().mapOnMapLongClick(
        PgScreenPoint(x: 5, y: 6),
        PgLatLng(latitude: 7, longitude: 8),
      );

      expect(click, {
        'point': const Point<double>(1, 2),
        'latLng': const LatLng(3, 4),
      });
      expect(longClick, {
        'point': const Point<double>(5, 6),
        'latLng': const LatLng(7, 8),
      });
    });

    test('mapOnCameraTrackingChanged and Dismissed', () async {
      final modes = <MyLocationTrackingMode>[];
      var dismissals = 0;
      platform.onCameraTrackingChangedPlatform.add(modes.add);
      platform.onCameraTrackingDismissedPlatform.add((_) => dismissals++);

      await events().mapOnCameraTrackingChanged(2);
      await events().mapOnCameraTrackingDismissed();

      expect(modes, [MyLocationTrackingMode.values[2]]);
      expect(dismissals, 1);
    });

    test('mapOnIdle', () async {
      var calls = 0;
      platform.onMapIdlePlatform.add((_) => calls++);

      await events().mapOnIdle();

      expect(calls, 1);
    });

    test('mapOnUserLocationUpdated, with a heading', () async {
      UserLocation? received;
      platform.onUserLocationUpdatedPlatform.add(
        (location) => received = location,
      );

      await events().mapOnUserLocationUpdated(
        PgUserLocation(
          position: PgLatLng(latitude: 45, longitude: 9),
          altitude: 120,
          bearing: 90,
          speed: 3,
          horizontalAccuracy: 5,
          timestamp: 1000,
        ),
        PgUserHeading(
          magneticHeading: 10,
          trueHeading: 12,
          headingAccuracy: 1,
          x: 0.1,
          y: 0.2,
          z: 0.3,
          timestamp: 2000,
        ),
      );

      final location = received!;
      expect(location.position, const LatLng(45, 9));
      expect(location.altitude, 120.0);
      expect(location.bearing, 90.0);
      expect(location.speed, 3.0);
      expect(location.horizontalAccuracy, 5.0);
      expect(location.verticalAccuracy, isNull);
      expect(location.timestamp, DateTime.fromMillisecondsSinceEpoch(1000));
      final heading = location.heading!;
      expect(heading.magneticHeading, 10.0);
      expect(heading.trueHeading, 12.0);
      expect(heading.headingAccuracy, 1.0);
      expect([heading.x, heading.y, heading.z], [0.1, 0.2, 0.3]);
      expect(heading.timestamp, DateTime.fromMillisecondsSinceEpoch(2000));
    });

    test('mapOnUserLocationUpdated, without a heading', () async {
      UserLocation? received;
      platform.onUserLocationUpdatedPlatform.add(
        (location) => received = location,
      );

      await events().mapOnUserLocationUpdated(
        PgUserLocation(
          position: PgLatLng(latitude: 1, longitude: 2),
          timestamp: 0,
        ),
        null,
      );

      expect(received!.heading, isNull);
      expect(received!.altitude, isNull);
    });
  });

  group('events through the channel', () {
    setUp(init);

    PgLatLng pgLatLng(double latitude, double longitude) =>
        PgLatLng(latitude: latitude, longitude: longitude);

    test('featureOnTap with a numeric id', () async {
      Map<String, dynamic>? received;
      platform.onFeatureTappedPlatform.add((event) => received = event);

      await sendFromNative('featureOnTap', [
        PgFeatureTap(
          id: 42,
          point: PgScreenPoint(x: 1, y: 2),
          latLng: pgLatLng(3, 4),
        ),
      ]);

      expect(received, {
        'id': 42,
        'point': const Point<double>(1, 2),
        'latLng': const LatLng(3, 4),
        'layerId': null,
      });
    });

    test('featureOnDrag with a string id', () async {
      Map<String, dynamic>? received;
      platform.onFeatureDraggedPlatform.add((event) => received = event);

      await sendFromNative('featureOnDrag', [
        PgFeatureDrag(
          id: 'pin',
          point: PgScreenPoint(x: 5, y: 6),
          origin: pgLatLng(1, 2),
          current: pgLatLng(3, 4),
          delta: pgLatLng(2, 2),
          eventType: 'end',
        ),
      ]);

      expect(received, {
        'id': 'pin',
        'point': const Point<double>(5, 6),
        'origin': const LatLng(1, 2),
        'current': const LatLng(3, 4),
        'delta': const LatLng(2, 2),
        'eventType': 'end',
      });
    });

    test('cameraOnIdle without a position', () async {
      final received = <CameraPosition?>[];
      platform.onCameraIdlePlatform.add(received.add);

      await sendFromNative('cameraOnIdle', [null]);

      expect(received, [null]);
    });

    test('mapOnUserLocationUpdated without a heading', () async {
      UserLocation? received;
      platform.onUserLocationUpdatedPlatform.add(
        (location) => received = location,
      );

      await sendFromNative('mapOnUserLocationUpdated', [
        PgUserLocation(
          position: pgLatLng(45, 9),
          verticalAccuracy: 2,
          timestamp: 3000,
        ),
        null,
      ]);

      expect(received!.position, const LatLng(45, 9));
      expect(received!.verticalAccuracy, 2.0);
      expect(received!.heading, isNull);
      expect(received!.timestamp, DateTime.fromMillisecondsSinceEpoch(3000));
    });
  });

  group('map options and location', () {
    setUp(init);

    test('updateMapOptions sends the update and reads the camera', () async {
      api.replies['mapUpdate'] = <Object?, Object?>{
        'bearing': 1.0,
        'target': <Object?>[10.0, 20.0],
        'tilt': 2.0,
        'zoom': 3.0,
      };

      final position = await platform.updateMapOptions({
        'compassEnabled': false,
      });

      expect(
        position,
        const CameraPosition(
          bearing: 1,
          target: LatLng(10, 20),
          tilt: 2,
          zoom: 3,
        ),
      );
      expect(api.calls, [
        [
          'mapUpdate',
          {'compassEnabled': false},
        ],
      ]);
    });

    test('updateMapOptions is null when native sends no camera', () async {
      expect(await platform.updateMapOptions(const {}), isNull);
    });

    test('updateMyLocationTrackingMode sends the index', () async {
      await platform.updateMyLocationTrackingMode(
        MyLocationTrackingMode.trackingCompass,
      );

      expect(api.calls, [
        ['mapUpdateMyLocationTrackingMode', 2],
      ]);
    });

    test('setTrackingCameraOptions sends the tilt and duration', () async {
      api.replies['locationComponentSetTrackingCameraOptions'] = true;

      final applied = await platform.setTrackingCameraOptions(
        tilt: 45,
        duration: const Duration(milliseconds: 250),
      );

      expect(applied, isTrue);
      expect(api.calls, [
        ['locationComponentSetTrackingCameraOptions', 45.0, 250],
      ]);
    });

    test('setTrackingCameraOptions reads a null answer as false', () async {
      final applied = await platform.setTrackingCameraOptions(tilt: 0);

      expect(applied, isFalse);
      expect(api.calls, [
        ['locationComponentSetTrackingCameraOptions', 0.0, null],
      ]);
    });

    test('setManualLocation sends the update map', () async {
      await platform.setManualLocation(
        ManualLocationUpdate(
          target: const LatLng(1, 2),
          horizontalAccuracy: 5,
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );

      expect(api.calls, [
        [
          'locationComponentSetManualLocation',
          {
            'position': [1.0, 2.0],
            'timestamp': 1000,
            'horizontalAccuracy': 5.0,
          },
        ],
      ]);
    });

    test('calls without an answer send their arguments', () async {
      await platform.matchMapLanguageWithDeviceDefault();
      await platform.setMapLanguage('it');
      await platform.setTelemetryEnabled(false);
      await platform.setMaximumFps(30);
      await platform.forceOnlineMode();
      await platform.pauseMap();
      await platform.resumeMap();
      await platform.invalidateAmbientCache();
      await platform.clearAmbientCache();
      await platform.setStyle('https://example.com/style.json');

      expect(api.calls, [
        ['mapMatchMapLanguageWithDeviceDefault'],
        ['mapSetMapLanguage', 'it'],
        ['mapSetTelemetryEnabled', false],
        ['mapSetMaximumFps', 30],
        ['mapForceOnlineMode'],
        ['mapPause'],
        ['mapResume'],
        ['mapInvalidateAmbientCache'],
        ['mapClearAmbientCache'],
        ['styleSetStyle', 'https://example.com/style.json'],
      ]);
    });

    test('getTelemetryEnabled returns the answer', () async {
      api.replies['mapGetTelemetryEnabled'] = true;

      expect(await platform.getTelemetryEnabled(), isTrue);
      expect(api.calls, [
        ['mapGetTelemetryEnabled'],
      ]);
    });

    test('updateContentInsets sends the four sides', () async {
      await platform.updateContentInsets(
        const EdgeInsets.fromLTRB(1, 2, 3, 4),
        true,
      );

      expect(api.calls, [
        [
          'mapUpdateContentInsets',
          {'top': 2.0, 'left': 1.0, 'bottom': 4.0, 'right': 3.0},
          true,
        ],
      ]);
    });

    test('setCameraBounds sends the bounds and the padding', () async {
      await platform.setCameraBounds(
        west: -10,
        north: 50,
        south: 40,
        east: 10,
        padding: 8,
      );

      expect(api.calls, [
        ['mapSetCameraBounds', -10.0, 50.0, 40.0, 10.0, 8],
      ]);
    });

    test('setCustomHeaders sends the headers and the filter', () async {
      await platform.setCustomHeaders({'X-Key': 'v'}, ['example.com']);

      expect(api.calls, [
        [
          'mapSetCustomHeaders',
          {'X-Key': 'v'},
          ['example.com'],
        ],
      ]);
    });

    test('getCustomHeaders turns keys and values into strings', () async {
      api.replies['mapGetCustomHeaders'] = <Object?, Object?>{
        'X-Key': 'v',
        'X-Count': 2,
      };

      expect(await platform.getCustomHeaders(), {
        'X-Key': 'v',
        'X-Count': '2',
      });
      expect(api.calls, [
        ['mapGetCustomHeaders'],
      ]);
    });

    test('getCustomHeaders is empty for a null answer', () async {
      expect(await platform.getCustomHeaders(), isEmpty);
    });

    test('requestMyLocationLatLng reads the coordinates', () async {
      api.replies['locationComponentGetLastLocation'] = <Object?, Object?>{
        'latitude': 45.5,
        // An int, as a JSON round trip may give.
        'longitude': 9,
      };

      expect(await platform.requestMyLocationLatLng(), const LatLng(45.5, 9));
      expect(api.calls, [
        ['locationComponentGetLastLocation'],
      ]);
    });

    test('requestMyLocationLatLng is null without a location', () async {
      expect(await platform.requestMyLocationLatLng(), isNull);
    });

    test('requestMyLocationLatLng reads a missing coordinate as 0', () async {
      api.replies['locationComponentGetLastLocation'] = <Object?, Object?>{
        'latitude': null,
        'longitude': 9.5,
      };

      expect(await platform.requestMyLocationLatLng(), const LatLng(0, 9.5));
    });
  });

  group('style', () {
    setUp(init);

    test('getStyle returns the JSON when native has it', () async {
      api.replies['mapGetStyle'] = <Object?, Object?>{
        'result': true,
        'json': '{"version":8}',
      };

      expect(await platform.getStyle(), '{"version":8}');
      expect(api.calls, [
        ['mapGetStyle'],
      ]);
    });

    test('getStyle is null when native has no style', () async {
      api.replies['mapGetStyle'] = <Object?, Object?>{'result': false};
      expect(await platform.getStyle(), isNull);

      api.replies['mapGetStyle'] = <Object?, Object?>{};
      expect(await platform.getStyle(), isNull);
    });

    test('the edit calls send their arguments and read the result', () async {
      api.replies['mapEditGeoJsonSource'] = <Object?, Object?>{'result': true};
      api.replies['mapEditGeoJsonUrl'] = <Object?, Object?>{'result': false};
      api.replies['mapSetLayerFilter'] = <Object?, Object?>{'result': true};

      expect(await platform.editGeoJsonSource('source', '{}'), isTrue);
      expect(
        await platform.editGeoJsonUrl('source', 'https://example.com/a.json'),
        isFalse,
      );
      // The deprecated controller method still reaches it.
      // ignore: deprecated_member_use
      expect(await platform.setLayerFilter('layer', '["has","a"]'), isTrue);
      expect(api.calls, [
        ['mapEditGeoJsonSource', 'source', '{}'],
        ['mapEditGeoJsonUrl', 'source', 'https://example.com/a.json'],
        ['mapSetLayerFilter', 'layer', '["has","a"]'],
      ]);
    });

    // As it did when the method channel reply was assigned to a map.
    test('a call that always answers a map fails on a null answer', () {
      expect(
        platform.editGeoJsonSource('source', '{}'),
        throwsA(isA<TypeError>()),
      );
    });

    test('addSource sends the properties', () async {
      const properties = VectorSourceProperties(
        url: 'https://example.com/tiles.json',
      );

      await platform.addSource('vector', properties);

      expect(api.calls, [
        ['styleAddSource', 'vector', properties.toJson()],
      ]);
      expect((api.calls.single[2]! as Map)['type'], 'vector');
    });

    test('addSource accepts the built-in raster-dem encodings', () async {
      await platform.addSource(
        'dem',
        const RasterDemSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          encoding: 'terrarium',
        ),
      );

      expect(api.calls.single.take(2), ['styleAddSource', 'dem']);
    });

    test('removeSource sends the id', () async {
      await platform.removeSource('source');

      expect(api.calls, [
        ['styleRemoveSource', 'source'],
      ]);
    });

    test('setLight sends the light', () async {
      await platform.setLight(
        const LightProperties(anchor: 'map', intensity: 0.4),
      );

      expect(api.calls, [
        [
          'styleSetLight',
          {'anchor': 'map', 'intensity': 0.4},
        ],
      ]);
    });

    test('getSourceIds reads the sources as strings', () async {
      api.replies['styleGetSourceIds'] = <Object?, Object?>{
        'sources': <Object?>['water', 7],
      };

      expect(await platform.getSourceIds(), ['water', '7']);
      expect(api.calls, [
        ['styleGetSourceIds'],
      ]);
    });

    test('getSourceProperties decodes and shapes the source', () async {
      api.replies['styleGetSourceProperties'] = <Object?, Object?>{
        'properties':
            '{"type":"vector","maxzoom":14.0,"bounds":[-180.0,-85.5,180.0,85.5]}',
      };

      final properties = await platform.getSourceProperties('vector');

      expect(properties, {
        'type': 'vector',
        'maxzoom': 14,
        'bounds': [-180, -85.5, 180, 85.5],
      });
      expect(properties!['maxzoom'], isA<int>());
      expect(api.calls, [
        ['styleGetSourceProperties', 'vector'],
      ]);
    });

    test('getSourceProperties is null for a missing source', () async {
      api.replies['styleGetSourceProperties'] = <Object?, Object?>{};

      expect(await platform.getSourceProperties('none'), isNull);
    });
  });

  group('images', () {
    setUp(init);

    const quad = LatLngQuad(
      topLeft: LatLng(4, 1),
      topRight: LatLng(4, 2),
      bottomRight: LatLng(3, 2),
      bottomLeft: LatLng(3, 1),
    );
    final quadList = [
      [4.0, 1.0],
      [4.0, 2.0],
      [3.0, 2.0],
      [3.0, 1.0],
    ];

    test('addImage sends the bytes, their length and sdf', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      await platform.addImage('pin', bytes);
      await platform.addImage('glyph', bytes, true);

      expect(api.calls, [
        ['styleAddImage', 'pin', bytes, 3, false],
        ['styleAddImage', 'glyph', bytes, 3, true],
      ]);
    });

    test('addImageSource sends the coordinates as lists', () async {
      final bytes = Uint8List.fromList([1, 2]);

      await platform.addImageSource('image', bytes, quad);

      expect(api.calls, [
        ['styleAddImageSource', 'image', bytes, 2, quadList],
      ]);
    });

    test('updateImageSource sends what is set and null otherwise', () async {
      final bytes = Uint8List.fromList([9]);

      await platform.updateImageSource('image', bytes, quad);
      await platform.updateImageSource('image', null, null);

      expect(api.calls, [
        ['styleUpdateImageSource', 'image', bytes, 1, quadList],
        ['styleUpdateImageSource', 'image', null, null, null],
      ]);
    });

    test('addLayer and addLayerBelow send the zoom range', () async {
      await platform.addLayer('image-layer', 'image', 1, 10);
      await platform.addLayer('image-layer', 'image', null, null);
      await platform.addLayerBelow('image-layer', 'image', 'labels', 2, null);

      expect(api.calls, [
        ['styleAddLayer', 'image-layer', 'image', 1.0, 10.0],
        ['styleAddLayer', 'image-layer', 'image', null, null],
        ['styleAddLayerBelow', 'image-layer', 'image', 'labels', 2.0, null],
      ]);
    });
  });

  group('layer calls', () {
    setUp(init);

    const properties = <String, dynamic>{'fill-opacity': 0.5};

    test('the filtered layer adds send every argument', () async {
      const filter = ['has', 'name'];

      await platform.addCircleLayer(
        'source',
        'circles',
        properties,
        belowLayerId: 'labels',
        sourceLayer: 'poi',
        minzoom: 1,
        maxzoom: 2,
        filter: filter,
        enableInteraction: true,
      );
      await platform.addFillLayer(
        'source',
        'fills',
        properties,
        filter: filter,
        enableInteraction: false,
      );
      await platform.addFillExtrusionLayer(
        'source',
        'extrusions',
        properties,
        sourceLayer: 'building',
        enableInteraction: true,
      );

      expect(api.calls, [
        [
          'circleLayerAdd',
          'source',
          'circles',
          'labels',
          'poi',
          1.0,
          2.0,
          '["has","name"]',
          true,
          properties,
        ],
        [
          'fillLayerAdd',
          'source',
          'fills',
          null,
          null,
          null,
          null,
          '["has","name"]',
          false,
          properties,
        ],
        [
          'fillExtrusionLayerAdd',
          'source',
          'extrusions',
          null,
          'building',
          null,
          null,
          'null',
          true,
          properties,
        ],
      ]);
    });

    test(
      'the raster, hillshade and color relief adds send no filter',
      () async {
        await platform.addRasterLayer(
          'raster',
          'raster-layer',
          properties,
          belowLayerId: 'labels',
          sourceLayer: 'ignored',
          minzoom: 3,
          maxzoom: 4,
        );
        await platform.addHillshadeLayer('dem', 'hillshade', properties);
        await platform.addColorReliefLayer(
          'dem',
          'relief',
          properties,
          belowLayerId: 'water',
          minzoom: 5,
        );

        expect(api.calls, [
          [
            'rasterLayerAdd',
            'raster',
            'raster-layer',
            'labels',
            3.0,
            4.0,
            properties,
          ],
          [
            'hillshadeLayerAdd',
            'dem',
            'hillshade',
            null,
            null,
            null,
            properties,
          ],
          [
            'colorReliefLayerAdd',
            'dem',
            'relief',
            'water',
            5.0,
            null,
            properties,
          ],
        ]);
      },
    );

    test('addBackgroundLayer sends no source', () async {
      await platform.addBackgroundLayer(
        'background',
        properties,
        belowLayerId: 'water',
        maxzoom: 9,
      );

      expect(api.calls, [
        ['backgroundLayerAdd', 'background', 'water', null, 9.0, properties],
      ]);
    });

    test('removeLayer, setLayerProperties and the visibility calls', () async {
      api.replies['layerGetVisibility'] = true;

      await platform.removeLayer('a');
      await platform.setLayerProperties('a', properties);
      await platform.setLayerVisibility('a', false);
      await platform.setLayerZoomRange('a', 2, 12);
      final visible = await platform.getLayerVisibility('a');

      expect(visible, isTrue);
      expect(api.calls, [
        ['styleRemoveLayer', 'a'],
        ['layerSetProperties', 'a', properties],
        ['layerSetVisibility', 'a', false],
        ['layerSetZoomRange', 'a', 2.0, 12.0],
        ['layerGetVisibility', 'a'],
      ]);
    });

    test('getLayerVisibility is null for a missing layer', () async {
      expect(await platform.getLayerVisibility('none'), isNull);
    });

    test('setLayersVisibility reads a null answer as none missing', () async {
      expect(await platform.setLayersVisibility(['a'], true), isEmpty);
    });

    test('setFilter encodes the filter and getFilter decodes it', () async {
      api.replies['styleGetFilter'] = <Object?, Object?>{
        'filter': '["==",["get","kind"],"cafe"]',
      };

      await platform.setFilter('a', [
        '==',
        ['get', 'kind'],
        'cafe',
      ]);
      final filter = await platform.getFilter('a');

      expect(filter, [
        '==',
        ['get', 'kind'],
        'cafe',
      ]);
      expect(api.calls, [
        ['styleSetFilter', 'a', '["==",["get","kind"],"cafe"]'],
        ['styleGetFilter', 'a'],
      ]);
    });

    test('getFilter is null for a layer without a filter', () async {
      api.replies['styleGetFilter'] = <Object?, Object?>{'filter': null};

      expect(await platform.getFilter('a'), isNull);
    });
  });

  group('GeoJSON size check', () {
    setUp(init);

    Map<String, dynamic> lineString(int points) => {
      'type': 'LineString',
      'coordinates': List.generate(points, (i) => [i * 0.001, 0.0]),
    };

    Map<String, dynamic> feature(Object? geometry) => {
      'type': 'Feature',
      'properties': <String, dynamic>{},
      'geometry': geometry,
    };

    // Each one reaches native intact, whether the payload is encoded on the
    // main isolate or on another one.
    for (final (name, geometry) in [
      (
        'a large GeometryCollection',
        {
          'type': 'GeometryCollection',
          'geometries': [lineString(1500), lineString(1500)],
        },
      ),
      (
        'a small GeometryCollection',
        {
          'type': 'GeometryCollection',
          'geometries': [lineString(2), 'not a geometry'],
        },
      ),
      (
        'a GeometryCollection without a geometries list',
        {'type': 'GeometryCollection', 'geometries': 'none'},
      ),
      ('a feature without a geometry', null),
    ]) {
      test('setFeatureForGeoJsonSource sends $name', () async {
        final payload = feature(geometry);

        await platform.setFeatureForGeoJsonSource('source', payload);

        expect(api.calls, [
          ['sourceSetFeature', 'source', jsonEncode(payload)],
        ]);
      });
    }
  });

  group('conversions, clusters and feature state', () {
    setUp(init);

    test('querySourceFeatures sends the filter and decodes', () async {
      api.replies['mapQuerySourceFeatures'] = <Object?, Object?>{
        'features': <Object?>['{"id":"a","properties":{"n":[1,2]}}'],
      };

      final features = await platform.querySourceFeatures('source', 'layer', [
        'has',
        'n',
      ]);

      expect(features, [
        {
          'id': 'a',
          'properties': {
            'n': [1, 2],
          },
        },
      ]);
      expect(api.calls, [
        [
          'mapQuerySourceFeatures',
          'source',
          'layer',
          ['has', 'n'],
        ],
      ]);
    });

    test('querySourceFeatures sends null for what is unset', () async {
      api.replies['mapQuerySourceFeatures'] = <Object?, Object?>{
        'features': <Object?>[],
      };

      expect(await platform.querySourceFeatures('source', null, null), isEmpty);
      expect(api.calls, [
        ['mapQuerySourceFeatures', 'source', null, null],
      ]);
    });

    test('getClusterExpansionZoom returns the zoom', () async {
      api.replies['sourceGetClusterExpansionZoom'] = 9;

      expect(await platform.getClusterExpansionZoom('points', 12), 9);
      expect(api.calls, [
        ['sourceGetClusterExpansionZoom', 'points', 12],
      ]);
    });

    test('getClusterChildren decodes the features', () async {
      api.replies['sourceGetClusterChildren'] = <Object?, Object?>{
        'features': <Object?>['{"id":1,"properties":{"cluster":true}}'],
      };

      final children = await platform.getClusterChildren('points', 12);

      expect(children, [
        {
          'id': 1,
          'properties': {'cluster': true},
        },
      ]);
      expect(children.single, isA<Map<String, dynamic>>());
      expect(api.calls, [
        ['sourceGetClusterChildren', 'points', 12],
      ]);
    });

    test('getClusterChildren is empty for a null answer', () async {
      expect(await platform.getClusterChildren('points', 12), isEmpty);
    });

    test('getClusterLeaves pages from the start by default', () async {
      api.replies['sourceGetClusterLeaves'] = <Object?, Object?>{};

      expect(await platform.getClusterLeaves('points', 12), isEmpty);
      expect(api.calls, [
        ['sourceGetClusterLeaves', 'points', 12, 10, 0],
      ]);
    });

    test('toScreenLocation sends the coordinates and reads x and y', () async {
      api.replies['mapToScreenLocation'] = <Object?, Object?>{
        'x': 100.5,
        'y': 200.0,
      };

      final point = await platform.toScreenLocation(const LatLng(45, 9));

      expect(point, const Point(100.5, 200.0));
      expect(api.calls, [
        ['mapToScreenLocation', 45.0, 9.0],
      ]);
    });

    test('getMetersPerPixelAtLatitude reads the answer', () async {
      api.replies['mapGetMetersPerPixelAtLatitude'] = <Object?, Object?>{
        'metersperpixel': 1.25,
      };

      expect(await platform.getMetersPerPixelAtLatitude(45), 1.25);
      expect(api.calls, [
        ['mapGetMetersPerPixelAtLatitude', 45.0],
      ]);
    });

    test('feature state reaches native on Android', () async {
      await platform.setFeatureState('source', '1', {
        'hover': true,
      }, sourceLayer: 'layer');
      await platform.removeFeatureState(
        'source',
        featureId: '1',
        stateKey: 'hover',
        sourceLayer: 'layer',
      );
      await platform.removeFeatureState('source');

      expect(api.calls, [
        [
          'sourceSetFeatureState',
          'source',
          '1',
          {'hover': true},
          'layer',
        ],
        ['sourceRemoveFeatureState', 'source', '1', 'hover', 'layer'],
        ['sourceRemoveFeatureState', 'source', null, null, null],
      ]);
    });

    test('getFeatureState is null when the feature has no state', () async {
      expect(await platform.getFeatureState('source', '1'), isNull);

      api.replies['sourceGetFeatureState'] = <Object?, Object?>{'state': null};
      expect(await platform.getFeatureState('source', '1'), isNull);

      expect(api.calls, [
        ['sourceGetFeatureState', 'source', '1', null],
        ['sourceGetFeatureState', 'source', '1', null],
      ]);
    });

    test('every feature state call fails on iOS without reaching native', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      expect(
        () => platform.removeFeatureState('source', featureId: '1'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            startsWith('removeFeatureState is not available on iOS'),
          ),
        ),
      );
      expect(
        () => platform.getFeatureState('source', '1'),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            startsWith('getFeatureState is not available on iOS'),
          ),
        ),
      );
      expect(api.calls, isEmpty);
    });
  });

  group('web only', () {
    setUp(init);

    test('what MapLibre Native lacks fails without reaching native', () {
      Matcher unsupported(String method) => throwsA(
        isA<UnsupportedError>().having(
          (e) => e.message,
          'message',
          startsWith('$method is not available on Android and iOS'),
        ),
      );

      expect(platform.setSky(const SkyProperties()), unsupported('setSky'));
      expect(
        platform.setTerrain(const TerrainProperties(source: 'dem')),
        unsupported('setTerrain'),
      );
      expect(platform.setTerrain(null), unsupported('setTerrain'));
      expect(platform.setProjection('globe'), unsupported('setProjection'));
      expect(
        platform.setGlobalStateProperty('mode', 'dark'),
        unsupported('setGlobalStateProperty'),
      );
      expect(api.calls, isEmpty);
    });

    test('the web helpers are no-ops', () async {
      const size = Size(320, 240);

      expect(await platform.setWebMapToCustomSize(size), size);
      await platform.waitUntilMapIsIdleAfterMovement();
      await platform.waitUntilMapTilesAreLoaded();
      platform.forceResizeWebMap();
      platform.resizeWebMap();

      expect(api.calls, isEmpty);
    });
  });

  group('buildView', () {
    const viewType = 'plugins.flutter.io/maplibre_gl';

    tearDown(() => MapLibreMap.useHybridComposition = false);

    Map<String, dynamic> creationParams() => {
      'options': <String, dynamic>{'compassEnabled': true},
    };

    void onPlatform(TargetPlatform target) {
      debugDefaultTargetPlatformOverride = target;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    }

    test('Android builds an AndroidView by default', () {
      onPlatform(TargetPlatform.android);
      final params = creationParams();
      void onCreated(int id) {}
      final recognizers = <Factory<OneSequenceGestureRecognizer>>{
        const Factory(EagerGestureRecognizer.new),
      };

      final view = platform.buildView(params, onCreated, recognizers);

      expect(
        view,
        isA<AndroidView>()
            .having((v) => v.viewType, 'viewType', viewType)
            .having((v) => v.creationParams, 'creationParams', same(params))
            .having(
              (v) => v.onPlatformViewCreated,
              'onPlatformViewCreated',
              same(onCreated),
            )
            .having(
              (v) => v.gestureRecognizers,
              'gestureRecognizers',
              same(recognizers),
            ),
      );
      expect(params['options'], {
        'compassEnabled': true,
        'useHybridComposition': false,
      });
    });

    test('Android copes with creation params without options', () {
      onPlatform(TargetPlatform.android);
      final params = <String, dynamic>{};

      expect(platform.buildView(params, (_) {}, null), isA<AndroidView>());
      expect(params, isEmpty);
    });

    testWidgets(
      'Android with hybrid composition creates the view itself',
      variant: TargetPlatformVariant.only(TargetPlatform.android),
      (tester) async {
        MapLibreMap.useHybridComposition = true;
        final messenger = tester.binding.defaultBinaryMessenger;
        final viewCalls = <MethodCall>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          viewCalls.add(call);
          switch (call.method) {
            case 'create':
              // A texture id: the view is drawn by Flutter.
              return 0;
            case 'resize':
              final args = call.arguments as Map;
              return <String, Object?>{
                'width': args['width'],
                'height': args['height'],
              };
          }
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          ),
        );
        final params = creationParams();
        final created = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: platform.buildView(params, created.add, null),
          ),
        );
        await tester.pump();

        expect(params['options']['useHybridComposition'], isTrue);
        final create = viewCalls.singleWhere((c) => c.method == 'create');
        final args = create.arguments as Map;
        expect(args['viewType'], viewType);
        expect(
          const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(args['params'] as Uint8List),
          ),
          params,
        );
        expect(created, [args['id']]);
        expect(find.byType(AndroidViewSurface), findsOneWidget);

        // Native asks for the focus when the view is touched.
        await messenger.handlePlatformMessage(
          SystemChannels.platform_views.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('viewFocused', created.single),
          ),
          (_) {},
        );
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus?.debugLabel,
          startsWith('PlatformView'),
        );

        await tester.pumpWidget(const SizedBox());
      },
    );

    test('iOS builds a UiKitView without the Android flag', () {
      onPlatform(TargetPlatform.iOS);
      MapLibreMap.useHybridComposition = true;
      final params = creationParams();
      void onCreated(int id) {}

      final view = platform.buildView(params, onCreated, null);

      expect(
        view,
        isA<UiKitView>()
            .having((v) => v.viewType, 'viewType', viewType)
            .having((v) => v.creationParams, 'creationParams', same(params))
            .having(
              (v) => v.onPlatformViewCreated,
              'onPlatformViewCreated',
              same(onCreated),
            ),
      );
      expect(params['options'], {'compassEnabled': true});
    });

    test('other platforms get a message instead of a map', () {
      onPlatform(TargetPlatform.linux);

      final view = platform.buildView(creationParams(), (_) {}, null);

      expect(
        view,
        isA<Text>().having(
          (v) => v.data,
          'data',
          'TargetPlatform.linux is not yet supported by the maps plugin',
        ),
      );
    });
  });
}

/// Records each call as its name followed by its arguments, and answers with
/// [replies] by name, or fails with [errors] by name.
///
/// Every method of the generated client is overridden. One that was not would
/// send on a channel nothing listens to, and fail with a channel-error.
class _FakeMapHostApi extends MapLibreMapHostApi {
  _FakeMapHostApi() : super(messageChannelSuffix: 'not-overridden');

  final List<List<Object?>> calls = [];
  final Map<String, Object?> replies = {};
  final Map<String, PlatformException> errors = {};

  /// Runs while waitForMap is pending, before it answers.
  Future<void> Function()? onWaitForMap;

  Future<T> _call<T>(String method, [List<Object?> args = const []]) async {
    calls.add([method, ...args]);
    final error = errors[method];
    if (error != null) throw error;
    return replies[method] as T;
  }

  @override
  Future<void> mapWaitForMap() async {
    calls.add(['mapWaitForMap']);
    await onWaitForMap?.call();
  }

  @override
  Future<Object?> mapUpdate(Map<String, Object?> options) =>
      _call('mapUpdate', [options]);

  @override
  Future<bool?> cameraAnimate(List<Object?> cameraUpdate, int? duration) =>
      _call('cameraAnimate', [cameraUpdate, duration]);

  @override
  Future<bool?> cameraMove(List<Object?> cameraUpdate) =>
      _call('cameraMove', [cameraUpdate]);

  @override
  Future<void> mapUpdateMyLocationTrackingMode(int mode) =>
      _call('mapUpdateMyLocationTrackingMode', [mode]);

  @override
  Future<bool?> locationComponentSetTrackingCameraOptions(
    double tilt,
    int? duration,
  ) => _call('locationComponentSetTrackingCameraOptions', [tilt, duration]);

  @override
  Future<void> locationComponentSetManualLocation(
    Map<String, Object?> update,
  ) => _call('locationComponentSetManualLocation', [update]);

  @override
  Future<void> mapMatchMapLanguageWithDeviceDefault() =>
      _call('mapMatchMapLanguageWithDeviceDefault');

  @override
  Future<void> mapUpdateContentInsets(
    Map<String, double> bounds,
    bool animated,
  ) => _call('mapUpdateContentInsets', [bounds, animated]);

  @override
  Future<void> mapSetMapLanguage(String language) =>
      _call('mapSetMapLanguage', [language]);

  @override
  Future<void> mapSetTelemetryEnabled(bool enabled) =>
      _call('mapSetTelemetryEnabled', [enabled]);

  @override
  Future<bool> mapGetTelemetryEnabled() => _call('mapGetTelemetryEnabled');

  @override
  Future<void> mapSetMaximumFps(int fps) => _call('mapSetMaximumFps', [fps]);

  @override
  Future<void> mapForceOnlineMode() => _call('mapForceOnlineMode');

  @override
  Future<void> mapPause() => _call('mapPause');

  @override
  Future<void> mapResume() => _call('mapResume');

  @override
  Future<bool> cameraEase(
    List<Object?> cameraUpdate,
    int? duration,
    String? interpolation,
  ) => _call('cameraEase', [cameraUpdate, duration, interpolation]);

  @override
  Future<Object?> mapQueryCameraPosition() => _call('mapQueryCameraPosition');

  @override
  Future<Object?> mapEditGeoJsonSource(String id, String data) =>
      _call('mapEditGeoJsonSource', [id, data]);

  @override
  Future<Object?> mapEditGeoJsonUrl(String id, String url) =>
      _call('mapEditGeoJsonUrl', [id, url]);

  @override
  Future<Object?> mapSetLayerFilter(String id, String filter) =>
      _call('mapSetLayerFilter', [id, filter]);

  @override
  Future<Object?> mapGetStyle() => _call('mapGetStyle');

  @override
  Future<void> mapSetCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) => _call('mapSetCustomHeaders', [headers, filter]);

  @override
  Future<Object?> mapGetCustomHeaders() => _call('mapGetCustomHeaders');

  @override
  Future<Object?> mapQueryRenderedFeaturesAtPoint(
    double x,
    double y,
    List<String> layerIds,
    List<Object?>? filter,
  ) => _call('mapQueryRenderedFeaturesAtPoint', [x, y, layerIds, filter]);

  @override
  Future<Object?> mapQueryRenderedFeaturesInRect(
    double left,
    double top,
    double right,
    double bottom,
    List<String> layerIds,
    String? filter,
  ) => _call('mapQueryRenderedFeaturesInRect', [
    left,
    top,
    right,
    bottom,
    layerIds,
    filter,
  ]);

  @override
  Future<Object?> mapQuerySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object?>? filter,
  ) => _call('mapQuerySourceFeatures', [sourceId, sourceLayerId, filter]);

  @override
  Future<int> sourceGetClusterExpansionZoom(String sourceId, int clusterId) =>
      _call('sourceGetClusterExpansionZoom', [sourceId, clusterId]);

  @override
  Future<Object?> sourceGetClusterChildren(String sourceId, int clusterId) =>
      _call('sourceGetClusterChildren', [sourceId, clusterId]);

  @override
  Future<Object?> sourceGetClusterLeaves(
    String sourceId,
    int clusterId,
    int limit,
    int offset,
  ) => _call('sourceGetClusterLeaves', [sourceId, clusterId, limit, offset]);

  @override
  Future<void> mapInvalidateAmbientCache() =>
      _call('mapInvalidateAmbientCache');

  @override
  Future<void> mapClearAmbientCache() => _call('mapClearAmbientCache');

  @override
  Future<Object?> locationComponentGetLastLocation() =>
      _call('locationComponentGetLastLocation');

  @override
  Future<Object?> mapGetVisibleRegion() => _call('mapGetVisibleRegion');

  @override
  Future<void> styleAddImage(
    String name,
    Uint8List bytes,
    int length,
    bool sdf,
  ) => _call('styleAddImage', [name, bytes, length, sdf]);

  @override
  Future<void> styleAddImageSource(
    String imageSourceId,
    Uint8List bytes,
    int length,
    List<Object?> coordinates,
  ) => _call('styleAddImageSource', [
    imageSourceId,
    bytes,
    length,
    coordinates,
  ]);

  @override
  Future<void> styleUpdateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    int? length,
    List<Object?>? coordinates,
  ) => _call('styleUpdateImageSource', [
    imageSourceId,
    bytes,
    length,
    coordinates,
  ]);

  @override
  Future<Object?> mapToScreenLocation(double latitude, double longitude) =>
      _call('mapToScreenLocation', [latitude, longitude]);

  @override
  Future<Float64List> mapToScreenLocationBatch(Float64List coordinates) =>
      _call('mapToScreenLocationBatch', [coordinates]);

  @override
  Future<void> styleRemoveSource(String sourceId) =>
      _call('styleRemoveSource', [sourceId]);

  @override
  Future<void> styleAddLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) => _call('styleAddLayer', [imageLayerId, imageSourceId, minzoom, maxzoom]);

  @override
  Future<void> styleAddLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) => _call('styleAddLayerBelow', [
    imageLayerId,
    imageSourceId,
    belowLayerId,
    minzoom,
    maxzoom,
  ]);

  @override
  Future<void> styleRemoveLayer(String layerId) =>
      _call('styleRemoveLayer', [layerId]);

  @override
  Future<void> styleMoveLayer(String layerId, String? belowLayerId) =>
      _call('styleMoveLayer', [layerId, belowLayerId]);

  @override
  Future<void> styleSetFilter(String layerId, String filter) =>
      _call('styleSetFilter', [layerId, filter]);

  @override
  Future<Object?> styleGetFilter(String layerId) =>
      _call('styleGetFilter', [layerId]);

  @override
  Future<Object?> mapToLatLng(double x, double y) =>
      _call('mapToLatLng', [x, y]);

  @override
  Future<Object?> mapGetMetersPerPixelAtLatitude(double latitude) =>
      _call('mapGetMetersPerPixelAtLatitude', [latitude]);

  @override
  Future<void> sourceAddGeoJson(String sourceId, String geojson) =>
      _call('sourceAddGeoJson', [sourceId, geojson]);

  @override
  Future<void> sourceSetGeoJson(String sourceId, String geojson) =>
      _call('sourceSetGeoJson', [sourceId, geojson]);

  @override
  Future<void> mapSetCameraBounds(
    double west,
    double north,
    double south,
    double east,
    int padding,
  ) => _call('mapSetCameraBounds', [west, north, south, east, padding]);

  @override
  Future<void> symbolLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  ) => _call('symbolLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    enableInteraction,
    properties,
  ]);

  @override
  Future<void> lineLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  ) => _call('lineLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    enableInteraction,
    properties,
  ]);

  @override
  Future<void> layerSetProperties(
    String layerId,
    Map<String, Object?> properties,
  ) => _call('layerSetProperties', [layerId, properties]);

  @override
  Future<void> circleLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  ) => _call('circleLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    enableInteraction,
    properties,
  ]);

  @override
  Future<void> fillLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  ) => _call('fillLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    enableInteraction,
    properties,
  ]);

  @override
  Future<void> fillExtrusionLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  ) => _call('fillExtrusionLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    enableInteraction,
    properties,
  ]);

  @override
  Future<void> styleAddSource(
    String sourceId,
    Map<String, Object?> properties,
  ) => _call('styleAddSource', [sourceId, properties]);

  @override
  Future<void> rasterLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  ) => _call('rasterLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    minzoom,
    maxzoom,
    properties,
  ]);

  @override
  Future<void> hillshadeLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  ) => _call('hillshadeLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    minzoom,
    maxzoom,
    properties,
  ]);

  @override
  Future<void> colorReliefLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  ) => _call('colorReliefLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    minzoom,
    maxzoom,
    properties,
  ]);

  @override
  Future<void> backgroundLayerAdd(
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  ) => _call('backgroundLayerAdd', [
    layerId,
    belowLayerId,
    minzoom,
    maxzoom,
    properties,
  ]);

  @override
  Future<void> heatmapLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    Map<String, Object?> properties,
  ) => _call('heatmapLayerAdd', [
    sourceId,
    layerId,
    belowLayerId,
    sourceLayer,
    minzoom,
    maxzoom,
    filter,
    properties,
  ]);

  @override
  Future<void> sourceSetFeature(String sourceId, String geojsonFeature) =>
      _call('sourceSetFeature', [sourceId, geojsonFeature]);

  @override
  Future<void> sourceSetFeatureState(
    String sourceId,
    String featureId,
    Map<String, Object?> state,
    String? sourceLayer,
  ) =>
      _call('sourceSetFeatureState', [sourceId, featureId, state, sourceLayer]);

  @override
  Future<void> sourceRemoveFeatureState(
    String sourceId,
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  ) => _call('sourceRemoveFeatureState', [
    sourceId,
    featureId,
    stateKey,
    sourceLayer,
  ]);

  @override
  Future<Object?> sourceGetFeatureState(
    String sourceId,
    String featureId,
    String? sourceLayer,
  ) => _call('sourceGetFeatureState', [sourceId, featureId, sourceLayer]);

  @override
  Future<void> styleSetLight(Map<String, Object?> light) =>
      _call('styleSetLight', [light]);

  @override
  Future<void> layerSetVisibility(String layerId, bool visible) =>
      _call('layerSetVisibility', [layerId, visible]);

  @override
  Future<List<String>?> layerSetVisibilityBatch(
    List<String> layerIds,
    bool visible,
  ) => _call('layerSetVisibilityBatch', [layerIds, visible]);

  @override
  Future<void> layerSetZoomRange(
    String layerId,
    double minzoom,
    double maxzoom,
  ) => _call('layerSetZoomRange', [layerId, minzoom, maxzoom]);

  @override
  Future<bool?> layerGetVisibility(String layerId) =>
      _call('layerGetVisibility', [layerId]);

  @override
  Future<Uint8List?> mapTakeSnapshot(int? width, int? height) =>
      _call('mapTakeSnapshot', [width, height]);

  @override
  Future<Object?> styleGetLayerIds() => _call('styleGetLayerIds');

  @override
  Future<Object?> styleGetSourceIds() => _call('styleGetSourceIds');

  @override
  Future<Object?> styleGetLayerProperties(String layerId) =>
      _call('styleGetLayerProperties', [layerId]);

  @override
  Future<Object?> styleGetSourceProperties(String sourceId) =>
      _call('styleGetSourceProperties', [sourceId]);

  @override
  Future<void> styleSetStyle(String style) => _call('styleSetStyle', [style]);
}

/// A platform a package built on the deprecated method channel platform and
/// installed through [MapLibrePlatform.createInstance]. It shows its own view,
/// so the test can tell that the map used it.
// ignore: deprecated_member_use
class _AppMethodChannel extends MapLibreMethodChannel {
  static const viewKey = Key('app platform view');

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) => const SizedBox(key: viewKey);
}
