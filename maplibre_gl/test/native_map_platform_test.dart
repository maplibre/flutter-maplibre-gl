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
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show geoJsonError;

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
    });

    testWidgets(
      'a map installs the Pigeon platform when the registrant did not run',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        // The default factory, as in an isolate where the registrant of the
        // app never ran.
        MapLibrePlatform.createInstance = previousFactory;
        expect(MapLibrePlatform.isRegistered, isFalse);
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
      'a map keeps a platform a package installed',
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      (tester) async {
        MapLibrePlatform appFactory() => _AppPlatform();
        MapLibrePlatform.createInstance = appFactory;

        await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

        expect(find.byKey(_AppPlatform.viewKey), findsOneWidget);
        expect(MapLibrePlatform.createInstance, same(appFactory));
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'a map says the platform is not supported where nothing registered',
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
      (tester) async {
        MapLibrePlatform.createInstance = previousFactory;

        await tester.pumpWidget(MaterialApp(home: MapLibreMap()));

        expect(find.textContaining('is not yet supported'), findsOneWidget);
        expect(MapLibrePlatform.isRegistered, isFalse);
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

  group('once native removed the handlers of the map', () {
    // The generated client this time, over the platform's own messenger, with
    // native played by mock handlers on the channels of the map.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = MapLibreMapHostApi.pigeonChannelCodec;
    String channel(String method, [int id = viewId]) =>
        'dev.flutter.pigeon.maplibre_gl.MapLibreMapHostApi.$method.$id';

    /// Plays native for [method] of the map [id], answering with [reply].
    /// A null [reply] is what a channel without a handler answers.
    void answer(String method, List<Object?>? reply, [int id = viewId]) {
      messenger.setMockMessageHandler(
        channel(method, id),
        (_) async => reply == null ? null : codec.encodeMessage(reply),
      );
      addTearDown(
        () => messenger.setMockMessageHandler(channel(method, id), null),
      );
    }

    final mapDisposed = isA<PlatformException>()
        .having((e) => e.code, 'code', 'MAP_DISPOSED')
        .having(
          (e) => e.message,
          'message',
          'The map was disposed before the call reached it.',
        );

    late MapLibrePlatform map;

    setUp(() async {
      MapLibreNativePlugin.registerWith();
      map = MapLibrePlatform.createInstance();
      addTearDown(map.dispose);
      answer('mapWaitForMap', [null]);
      await map.initPlatform(viewId);
    });

    test('a call fails with MAP_DISPOSED', () async {
      answer('styleGetLayerIds', null);

      await expectLater(map.getLayerIds(), throwsA(mapDisposed));
    });

    test(
      'waiting for a map that is already gone fails with MAP_DISPOSED',
      () async {
        final gone = MapLibrePlatform.createInstance();
        addTearDown(gone.dispose);
        answer('mapWaitForMap', null, viewId + 1);

        await expectLater(gone.initPlatform(viewId + 1), throwsA(mapDisposed));
      },
    );

    test('answers and errors of native pass through', () async {
      answer('styleGetLayerIds', [
        <Object?>['road'],
      ]);
      expect(await map.getLayerIds(), ['road']);

      answer('styleGetLayerIds', ['STYLE_NOT_READY', 'No style yet', null]);
      await expectLater(
        map.getLayerIds(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'STYLE_NOT_READY',
          ),
        ),
      );
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
        ['cameraAnimate', PgCameraUpdateZoomTo(zoom: 5), 300],
      ]);
    });

    test('animateCamera sends a null duration when unset', () async {
      await platform.animateCamera(CameraUpdate.zoomIn());

      expect(api.calls, [
        ['cameraAnimate', PgCameraUpdateZoomIn(), null],
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
          PgCameraUpdateNewLatLng(latLng: PgLatLng(latitude: 1, longitude: 2)),
        ],
      ]);
    });

    test('easeCamera sends the interpolation', () async {
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
          PgCameraUpdateBearingTo(bearing: 90),
          200,
          PgCameraAnimationInterpolation.fastOutLinearIn,
        ],
      ]);
    });

    test('easeCamera sends null for what is unset', () async {
      api.replies['cameraEase'] = false;

      await platform.easeCamera(CameraUpdate.zoomOut());

      expect(api.calls, [
        ['cameraEase', PgCameraUpdateZoomOut(), null, null],
      ]);
    });

    // Native receives the interpolation by index, so each value has to land on
    // the one with the same name.
    test('easeCamera sends each interpolation as itself', () async {
      api.replies['cameraEase'] = true;
      for (final interpolation in CameraAnimationInterpolation.values) {
        await platform.easeCamera(
          CameraUpdate.zoomIn(),
          interpolation: interpolation,
        );
      }

      expect(
        [for (final call in api.calls) (call[3]! as Enum).name],
        [for (final value in CameraAnimationInterpolation.values) value.name],
      );
    });

    test('every kind of update reaches native as its own class', () async {
      PgLatLng latLng(double latitude, double longitude) =>
          PgLatLng(latitude: latitude, longitude: longitude);
      final updates = <(CameraUpdate, PgCameraUpdate)>[
        (
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              bearing: 10,
              target: LatLng(45, 9),
              tilt: 20,
              zoom: 11,
            ),
          ),
          PgCameraUpdateNewCameraPosition(
            cameraPosition: PgCameraPosition(
              bearing: 10,
              target: latLng(45, 9),
              tilt: 20,
              zoom: 11,
            ),
          ),
        ),
        (
          CameraUpdate.newLatLng(const LatLng(1, 2)),
          PgCameraUpdateNewLatLng(latLng: latLng(1, 2)),
        ),
        (
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: const LatLng(1, 2),
              northeast: const LatLng(3, 4),
            ),
            left: 5,
            top: 6,
            right: 7,
            bottom: 8,
          ),
          PgCameraUpdateNewLatLngBounds(
            bounds: PgLatLngBounds(
              southwest: latLng(1, 2),
              northeast: latLng(3, 4),
            ),
            padding: PgEdgeInsets(top: 6, left: 5, bottom: 8, right: 7),
          ),
        ),
        (
          CameraUpdate.newLatLngZoom(const LatLng(1, 2), 3),
          PgCameraUpdateNewLatLngZoom(latLng: latLng(1, 2), zoom: 3),
        ),
        (CameraUpdate.scrollBy(4, -5), PgCameraUpdateScrollBy(dx: 4, dy: -5)),
        (CameraUpdate.zoomBy(2), PgCameraUpdateZoomBy(amount: 2)),
        (
          CameraUpdate.zoomBy(-1, const Offset(10, 20)),
          PgCameraUpdateZoomBy(
            amount: -1,
            focus: PgScreenPoint(x: 10, y: 20),
          ),
        ),
        (CameraUpdate.zoomIn(), PgCameraUpdateZoomIn()),
        (CameraUpdate.zoomOut(), PgCameraUpdateZoomOut()),
        (CameraUpdate.zoomTo(12), PgCameraUpdateZoomTo(zoom: 12)),
        (CameraUpdate.bearingTo(90), PgCameraUpdateBearingTo(bearing: 90)),
        (CameraUpdate.tiltTo(30), PgCameraUpdateTiltTo(tilt: 30)),
      ];

      for (final (update, _) in updates) {
        await platform.moveCamera(update);
      }

      expect(api.calls, [
        for (final (_, typed) in updates) ['cameraMove', typed],
      ]);
    });

    test('an update of no known kind fails without reaching native', () {
      expect(
        platform.animateCamera(_UnknownCameraUpdate()),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_ARGUMENT')
              .having(
                (e) => e.message,
                'message',
                'Cannot interpret [bogus] as CameraUpdate.',
              ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    test('queryCameraPosition reads the camera', () async {
      api.replies['mapQueryCameraPosition'] = PgCameraPosition(
        bearing: 10,
        target: PgLatLng(latitude: 45, longitude: 9.5),
        tilt: 20,
        zoom: 11,
      );

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

    test('addLineLayer sends a null filter without one', () async {
      await platform.addLineLayer(
        'source',
        'lines',
        const {},
        enableInteraction: false,
      );

      expect(api.calls.single[7], isNull);
    });

    test('addHeatmapLayer encodes the filter and the source layer', () async {
      await platform.addHeatmapLayer(
        'source',
        'heat',
        const {},
        sourceLayer: 'quakes',
        filter: ['has', 'weight'],
      );

      expect(api.calls, [
        [
          'heatmapLayerAdd',
          'source',
          'heat',
          null,
          'quakes',
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
      api.replies['styleGetLayerIds'] = <String>['water', 'roads'];

      final ids = await platform.getLayerIds();

      expect(ids, ['water', 'roads']);
      // A growable list of its own.
      ids.add('more');
    });

    test('getLayerProperties decodes and shapes the layer', () async {
      api.replies['styleGetLayerProperties'] = '{"id":"water","minzoom":4.0}';

      expect(await platform.getLayerProperties('water'), {
        'id': 'water',
        'minzoom': 4,
      });
      expect(api.calls, [
        ['styleGetLayerProperties', 'water'],
      ]);
    });

    test('getLayerProperties is null for a missing layer', () async {
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

    // Many small features take the background path by their count alone.
    test('a many-feature collection reaches native intact', () async {
      final geojson = {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < 500; i++)
            {
              'type': 'Feature',
              'properties': {'n': i},
              'geometry': {
                'type': 'Point',
                'coordinates': [i * 0.01, i * 0.02],
              },
            },
        ],
      };

      await platform.setGeoJsonSource('source', geojson);

      expect(api.calls, [
        ['sourceSetGeoJson', 'source', jsonEncode(geojson)],
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
        'geometry': null,
      });

      expect(api.calls.map((call) => call.first), [
        'sourceSetGeoJson',
        'sourceSetFeature',
      ]);
    });

    // Checked before anything reaches native, as on web.
    test('data that is not GeoJSON fails with INVALID_GEOJSON', () async {
      final notGeoJson = {
        'type': 'FeatureCollection',
        'features': [
          {'type': 'Feature', 'properties': <String, dynamic>{}},
        ],
      };
      final invalid = isA<PlatformException>()
          .having((e) => e.code, 'code', 'INVALID_GEOJSON')
          .having(
            (e) => e.message,
            'message',
            "The data for source 'source' is not GeoJSON: Feature 0: A "
                'Feature must have a "geometry" member.',
          );

      await expectLater(
        platform.addGeoJsonSource('source', notGeoJson),
        throwsA(invalid),
      );
      await expectLater(
        platform.setGeoJsonSource('source', notGeoJson),
        throwsA(invalid),
      );
      await expectLater(
        platform.addSource(
          'source',
          GeojsonSourceProperties(data: notGeoJson),
        ),
        throwsA(invalid),
      );
      await expectLater(
        platform.editGeoJsonSource('source', jsonEncode(notGeoJson)),
        throwsA(invalid),
      );
      await expectLater(
        platform.setFeatureForGeoJsonSource('source', {
          'type': 'Point',
          'coordinates': [0, 0],
        }),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_GEOJSON')
              .having(
                (e) => e.message,
                'message',
                "The feature for source 'source' is not a GeoJSON Feature: "
                    'It is a Point, not a Feature.',
              ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    test('text that is not JSON fails editGeoJsonSource', () async {
      await expectLater(
        platform.editGeoJsonSource('source', 'not json'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_GEOJSON')
              .having(
                (e) => e.message,
                'message',
                "The data for source 'source' is not GeoJSON: Not valid JSON.",
              ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    // Text longer than 100 000 characters is checked in a background isolate.
    test('editGeoJsonSource checks a large text the same way', () async {
      final features = [
        for (var i = 0; i < 2000; i++)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [i * 0.001, 0],
            },
            'properties': {'name': 'feature $i'},
          },
      ];
      final valid = jsonEncode({
        'type': 'FeatureCollection',
        'features': features,
      });
      expect(valid.length, greaterThan(100000));
      api.replies['mapEditGeoJsonSource'] = true;

      expect(await platform.editGeoJsonSource('source', valid), isTrue);
      await expectLater(
        platform.editGeoJsonSource(
          'source',
          jsonEncode({'type': 'Nope', 'features': features}),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'INVALID_GEOJSON',
          ),
        ),
      );
      expect(api.calls, hasLength(1));
    });

    // A payload above the offload thresholds is checked on the other isolate,
    // with the same answer.
    test('a large payload is checked too', () async {
      final big = line(40000);
      ((big['features'] as List).single as Map)['properties'] = 'none';

      await expectLater(
        platform.setGeoJsonSource('source', big),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_GEOJSON')
              .having(
                (e) => e.details,
                'details',
                'Feature 0: The "properties" of a Feature must be an object '
                    'or null.',
              ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    // A small edit would otherwise reach native before the large write made
    // ahead of it, and be overwritten by it.
    test('editGeoJsonSource and editGeoJsonUrl keep their place among the '
        'writes to a source', () async {
      api.replies['mapEditGeoJsonSource'] = true;
      api.replies['mapEditGeoJsonUrl'] = true;
      final big = line(40000);
      final small = jsonEncode(line(1));

      final answers = await Future.wait([
        platform.addGeoJsonSource('source', big),
        platform.editGeoJsonSource('source', small),
        platform.editGeoJsonUrl('source', 'https://example.com/a.json'),
      ]);

      expect(answers.skip(1), [true, true]);
      expect(api.calls, [
        ['sourceAddGeoJson', 'source', jsonEncode(big)],
        ['mapEditGeoJsonSource', 'source', small],
        ['mapEditGeoJsonUrl', 'source', 'https://example.com/a.json'],
      ]);
    });

    test('a large editGeoJsonSource text reaches native before a later '
        'write', () async {
      api.replies['mapEditGeoJsonSource'] = true;
      final big = jsonEncode(line(40000));
      final feature = {
        'type': 'Feature',
        'id': 1,
        'properties': <String, dynamic>{},
        'geometry': null,
      };

      await Future.wait([
        platform.editGeoJsonSource('source', big),
        platform.setFeatureForGeoJsonSource('source', feature),
      ]);

      expect(api.calls, [
        ['mapEditGeoJsonSource', 'source', big],
        ['sourceSetFeature', 'source', jsonEncode(feature)],
      ]);
    });

    test('a large addSource is checked on another isolate and keeps its '
        'place among the writes to a source', () async {
      final big = line(40000);
      final small = line(1);

      await Future.wait([
        platform.addSource('source', GeojsonSourceProperties(data: big)),
        platform.setGeoJsonSource('source', small),
      ]);

      expect(api.calls.map((call) => call.take(2)), [
        ['styleAddSource', 'source'],
        ['sourceSetGeoJson', 'source'],
      ]);
      expect((api.calls.first[2]! as Map)['data'], big);

      api.calls.clear();
      ((big['features'] as List).single as Map)['properties'] = 'none';
      await expectLater(
        platform.addSource('other', GeojsonSourceProperties(data: big)),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'INVALID_GEOJSON')
              .having(
                (e) => e.details,
                'details',
                'Feature 0: The "properties" of a Feature must be an object '
                    'or null.',
              ),
        ),
      );
      expect(api.calls, isEmpty);
    });

    // A large addSource is checked on another isolate, and a layer add made
    // right after it without await would otherwise find no source.
    test('a call on a source waits for the writes to it in flight', () async {
      api.replies['mapQuerySourceFeatures'] = <String>[];
      api.replies['sourceGetClusterExpansionZoom'] = 3;
      final big = line(40000);

      await Future.wait([
        platform.addSource('source', GeojsonSourceProperties(data: big)),
        platform.addCircleLayer(
          'source',
          'circles',
          const {},
          enableInteraction: true,
        ),
        platform.querySourceFeatures('source', null, null),
        platform.getClusterExpansionZoom('source', 1),
        platform.setFeatureState('source', '1', const {'on': true}),
        platform.getSourceProperties('source'),
        platform.removeSource('source'),
      ]);

      expect(api.calls.map((call) => call.first), [
        'styleAddSource',
        'circleLayerAdd',
        'mapQuerySourceFeatures',
        'sourceGetClusterExpansionZoom',
        'sourceSetFeatureState',
        'styleGetSourceProperties',
        'styleRemoveSource',
      ]);
    });

    // The layer add waits for the source, so the calls on the layer wait
    // for the layer add.
    test('a call on a layer waits for its add in flight', () async {
      final big = line(40000);

      await Future.wait([
        platform.addGeoJsonSource('source', big),
        platform.addCircleLayer(
          'source',
          'circles',
          const {},
          enableInteraction: true,
        ),
        platform.setLayerProperties('circles', const {'circle-radius': 4}),
        platform.addBackgroundLayer(
          'background',
          const {},
          belowLayerId: 'circles',
        ),
        platform.setGeoJsonSource('source', line(1)),
      ]);

      expect(api.calls.map((call) => call.first), [
        'sourceAddGeoJson',
        'circleLayerAdd',
        'layerSetProperties',
        'backgroundLayerAdd',
        'sourceSetGeoJson',
      ]);
    });

    test('a call with no write in flight on its source goes at once', () async {
      api.replies['mapQuerySourceFeatures'] = <String>[];
      final big = platform.addGeoJsonSource('big', line(40000));
      final add = platform.addCircleLayer(
        'other',
        'circles',
        const {},
        enableInteraction: true,
      );
      final query = platform.querySourceFeatures('other', null, null);

      expect(api.calls.map((call) => call.first), [
        'circleLayerAdd',
        'mapQuerySourceFeatures',
      ]);
      await Future.wait([big, add, query]);
      expect(api.calls.last.first, 'sourceAddGeoJson');
    });

    // jsonEncode writes app models and the position classes of GeoJSON
    // libraries through their toJson(), as it always has.
    test('objects with toJson() go in as jsonEncode writes them', () async {
      final feature = {
        'type': 'Feature',
        'id': 1,
        'geometry': const _Geometry('LineString', [
          _Position(1, 2),
          _Position(3, 4),
        ]),
        'properties': <String, dynamic>{},
      };
      final collection = {
        'type': 'FeatureCollection',
        'features': [feature],
      };

      await platform.addGeoJsonSource('source', collection);
      await platform.setGeoJsonSource('source', collection);
      await platform.setFeatureForGeoJsonSource('source', feature);
      await platform.addSource(
        'other',
        GeojsonSourceProperties(data: collection),
      );

      expect(api.calls.take(3), [
        ['sourceAddGeoJson', 'source', jsonEncode(collection)],
        ['sourceSetGeoJson', 'source', jsonEncode(collection)],
        ['sourceSetFeature', 'source', jsonEncode(feature)],
      ]);
      expect(api.calls.last.take(2), ['styleAddSource', 'other']);
      expect(
        (api.calls.last[2]! as Map)['data'],
        jsonDecode(jsonEncode(collection)),
      );
      // The platform channel takes what addSource hands it.
      expect(
        () => MapLibreMapHostApi.pigeonChannelCodec.encodeMessage(
          api.calls.last,
        ),
        returnsNormally,
      );
    });

    test('a value jsonEncode cannot write fails every GeoJSON write the '
        'same way', () async {
      final feature = {
        'type': 'Feature',
        'geometry': null,
        'properties': {'when': DateTime(2020)},
      };

      await expectLater(
        platform.addGeoJsonSource('source', feature),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      await expectLater(
        platform.addSource('source', GeojsonSourceProperties(data: feature)),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(api.calls, isEmpty);
    });

    // JSON has no NaN or infinity, so MapLibre Native cannot read them.
    test('a number that is not finite fails every GeoJSON write with '
        'INVALID_GEOJSON', () async {
      final invalid = isA<PlatformException>()
          .having((e) => e.code, 'code', 'INVALID_GEOJSON')
          .having(
            (e) => e.details,
            'details',
            'A number is NaN or infinite, which JSON cannot hold.',
          );
      Map<String, dynamic> feature(Object? value) => {
        'type': 'Feature',
        'geometry': null,
        'properties': {'value': value},
      };
      final big = line(40000);
      ((big['features'] as List).single as Map)['properties'] = {
        'value': double.infinity,
      };

      await expectLater(
        platform.addGeoJsonSource('source', feature(double.nan)),
        throwsA(invalid),
      );
      await expectLater(
        platform.setGeoJsonSource('source', big),
        throwsA(invalid),
      );
      await expectLater(
        platform.setFeatureForGeoJsonSource(
          'source',
          feature(const _Wrapped(double.negativeInfinity)),
        ),
        throwsA(invalid),
      );
      await expectLater(
        platform.addSource(
          'source',
          GeojsonSourceProperties(data: feature(double.nan)),
        ),
        throwsA(invalid),
      );
      await expectLater(
        platform.addSource('source', GeojsonSourceProperties(data: big)),
        throwsA(invalid),
      );
      expect(api.calls, isEmpty);
    });

    test('a url as the data of addSource is not checked', () async {
      await platform.addSource(
        'source',
        const GeojsonSourceProperties(data: 'https://example.com/a.json'),
      );

      expect(api.calls.single.take(2), ['styleAddSource', 'source']);
    });

    // As web hands it to maplibre-gl-js.
    test('a url reaches native with what a url cannot hold '
        'percent-encoded', () async {
      api.replies['mapEditGeoJsonUrl'] = true;

      await platform.addSource(
        'source',
        const GeojsonSourceProperties(data: 'file:///a b/c.json'),
      );
      await platform.addSource(
        'image',
        const ImageSourceProperties(url: 'https://example.com/{a}.png'),
      );
      expect(
        await platform.editGeoJsonUrl('source', 'https://example.com/a b'),
        isTrue,
      );
      // An empty url changes nothing, as on web.
      expect(await platform.editGeoJsonUrl('source', ''), isFalse);

      expect(api.calls.map((call) => call.take(2)), [
        ['styleAddSource', 'source'],
        ['styleAddSource', 'image'],
        ['mapEditGeoJsonUrl', 'source'],
      ]);
      expect((api.calls[0][2]! as Map)['data'], 'file:///a%20b/c.json');
      expect(
        (api.calls[1][2]! as Map)['url'],
        'https://example.com/%7Ba%7D.png',
      );
      expect(api.calls[2][2], 'https://example.com/a%20b');
    });

    // MapLibre Native rejects them, and maplibre-gl-js requests no tile.
    test('addSource gives bounds across the antimeridian every '
        'longitude', () async {
      await platform.addSource(
        'tiles',
        const RasterSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          bounds: [170, -10, -170, 10],
        ),
      );

      expect((api.calls.single[2]! as Map)['bounds'], [-180, -10, 180, 10]);
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

  // The Android SDK hands every feature id over as text, so native marks the
  // features whose text id reads as a number to give them back as text.
  group('feature ids that are text', () {
    setUp(init);

    const marker = 'maplibre_gl:string_id';

    Map<String, dynamic> point(Object id) => {
      'type': 'Feature',
      'id': id,
      'properties': {'name': '$id'},
      'geometry': {
        'type': 'Point',
        'coordinates': [1, 2],
      },
    };

    Map<String, dynamic> collection(List<Object> ids) => {
      'type': 'FeatureCollection',
      'features': [for (final id in ids) point(id)],
    };

    /// The names of the features of [json] that carry the marker.
    Set<String> marked(Object? json) {
      final data = json is String ? jsonDecode(json) as Map : json! as Map;
      final features =
          data['type'] == 'FeatureCollection'
              ? data['features'] as List
              : [data];
      return {
        for (final feature in features.cast<Map>())
          if ((feature['properties'] as Map).containsKey(marker))
            (feature['properties'] as Map)['name'] as String,
      };
    }

    const ids = <Object>[2, '2', 2.5, '2.5', '-3', 'poi-12', '02', '1e3'];

    test('are marked on Android when they read as a number', () async {
      final geojson = collection(ids);
      final before = jsonEncode(geojson);

      await platform.addGeoJsonSource('source', geojson);
      await platform.setGeoJsonSource('source', geojson);
      await platform.setFeatureForGeoJsonSource('source', point('7'));
      await platform.addSource(
        'inline',
        GeojsonSourceProperties(data: collection(ids)),
      );

      expect(api.calls.map((call) => call.first), [
        'sourceAddGeoJson',
        'sourceSetGeoJson',
        'sourceSetFeature',
        'styleAddSource',
      ]);
      for (final call in api.calls.take(2)) {
        expect(marked(call[2]), {'2', '2.5', '-3'});
      }
      expect(marked(api.calls[2][2]), {'7'});
      expect(marked((api.calls[3][2]! as Map)['data']), {'2', '2.5', '-3'});
      // The data of the app is left as it was.
      expect(jsonEncode(geojson), before);
    });

    test('are marked in the text editGeoJsonSource takes', () async {
      api.replies['mapEditGeoJsonSource'] = true;
      final withText = jsonEncode(collection(['2', 2]));
      final withoutText = jsonEncode(collection([2, 'poi-12']));

      await platform.editGeoJsonSource('source', withText);
      await platform.editGeoJsonSource('source', withoutText);

      expect(marked(api.calls[0][2]), {'2'});
      // Sent as it came when nothing needs the marker.
      expect(api.calls[1][2], same(withoutText));
    });

    test('are marked in a large payload too', () async {
      final big = collection([for (var i = 0; i < 200; i++) '$i']);

      await platform.setGeoJsonSource('source', big);

      expect(marked(api.calls.single[2]), hasLength(200));
    });

    test('are sent unmarked on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      api.replies['mapEditGeoJsonSource'] = true;
      final geojson = collection(ids);

      await platform.addGeoJsonSource('source', geojson);
      await platform.setFeatureForGeoJsonSource('source', point('7'));
      await platform.editGeoJsonSource('source', jsonEncode(geojson));
      await platform.addSource(
        'inline',
        GeojsonSourceProperties(data: geojson),
      );

      expect(api.calls[0][2], jsonEncode(geojson));
      expect(api.calls[1][2], jsonEncode(point('7')));
      expect(api.calls[2][2], jsonEncode(geojson));
      expect((api.calls[3][2]! as Map)['data'], same(geojson));
    });
  });

  // MapLibre Native has no generateId, so the plugin numbers the features.
  group('generateId', () {
    setUp(init);

    Map<String, dynamic> point(Object? id) => {
      'type': 'Feature',
      if (id != null) 'id': id,
      'properties': {'name': '$id'},
      'geometry': {
        'type': 'Point',
        'coordinates': [1, 2],
      },
    };

    Map<String, dynamic> collection(List<Object?> ids) => {
      'type': 'FeatureCollection',
      'features': [for (final id in ids) point(id)],
    };

    /// The features of [json], a GeoJSON object or its text.
    List<Map> featuresOf(Object? json) {
      final data = json is String ? jsonDecode(json) as Map : json! as Map;
      return data['type'] == 'FeatureCollection'
          ? (data['features'] as List).cast<Map>()
          : [data];
    }

    /// Expects the features of [json] to have the ids [expected], and no
    /// property of the plugin.
    void expectIds(Object? json, List<Object?> expected) {
      final features = featuresOf(json);
      expect([for (final feature in features) feature['id']], expected);
      for (final feature in features) {
        expect(
          (feature['properties'] as Map).keys.map((key) => '$key'),
          everyElement(isNot(startsWith('maplibre_gl:'))),
        );
      }
    }

    Future<void> addGenerated(String sourceId, Object data) =>
        platform.addSource(
          sourceId,
          GeojsonSourceProperties(data: data, generateId: true),
        );

    test('numbers the features of the data, over their ids', () async {
      api.replies['mapEditGeoJsonSource'] = true;
      final geojson = collection(['2', 'poi-12', null]);
      final before = jsonEncode(geojson);

      await addGenerated('generated', geojson);
      await platform.setGeoJsonSource('generated', collection([9, 8]));
      await platform.editGeoJsonSource(
        'generated',
        jsonEncode(collection(['7'])),
      );
      await platform.setGeoJsonSource('generated', point('x'));
      // Large enough to be checked on a background isolate.
      await platform.setGeoJsonSource(
        'generated',
        collection([for (var i = 0; i < 200; i++) 'id-$i']),
      );

      expectIds((api.calls[0][2]! as Map)['data'], [0, 1, 2]);
      expectIds(api.calls[1][2], [0, 1]);
      expectIds(api.calls[2][2], [0]);
      expectIds(api.calls[3][2], [0]);
      expectIds(api.calls[4][2], [for (var i = 0; i < 200; i++) i]);
      // The data of the app is left as it was.
      expect(jsonEncode(geojson), before);
    });

    test('numbers on iOS too', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      api.replies['mapEditGeoJsonSource'] = true;

      await addGenerated('generated', collection(['a', 'b']));
      await platform.editGeoJsonSource(
        'generated',
        jsonEncode(collection(['c'])),
      );

      expectIds((api.calls[0][2]! as Map)['data'], [0, 1]);
      expectIds(api.calls[1][2], [0]);
    });

    test('a feature set by setGeoJsonFeature keeps its id', () async {
      await addGenerated('generated', collection(['a', 'b']));

      await platform.setFeatureForGeoJsonSource('generated', point('1'));

      expect(api.calls[1][2], jsonEncode(point('1')));
    });

    test('data from a url is not numbered, but data set later is', () async {
      await addGenerated('generated', 'https://example.com/a.json');
      await platform.setGeoJsonSource('generated', collection(['a']));

      expect(
        api.calls[0][2],
        containsPair('data', 'https://example.com/a.json'),
      );
      expectIds(api.calls[1][2], [0]);
    });

    test('ends with the source, a new source of that id or a new '
        'style', () async {
      final events = platform as MapLibreMapFlutterApi;
      Future<List<Object?>> idsSet() async {
        api.calls.clear();
        await platform.setGeoJsonSource('generated', collection([5]));
        return [
          for (final feature in featuresOf(api.calls.single[2])) feature['id'],
        ];
      }

      await addGenerated('generated', collection([]));
      expect(await idsSet(), [0]);
      await platform.removeSource('generated');
      expect(await idsSet(), [5]);

      await addGenerated('generated', collection([]));
      await platform.addGeoJsonSource('generated', collection([]));
      expect(await idsSet(), [5]);

      await addGenerated('generated', collection([]));
      await platform.addSource(
        'generated',
        GeojsonSourceProperties(data: collection([])),
      );
      expect(await idsSet(), [5]);

      await addGenerated('generated', collection([]));
      await events.mapOnStyleLoaded();
      expect(await idsSet(), [5]);
    });

    test('a failed add leaves the source as it was', () async {
      await addGenerated('generated', collection([]));
      api.errors['styleAddSource'] = PlatformException(code: 'boom');
      await expectLater(
        platform.addSource(
          'generated',
          GeojsonSourceProperties(data: collection([])),
        ),
        throwsA(isA<PlatformException>()),
      );
      api.errors.remove('styleAddSource');
      api.calls.clear();

      await platform.setGeoJsonSource('generated', collection([5]));

      expectIds(api.calls.single[2], [0]);
    });

    test('a failed remove leaves the source as it was', () async {
      await addGenerated('generated', collection([]));
      api.errors['styleRemoveSource'] = PlatformException(code: 'boom');
      await expectLater(
        platform.removeSource('generated'),
        throwsA(isA<PlatformException>()),
      );
      api.errors.remove('styleRemoveSource');
      api.calls.clear();

      await platform.setGeoJsonSource('generated', collection([5]));

      expectIds(api.calls.single[2], [0]);
    });

    test('a remove and an add made without await keep call order', () async {
      await addGenerated('generated', collection([]));
      await Future.wait([
        platform.removeSource('generated'),
        addGenerated('generated', collection([])),
      ]);
      api.calls.clear();

      await platform.setGeoJsonSource('generated', collection([5]));

      expectIds(api.calls.single[2], [0]);
    });
  });

  group('queries', () {
    setUp(init);

    test('queryRenderedFeatures encodes the filter and decodes', () async {
      api.replies['mapQueryRenderedFeaturesAtPoint'] = <String>[
        '{"id":1,"type":"Feature"}',
      ];

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
          '["==",["get","kind"],"cafe"]',
        ],
      ]);
    });

    test('queryRenderedFeaturesInRect sends the filter string', () async {
      api.replies['mapQueryRenderedFeaturesInRect'] = <String>[];

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
      api.replies['sourceGetClusterLeaves'] = <String>['{"id":"a"}'];

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
      api.replies['mapGetVisibleRegion'] = PgLatLngBounds(
        southwest: PgLatLng(latitude: 10, longitude: 20),
        northeast: PgLatLng(latitude: 30, longitude: 40),
      );

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

    test('toScreenLocationBatch answers no points without native', () async {
      expect(await platform.toScreenLocationBatch(const []), isEmpty);
      expect(api.calls, isEmpty);
    });

    test('toLatLng sends doubles for an int point', () async {
      api.replies['mapToLatLng'] = PgLatLng(latitude: 1.5, longitude: 2.5);

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
      api.replies['sourceGetFeatureState'] = '{"hover":true}';

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

      await events().mapOnCameraTrackingChanged(
        PgMyLocationTrackingMode.trackingCompass,
      );
      await events().mapOnCameraTrackingDismissed();

      expect(modes, [MyLocationTrackingMode.trackingCompass]);
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
      api.replies['mapUpdate'] = PgCameraPosition(
        bearing: 1,
        target: PgLatLng(latitude: 10, longitude: 20),
        tilt: 2,
        zoom: 3,
      );

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
        ['mapUpdate', PgMapOptions(compassEnabled: false)],
      ]);
    });

    test('updateMapOptions types every option', () async {
      final options = MapLibreMapOptions(
        compassEnabled: true,
        cameraTargetBounds: CameraTargetBounds(
          LatLngBounds(
            southwest: const LatLng(1, 2),
            northeast: const LatLng(3, 4),
          ),
        ),
        styleString: 'https://example.com/style.json',
        minMaxZoomPreference: const MinMaxZoomPreference(2, null),
        rotateGesturesEnabled: false,
        scrollGesturesEnabled: true,
        tiltGesturesEnabled: false,
        zoomGesturesEnabled: true,
        doubleClickZoomEnabled: false,
        panInertia: PanInertia.short,
        hapticFeedbackEnabled: true,
        trackCameraPosition: true,
        myLocationEnabled: true,
        myLocationTrackingMode: MyLocationTrackingMode.trackingGps,
        myLocationRenderMode: MyLocationRenderMode.compass,
        myLocationStyle: const MyLocationStyle(
          fillColor: Color(0xFF112233),
          accuracyCircleEnabled: false,
          pulseEnabled: true,
        ),
        logoEnabled: false,
        logoViewPosition: LogoViewPosition.bottomRight,
        logoViewMargins: const Point(1, 2),
        compassViewPosition: CompassViewPosition.topLeft,
        compassViewMargins: const Point(3, 4),
        attributionEnabled: true,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        attributionButtonMargins: const Point(5.5, 6),
        attributionButtonColor: const Color(0xFF445566),
        // Web only, and dropped.
        scaleControlEnabled: true,
        scaleControlPosition: ScaleControlPosition.topRight,
        scaleControlUnit: ScaleControlUnit.nautical,
        locationEnginePlatforms: const LocationEnginePlatforms.android(
          enableHighAccuracy: true,
          interval: 500,
          displacement: 10,
        ),
        locationSource: const ManualLocationSource(),
        foregroundLoadColor: const Color(0xFF778899),
        translucentTextureSurface: true,
        featureTapsTriggersMapClick: true,
        symbolPlacementTransitionsEnabled: false,
      );

      await platform.updateMapOptions(options.toMap());

      expect(api.calls, [
        [
          'mapUpdate',
          PgMapOptions(
            compassEnabled: true,
            cameraTargetBounds: PgCameraTargetBounds(
              bounds: PgLatLngBounds(
                southwest: PgLatLng(latitude: 1, longitude: 2),
                northeast: PgLatLng(latitude: 3, longitude: 4),
              ),
            ),
            styleString: 'https://example.com/style.json',
            minMaxZoomPreference: PgMinMaxZoomPreference(minZoom: 2),
            rotateGesturesEnabled: false,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomGesturesEnabled: true,
            doubleClickZoomEnabled: false,
            panInertia: PgPanInertia.short,
            hapticFeedbackEnabled: true,
            trackCameraPosition: true,
            myLocationEnabled: true,
            myLocationTrackingMode: PgMyLocationTrackingMode.trackingGps,
            myLocationRenderMode: PgMyLocationRenderMode.compass,
            myLocationStyle: PgMyLocationStyle(
              fillColor: 0xFF112233,
              accuracyCircleEnabled: false,
              pulseEnabled: true,
            ),
            logoEnabled: false,
            logoViewPosition: PgOrnamentPosition.bottomRight,
            logoViewMargins: PgScreenPoint(x: 1, y: 2),
            compassViewPosition: PgOrnamentPosition.topLeft,
            compassViewMargins: PgScreenPoint(x: 3, y: 4),
            attributionEnabled: true,
            attributionButtonPosition: PgOrnamentPosition.bottomLeft,
            attributionButtonMargins: PgScreenPoint(x: 5.5, y: 6),
            attributionButtonColor: 0xFF445566,
            locationEngineProperties: PgLocationEngineProperties(
              interval: 500,
              priority: PgLocationPriority.highAccuracy,
              displacement: 10,
            ),
            locationSource: PgLocationSource.manual,
            foregroundLoadColor: 0xFF778899,
            translucentTextureSurface: true,
            featureTapsTriggersMapClick: true,
            symbolPlacementTransitionsEnabled: false,
          ),
        ],
      ]);
    });

    test('updateMapOptions sends the unbounded values', () async {
      await platform.updateMapOptions({
        'cameraTargetBounds': CameraTargetBounds.unbounded.toJson(),
        'minMaxZoomPreference': MinMaxZoomPreference.unbounded.toJson(),
        'locationSource': 'platform',
      });

      expect(api.calls, [
        [
          'mapUpdate',
          PgMapOptions(
            cameraTargetBounds: PgCameraTargetBounds(),
            minMaxZoomPreference: PgMinMaxZoomPreference(),
            locationSource: PgLocationSource.platform,
          ),
        ],
      ]);
    });

    test('updateMapOptions sends the iOS location engine settings', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const engine = LocationEnginePlatforms.iOS(
        enableHighAccuracy: true,
        displacement: 5,
        intervalMs: 1000,
        pulseWindowMs: 2000,
      );

      await platform.updateMapOptions({
        'locationEngineProperties': engine.toList(),
      });

      expect(api.calls, [
        [
          'mapUpdate',
          PgMapOptions(
            locationEngineProperties: PgLocationEngineProperties(
              enableHighAccuracy: true,
              displacement: 5,
              intervalMs: 1000,
              pulseWindowMs: 2000,
            ),
          ),
        ],
      ]);
    });

    test('updateMapOptions is null when native sends no camera', () async {
      expect(await platform.updateMapOptions(const {}), isNull);
    });

    test('updateMyLocationTrackingMode sends the mode', () async {
      await platform.updateMyLocationTrackingMode(
        MyLocationTrackingMode.trackingCompass,
      );

      expect(api.calls, [
        [
          'mapUpdateMyLocationTrackingMode',
          PgMyLocationTrackingMode.trackingCompass,
        ],
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

    test('setTrackingCameraOptions reports a cancelled animation', () async {
      api.replies['locationComponentSetTrackingCameraOptions'] = false;

      expect(await platform.setTrackingCameraOptions(tilt: 30), isFalse);
    });

    test('setManualLocation sends the update', () async {
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
          PgManualLocationUpdate(
            position: PgLatLng(latitude: 1, longitude: 2),
            timestamp: 1000,
            horizontalAccuracy: 5,
          ),
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
          PgEdgeInsets(top: 2, left: 1, bottom: 4, right: 3),
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

    test('getCustomHeaders returns a copy of the headers', () async {
      final headers = {'X-Key': 'v'};
      api.replies['mapGetCustomHeaders'] = headers;

      final result = await platform.getCustomHeaders();
      result['X-Other'] = 'w';

      expect(result, {'X-Key': 'v', 'X-Other': 'w'});
      expect(headers, {'X-Key': 'v'});
      expect(api.calls, [
        ['mapGetCustomHeaders'],
      ]);
    });

    test('requestMyLocationLatLng reads the coordinates', () async {
      api.replies['locationComponentGetLastLocation'] = PgLatLng(
        latitude: 45.5,
        longitude: 9,
      );

      expect(await platform.requestMyLocationLatLng(), const LatLng(45.5, 9));
      expect(api.calls, [
        ['locationComponentGetLastLocation'],
      ]);
    });
  });

  group('style', () {
    setUp(init);

    test('getStyle returns the JSON when native has it', () async {
      api.replies['mapGetStyle'] = '{"version":8}';

      expect(await platform.getStyle(), '{"version":8}');
      expect(api.calls, [
        ['mapGetStyle'],
      ]);
    });

    test('getStyle is null when native has no style', () async {
      expect(await platform.getStyle(), isNull);
    });

    test('the edit calls send their arguments and read the result', () async {
      api.replies['mapEditGeoJsonSource'] = true;
      api.replies['mapEditGeoJsonUrl'] = false;
      api.replies['mapSetLayerFilter'] = true;

      expect(
        await platform.editGeoJsonSource(
          'source',
          '{"type":"Point","coordinates":[1,2]}',
        ),
        isTrue,
      );
      expect(
        await platform.editGeoJsonUrl('source', 'https://example.com/a.json'),
        isFalse,
      );
      // The deprecated controller method still reaches it.
      // ignore: deprecated_member_use
      expect(await platform.setLayerFilter('layer', '["has","a"]'), isTrue);
      expect(api.calls, [
        [
          'mapEditGeoJsonSource',
          'source',
          '{"type":"Point","coordinates":[1,2]}',
        ],
        ['mapEditGeoJsonUrl', 'source', 'https://example.com/a.json'],
        ['mapSetLayerFilter', 'layer', '["has","a"]'],
      ]);
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

    // A style copied from JSON spells out the encoding and its factors, which
    // must reach native rather than be rejected as a custom encoding.
    test('addSource passes the factors of a built-in encoding', () async {
      await platform.addSource(
        'dem-default',
        const RasterDemSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          // The spelled-out default is the case under test.
          // ignore: avoid_redundant_argument_values
          encoding: 'mapbox',
          redFactor: 1.0,
          baseShift: 0.0,
        ),
      );
      await platform.addSource(
        'dem-terrarium',
        const RasterDemSourceProperties(
          tiles: ['https://example.com/{z}/{x}/{y}.png'],
          encoding: 'terrarium',
          greenFactor: 2.0,
        ),
      );

      final standard = api.calls[0][2]! as Map;
      expect(standard['encoding'], 'mapbox');
      expect(standard['redFactor'], 1.0);
      final terrarium = api.calls[1][2]! as Map;
      expect(terrarium['encoding'], 'terrarium');
      expect(terrarium['greenFactor'], 2.0);
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

    test('getSourceIds reads the sources', () async {
      api.replies['styleGetSourceIds'] = <String>['water', 'roads'];

      final ids = await platform.getSourceIds();

      expect(ids, ['water', 'roads']);
      // A growable list of its own.
      ids.add('more');
      expect(api.calls, [
        ['styleGetSourceIds'],
      ]);
    });

    test('getSourceProperties decodes and shapes the source', () async {
      api.replies['styleGetSourceProperties'] =
          '{"type":"vector","maxzoom":14.0,"bounds":[-180.0,-85.5,180.0,85.5]}';

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
    final pgQuad = PgLatLngQuad(
      topLeft: PgLatLng(latitude: 4, longitude: 1),
      topRight: PgLatLng(latitude: 4, longitude: 2),
      bottomRight: PgLatLng(latitude: 3, longitude: 2),
      bottomLeft: PgLatLng(latitude: 3, longitude: 1),
    );

    test(
      'addImage sends the bytes, their length, sdf and pixelRatio',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3]);

        await platform.addImage('pin', bytes);
        await platform.addImage('glyph', bytes, true);
        await platform.addImage('sharp', bytes, false, 2.5);

        expect(api.calls, [
          ['styleAddImage', 'pin', bytes, 3, false, null],
          ['styleAddImage', 'glyph', bytes, 3, true, null],
          ['styleAddImage', 'sharp', bytes, 3, false, 2.5],
        ]);
      },
    );

    test('addImageSource sends the corners', () async {
      final bytes = Uint8List.fromList([1, 2]);

      await platform.addImageSource('image', bytes, quad);

      expect(api.calls, [
        ['styleAddImageSource', 'image', bytes, 2, pgQuad],
      ]);
    });

    test('updateImageSource sends what is set and null otherwise', () async {
      final bytes = Uint8List.fromList([9]);

      await platform.updateImageSource('image', bytes, quad);
      await platform.updateImageSource('image', null, null);

      expect(api.calls, [
        ['styleUpdateImageSource', 'image', bytes, 1, pgQuad],
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
          null,
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
      api.replies['styleGetFilter'] = '["==",["get","kind"],"cafe"]';

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

    test('setFilter sends null to remove the filter', () async {
      await platform.setFilter('a', null);

      expect(api.calls, [
        ['styleSetFilter', 'a', null],
      ]);
    });

    test('getFilter is null for a layer without a filter', () async {
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
          'geometries': [lineString(2), lineString(3)],
        },
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

    // The size check runs first and must not trip on what is not GeoJSON,
    // which then fails the call without reaching native.
    for (final (name, geometry) in [
      (
        'a GeometryCollection holding something else',
        {
          'type': 'GeometryCollection',
          'geometries': [lineString(2), 'not a geometry'],
        },
      ),
      (
        'a GeometryCollection without a geometries list',
        {'type': 'GeometryCollection', 'geometries': 'none'},
      ),
    ]) {
      test('setFeatureForGeoJsonSource rejects $name', () async {
        await expectLater(
          platform.setFeatureForGeoJsonSource('source', feature(geometry)),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'INVALID_GEOJSON',
            ),
          ),
        );
        expect(api.calls, isEmpty);
      });
    }
  });

  // Plain GeoJSON is checked and written in one pass; anything else goes
  // through geoJsonError and jsonEncode. Native gets the same either way.
  group('GeoJSON text', () {
    setUp(init);

    const marker = 'maplibre_gl:string_id';

    Map<String, dynamic> point(Object? properties, {Object? id = 1}) => {
      'type': 'Feature',
      'id': id,
      'properties': properties,
      'geometry': {
        'type': 'Point',
        'coordinates': [1.5, -2],
      },
    };

    Object deep(int levels) => levels == 0 ? 1 : {'d': deep(levels - 1)};

    for (final target in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('is what jsonEncode writes on ${target.name}', () async {
        debugDefaultTargetPlatformOverride = target;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final text = point({
          'name': 'ő"x',
          'tab\there': '漢\n字',
          'emoji': '😀',
          'lone': '\ud800',
          'latin1': 'é ÿ',
          '\u001f': r'back\slash',
        });
        final numbers = point({
          'n': [-0.0, 1e21, 1e-7, 0.1 + 0.2, 2147483648, true, null],
        }, id: 'poi-1');
        final collection = {
          'type': 'FeatureCollection',
          'bbox': [-180, -90, 180, 90],
          'features': [
            text,
            numbers,
            {
              'geometry': {
                'coordinates': [
                  [
                    [0, 0, 12.5, 'extra'],
                    [1, 0],
                    [1, 1],
                    [0, 0],
                  ],
                ],
                'type': 'Polygon',
              },
              'properties': null,
              'type': 'Feature',
            },
            point({'deep': deep(10)}, id: 2.5),
          ],
        };
        // Deeper than the single pass goes.
        final deeper = point({'deep': deep(100)});

        await platform.setGeoJsonSource('source', collection);
        await platform.setFeatureForGeoJsonSource('source', text);
        await platform.setGeoJsonSource('source', deeper);

        expect(api.calls, [
          ['sourceSetGeoJson', 'source', jsonEncode(collection)],
          ['sourceSetFeature', 'source', jsonEncode(text)],
          ['sourceSetGeoJson', 'source', jsonEncode(deeper)],
        ]);
      });
    }

    test('marks a text id as a copy of the feature would', () async {
      Map<String, dynamic> collection(List<Map<String, dynamic>> features) => {
        'type': 'FeatureCollection',
        'features': features,
      };

      await platform.setGeoJsonSource(
        'source',
        collection([
          {'type': 'Feature', 'id': '1', 'geometry': null},
          {'type': 'Feature', 'properties': null, 'id': '2', 'geometry': null},
        ]),
      );
      // The marker already there.
      await platform.setGeoJsonSource(
        'source',
        collection([
          {
            'properties': {'a': 1, marker: false},
            'type': 'Feature',
            'id': '3',
            'geometry': null,
          },
        ]),
      );

      expect(api.calls.map((call) => call[2]), [
        jsonEncode(
          collection([
            {
              'type': 'Feature',
              'id': '1',
              'geometry': null,
              'properties': {marker: true},
            },
            {
              'type': 'Feature',
              'properties': {marker: true},
              'id': '2',
              'geometry': null,
            },
          ]),
        ),
        jsonEncode(
          collection([
            {
              'properties': {'a': 1, marker: true},
              'type': 'Feature',
              'id': '3',
              'geometry': null,
            },
          ]),
        ),
      ]);
    });

    test(
      'numbers a feature in place of its id, or after its members',
      () async {
        await platform.addSource(
          'generated',
          const GeojsonSourceProperties(
            data: 'https://example.com/a.json',
            generateId: true,
          ),
        );

        await platform.setGeoJsonSource('generated', {
          'type': 'FeatureCollection',
          'features': [
            {'id': 'a', 'type': 'Feature', 'geometry': null},
            {'type': 'Feature', 'geometry': null, 'properties': {}},
          ],
        });

        expect(
          api.calls.last[2],
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {'id': 0, 'type': 'Feature', 'geometry': null},
              {'type': 'Feature', 'geometry': null, 'properties': {}, 'id': 1},
            ],
          }),
        );
      },
    );

    // The first error geoJsonError finds wins, wherever the data stops being
    // plain JSON.
    for (final (name, data) in <(String, Map<String, dynamic>)>[
      (
        'a feature without a geometry after a valid one',
        {
          'type': 'FeatureCollection',
          'features': [
            point(null),
            {'type': 'Feature'},
          ],
        },
      ),
      (
        'a position that is not a number',
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [1, 2],
              [double.nan, 0],
            ],
          },
        },
      ),
      (
        'a bad geometry after a NaN property',
        {
          'type': 'Feature',
          'properties': {'v': double.nan},
          'geometry': {
            'type': 'Point',
            'coordinates': [1],
          },
        },
      ),
      ('properties that are a list', point([1])),
      ('a null id', point(null, id: null)),
      (
        'a type after a bad geometry',
        {
          'geometry': {'type': 'Circle'},
          'type': 'Feature',
        },
      ),
    ]) {
      test('rejects $name with the reason of geoJsonError', () async {
        final reason = geoJsonError(data);
        expect(reason, isNotNull);
        final invalid = isA<PlatformException>()
            .having((e) => e.code, 'code', 'INVALID_GEOJSON')
            .having((e) => e.details, 'details', reason);

        await expectLater(
          platform.setGeoJsonSource('source', data),
          throwsA(invalid),
        );
        await expectLater(
          platform.addSource('source', GeojsonSourceProperties(data: data)),
          throwsA(invalid),
        );
        expect(api.calls, isEmpty);
      });
    }

    test('a cycle fails as jsonEncode fails on it', () async {
      final properties = <String, dynamic>{};
      properties['self'] = properties;

      await expectLater(
        platform.setGeoJsonSource('source', point(properties)),
        throwsA(isA<JsonCyclicError>()),
      );
    });
  });

  group('conversions, clusters and feature state', () {
    setUp(init);

    test('querySourceFeatures encodes the filter and decodes', () async {
      api.replies['mapQuerySourceFeatures'] = <String>[
        '{"id":"a","properties":{"n":[1,2]}}',
      ];

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
        ['mapQuerySourceFeatures', 'source', 'layer', '["has","n"]'],
      ]);
    });

    test('querySourceFeatures sends null for what is unset', () async {
      api.replies['mapQuerySourceFeatures'] = <String>[];

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
      api.replies['sourceGetClusterChildren'] = <String>[
        '{"id":1,"properties":{"cluster":true}}',
      ];

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

    test('getClusterChildren is empty without children', () async {
      api.replies['sourceGetClusterChildren'] = <String>[];

      expect(await platform.getClusterChildren('points', 12), isEmpty);
    });

    test('getClusterLeaves pages from the start by default', () async {
      api.replies['sourceGetClusterLeaves'] = <String>[];

      expect(await platform.getClusterLeaves('points', 12), isEmpty);
      expect(api.calls, [
        ['sourceGetClusterLeaves', 'points', 12, 10, 0],
      ]);
    });

    test('toScreenLocation sends the coordinates and reads x and y', () async {
      api.replies['mapToScreenLocation'] = PgScreenPoint(x: 100.5, y: 200);

      final point = await platform.toScreenLocation(const LatLng(45, 9));

      expect(point, const Point(100.5, 200.0));
      expect(api.calls, [
        ['mapToScreenLocation', 45.0, 9.0],
      ]);
    });

    test('getMetersPerPixelAtLatitude reads the answer', () async {
      api.replies['mapGetMetersPerPixelAtLatitude'] = 1.25;

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
      await platform.removeFeatureState(
        'source',
        featureId: '1',
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
        ['sourceRemoveFeatureState', 'source', '1', null, 'layer'],
        ['sourceRemoveFeatureState', 'source', null, null, null],
      ]);
    });

    test('getFeatureState is null when the feature has no state', () async {
      expect(await platform.getFeatureState('source', '1'), isNull);

      expect(api.calls, [
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
    const codec = MapLibreMapHostApi.pigeonChannelCodec;

    tearDown(() => MapLibreMap.useHybridComposition = false);

    Map<String, dynamic> creationParams() => {
      'options': <String, dynamic>{'compassEnabled': true},
    };

    /// What [creationParams] becomes, with the Android flag.
    PgCreationParams typed({bool useHybridComposition = false}) =>
        PgCreationParams(
          options: PgMapOptions(compassEnabled: true),
          dragEnabled: true,
          useHybridComposition: useHybridComposition,
        );

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
            .having((v) => v.creationParams, 'creationParams', typed())
            .having(
              (v) => v.creationParamsCodec,
              'creationParamsCodec',
              same(codec),
            )
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
      // The map of the caller is left as it was.
      expect(params, creationParams());
    });

    test('Android copes with creation params without options', () {
      onPlatform(TargetPlatform.android);

      expect(
        platform.buildView(<String, dynamic>{}, (_) {}, null),
        isA<AndroidView>().having(
          (v) => v.creationParams,
          'creationParams',
          PgCreationParams(
            options: PgMapOptions(),
            dragEnabled: true,
            useHybridComposition: false,
          ),
        ),
      );
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
        final created = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: platform.buildView(creationParams(), created.add, null),
          ),
        );
        await tester.pump();

        final create = viewCalls.singleWhere((c) => c.method == 'create');
        final args = create.arguments as Map;
        expect(args['viewType'], viewType);
        // Encoded with the codec of the messages, which native decodes with.
        expect(
          codec.decodeMessage(
            ByteData.sublistView(args['params'] as Uint8List),
          ),
          typed(useHybridComposition: true),
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
      void onCreated(int id) {}

      final view = platform.buildView(creationParams(), onCreated, null);

      expect(
        view,
        isA<UiKitView>()
            .having((v) => v.viewType, 'viewType', viewType)
            .having((v) => v.creationParams, 'creationParams', typed())
            .having(
              (v) => v.creationParamsCodec,
              'creationParamsCodec',
              same(codec),
            )
            .having(
              (v) => v.onPlatformViewCreated,
              'onPlatformViewCreated',
              same(onCreated),
            ),
      );
    });

    test('the creation params of a map are typed', () {
      onPlatform(TargetPlatform.android);
      const camera = CameraPosition(
        bearing: 10,
        target: LatLng(45, 9),
        tilt: 20,
        zoom: 11,
      );

      final view = platform.buildView(
        {
          'initialCameraPosition': camera.toMap(),
          'styleString': 'https://example.com/style.json',
          'options': <String, dynamic>{
            'styleString': 'https://example.com/style.json',
          },
          'dragEnabled': false,
          'iosLongClickDurationMilliseconds': 300,
          // Web only, and dropped.
          'webPreserveDrawingBuffer': true,
        },
        (_) {},
        null,
      );

      expect(
        (view as AndroidView).creationParams,
        PgCreationParams(
          styleString: 'https://example.com/style.json',
          options: PgMapOptions(styleString: 'https://example.com/style.json'),
          initialCameraPosition: PgCameraPosition(
            bearing: 10,
            target: PgLatLng(latitude: 45, longitude: 9),
            tilt: 20,
            zoom: 11,
          ),
          dragEnabled: false,
          iosLongClickDurationMs: 300,
          useHybridComposition: false,
        ),
      );
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

/// A position class of a GeoJSON library: `jsonEncode` writes it as the list
/// its `toJson()` returns.
class _Position {
  const _Position(this.longitude, this.latitude);

  final num longitude;
  final num latitude;

  List<num> toJson() => [longitude, latitude];
}

/// A geometry class of an app model, written as the map its `toJson()`
/// returns.
class _Geometry {
  const _Geometry(this.type, this.coordinates);

  final String type;
  final Object? coordinates;

  Map<String, Object?> toJson() => {'type': type, 'coordinates': coordinates};
}

/// An app model `jsonEncode` writes as the map its `toJson()` returns, with
/// [value] in it.
class _Wrapped {
  const _Wrapped(this.value);

  final Object? value;

  Map<String, Object?> toJson() => {'value': value};
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
  Future<PgCameraPosition?> mapUpdate(PgMapOptions options) =>
      _call('mapUpdate', [options]);

  @override
  Future<bool?> cameraAnimate(PgCameraUpdate cameraUpdate, int? duration) =>
      _call('cameraAnimate', [cameraUpdate, duration]);

  @override
  Future<bool?> cameraMove(PgCameraUpdate cameraUpdate) =>
      _call('cameraMove', [cameraUpdate]);

  @override
  Future<void> mapUpdateMyLocationTrackingMode(PgMyLocationTrackingMode mode) =>
      _call('mapUpdateMyLocationTrackingMode', [mode]);

  @override
  Future<bool?> locationComponentSetTrackingCameraOptions(
    double tilt,
    int? duration,
  ) => _call('locationComponentSetTrackingCameraOptions', [tilt, duration]);

  @override
  Future<void> locationComponentSetManualLocation(
    PgManualLocationUpdate update,
  ) => _call('locationComponentSetManualLocation', [update]);

  @override
  Future<void> mapMatchMapLanguageWithDeviceDefault() =>
      _call('mapMatchMapLanguageWithDeviceDefault');

  @override
  Future<void> mapUpdateContentInsets(PgEdgeInsets insets, bool animated) =>
      _call('mapUpdateContentInsets', [insets, animated]);

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
    PgCameraUpdate cameraUpdate,
    int? duration,
    PgCameraAnimationInterpolation? interpolation,
  ) => _call('cameraEase', [cameraUpdate, duration, interpolation]);

  @override
  Future<PgCameraPosition> mapQueryCameraPosition() =>
      _call('mapQueryCameraPosition');

  @override
  Future<bool> mapEditGeoJsonSource(String id, String data) =>
      _call('mapEditGeoJsonSource', [id, data]);

  @override
  Future<bool> mapEditGeoJsonUrl(String id, String url) =>
      _call('mapEditGeoJsonUrl', [id, url]);

  @override
  Future<bool> mapSetLayerFilter(String id, String filter) =>
      _call('mapSetLayerFilter', [id, filter]);

  @override
  Future<String?> mapGetStyle() => _call('mapGetStyle');

  @override
  Future<void> mapSetCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) => _call('mapSetCustomHeaders', [headers, filter]);

  @override
  Future<Map<String, String>> mapGetCustomHeaders() =>
      _call('mapGetCustomHeaders');

  @override
  Future<List<String>> mapQueryRenderedFeaturesAtPoint(
    double x,
    double y,
    List<String> layerIds,
    String? filter,
  ) => _call('mapQueryRenderedFeaturesAtPoint', [x, y, layerIds, filter]);

  @override
  Future<List<String>> mapQueryRenderedFeaturesInRect(
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
  Future<List<String>> mapQuerySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    String? filter,
  ) => _call('mapQuerySourceFeatures', [sourceId, sourceLayerId, filter]);

  @override
  Future<int> sourceGetClusterExpansionZoom(String sourceId, int clusterId) =>
      _call('sourceGetClusterExpansionZoom', [sourceId, clusterId]);

  @override
  Future<List<String>> sourceGetClusterChildren(
    String sourceId,
    int clusterId,
  ) => _call('sourceGetClusterChildren', [sourceId, clusterId]);

  @override
  Future<List<String>> sourceGetClusterLeaves(
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
  Future<PgLatLng> locationComponentGetLastLocation() =>
      _call('locationComponentGetLastLocation');

  @override
  Future<PgLatLngBounds> mapGetVisibleRegion() => _call('mapGetVisibleRegion');

  @override
  Future<void> styleAddImage(
    String name,
    Uint8List bytes,
    int length,
    bool sdf,
    double? pixelRatio,
  ) => _call('styleAddImage', [name, bytes, length, sdf, pixelRatio]);

  @override
  Future<void> styleAddImageSource(
    String imageSourceId,
    Uint8List bytes,
    int length,
    PgLatLngQuad coordinates,
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
    PgLatLngQuad? coordinates,
  ) => _call('styleUpdateImageSource', [
    imageSourceId,
    bytes,
    length,
    coordinates,
  ]);

  @override
  Future<PgScreenPoint> mapToScreenLocation(
    double latitude,
    double longitude,
  ) => _call('mapToScreenLocation', [latitude, longitude]);

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
  Future<void> styleSetFilter(String layerId, String? filter) =>
      _call('styleSetFilter', [layerId, filter]);

  @override
  Future<String?> styleGetFilter(String layerId) =>
      _call('styleGetFilter', [layerId]);

  @override
  Future<PgLatLng> mapToLatLng(double x, double y) =>
      _call('mapToLatLng', [x, y]);

  @override
  Future<double> mapGetMetersPerPixelAtLatitude(double latitude) =>
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
    String? filter,
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
    String? filter,
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
    String? filter,
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
    String? filter,
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
    String? filter,
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
    String? filter,
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
  Future<String?> sourceGetFeatureState(
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
  Future<List<String>> styleGetLayerIds() => _call('styleGetLayerIds');

  @override
  Future<List<String>> styleGetSourceIds() => _call('styleGetSourceIds');

  @override
  Future<String?> styleGetLayerProperties(String layerId) =>
      _call('styleGetLayerProperties', [layerId]);

  @override
  Future<String?> styleGetSourceProperties(String sourceId) =>
      _call('styleGetSourceProperties', [sourceId]);

  @override
  Future<void> styleSetStyle(String style) => _call('styleSetStyle', [style]);
}

/// A platform a package installed through [MapLibrePlatform.createInstance].
/// It shows its own view, so the test can tell that the map used it.
class _AppPlatform extends MapLibrePlatform {
  static const viewKey = Key('app platform view');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) => const SizedBox(key: viewKey);
}

/// An update of a kind the native platform does not know, as a subclass
/// that changed `toJson` could make.
class _UnknownCameraUpdate extends CameraUpdate {
  _UnknownCameraUpdate() : super.zoomIn();

  @override
  dynamic toJson() => ['bogus'];
}
