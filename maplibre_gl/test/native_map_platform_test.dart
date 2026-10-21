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

    test('cameraOnMoveStarted', () async {
      var calls = 0;
      platform.onCameraMoveStartedPlatform.add((_) => calls++);

      await events().cameraOnMoveStarted();

      expect(calls, 1);
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
}

/// Records each call as its name followed by its arguments, and answers with
/// [replies] by name, or fails with [errors] by name.
class _FakeMapHostApi extends MapLibreMapHostApi {
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
  Future<bool?> cameraAnimate(List<Object?> cameraUpdate, int? duration) =>
      _call('cameraAnimate', [cameraUpdate, duration]);

  @override
  Future<bool?> cameraMove(List<Object?> cameraUpdate) =>
      _call('cameraMove', [cameraUpdate]);

  @override
  Future<bool> cameraEase(
    List<Object?> cameraUpdate,
    int? duration,
    String? interpolation,
  ) => _call('cameraEase', [cameraUpdate, duration, interpolation]);

  @override
  Future<Object?> mapQueryCameraPosition() => _call('mapQueryCameraPosition');

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
  Future<void> styleMoveLayer(String layerId, String? belowLayerId) =>
      _call('styleMoveLayer', [layerId, belowLayerId]);

  @override
  Future<List<String>?> layerSetVisibilityBatch(
    List<String> layerIds,
    bool visible,
  ) => _call('layerSetVisibilityBatch', [layerIds, visible]);

  @override
  Future<Object?> styleGetLayerIds() => _call('styleGetLayerIds');

  @override
  Future<Object?> styleGetLayerProperties(String layerId) =>
      _call('styleGetLayerProperties', [layerId]);

  @override
  Future<void> sourceAddGeoJson(String sourceId, String geojson) =>
      _call('sourceAddGeoJson', [sourceId, geojson]);

  @override
  Future<void> sourceSetGeoJson(String sourceId, String geojson) =>
      _call('sourceSetGeoJson', [sourceId, geojson]);

  @override
  Future<void> sourceSetFeature(String sourceId, String geojsonFeature) =>
      _call('sourceSetFeature', [sourceId, geojsonFeature]);

  @override
  Future<void> styleAddSource(
    String sourceId,
    Map<String, Object?> properties,
  ) => _call('styleAddSource', [sourceId, properties]);

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
  Future<Object?> sourceGetClusterLeaves(
    String sourceId,
    int clusterId,
    int limit,
    int offset,
  ) => _call('sourceGetClusterLeaves', [sourceId, clusterId, limit, offset]);

  @override
  Future<Object?> mapGetVisibleRegion() => _call('mapGetVisibleRegion');

  @override
  Future<Float64List> mapToScreenLocationBatch(Float64List coordinates) =>
      _call('mapToScreenLocationBatch', [coordinates]);

  @override
  Future<Object?> mapToLatLng(double x, double y) =>
      _call('mapToLatLng', [x, y]);

  @override
  Future<Object?> locationComponentGetLastLocation() =>
      _call('locationComponentGetLastLocation');

  @override
  Future<void> sourceSetFeatureState(
    String sourceId,
    String featureId,
    Map<String, Object?> state,
    String? sourceLayer,
  ) =>
      _call('sourceSetFeatureState', [sourceId, featureId, state, sourceLayer]);

  @override
  Future<Object?> sourceGetFeatureState(
    String sourceId,
    String featureId,
    String? sourceLayer,
  ) => _call('sourceGetFeatureState', [sourceId, featureId, sourceLayer]);

  @override
  Future<Uint8List?> mapTakeSnapshot(int? width, int? height) =>
      _call('mapTakeSnapshot', [width, height]);
}
