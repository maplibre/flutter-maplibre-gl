// The messages of each map at the channel level: the generated client the
// platform builds for its view id, answered by handlers that stand in for the
// generated Kotlin and Swift, and events encoded the way native encodes them.
// Also reads the generated sources, hence vm only.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl/src/native/messages.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const viewId = 7;
  const hostApi = 'dev.flutter.pigeon.maplibre_gl.MapLibreMapHostApi';
  const flutterApi = 'dev.flutter.pigeon.maplibre_gl.MapLibreMapFlutterApi';
  const codec = MapLibreMapHostApi.pigeonChannelCodec;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MapLibrePlatform platform;
  late MapLibrePlatform Function() previousFactory;

  /// The decoded arguments of each call native received, by channel name.
  late Map<String, List<Object?>> received;
  final mockedChannels = <String>{};

  /// Stands in for native on the channel of [method] of the map [id]: records
  /// the arguments and answers with [reply] in a Pigeon envelope, or with a
  /// Pigeon error envelope when [reply] throws a [PlatformException].
  void onHost(
    String method,
    Object? Function(List<Object?>? args) reply, {
    int id = viewId,
  }) {
    final channel = '$hostApi.$method.$id';
    mockedChannels.add(channel);
    messenger.setMockMessageHandler(channel, (message) async {
      final args = codec.decodeMessage(message) as List<Object?>?;
      (received[channel] ??= []).add(args);
      try {
        return codec.encodeMessage(<Object?>[reply(args)]);
      } on PlatformException catch (e) {
        return codec.encodeMessage(<Object?>[e.code, e.message, e.details]);
      }
    });
  }

  /// The arguments [method] of the map [id] received, one entry per call.
  List<Object?>? calls(String method, {int id = viewId}) =>
      received['$hostApi.$method.$id'];

  /// Sends [event] to the map [id] as native does. Completes with the decoded
  /// reply envelope, or null when nothing listens.
  Future<List<Object?>?> fromNative(
    String event,
    List<Object?>? args, {
    int id = viewId,
  }) async {
    ByteData? reply;
    await messenger.handlePlatformMessage(
      '$flutterApi.$event.$id',
      MapLibreMapFlutterApi.pigeonChannelCodec.encodeMessage(args),
      (data) => reply = data,
    );
    return codec.decodeMessage(reply) as List<Object?>?;
  }

  setUp(() async {
    previousFactory = MapLibrePlatform.createInstance;
    received = {};
    // No client factory: the platform builds the generated client itself,
    // MapLibreMapHostApi(messageChannelSuffix: '7') for the view id 7.
    MapLibreNativePlugin.registerWith();
    platform = MapLibrePlatform.createInstance();
    onHost('mapWaitForMap', (_) => null);
    await platform.initPlatform(viewId);
  });

  tearDown(() {
    platform.dispose();
    for (final channel in mockedChannels) {
      messenger.setMockMessageHandler(channel, null);
    }
    mockedChannels.clear();
    MapLibrePlatform.createInstance = previousFactory;
  });

  group('calls', () {
    test('initPlatform waits for the map on the channel of its view', () {
      // Without arguments.
      expect(calls('mapWaitForMap'), [null]);
    });

    test('a layer add carries its properties intact', () async {
      onHost('fillLayerAdd', (_) => null);

      await platform.addFillLayer(
        'source',
        'lakes',
        {
          'fill-color': '#3388ff',
          'fill-opacity': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            0.2,
            16,
            0.8,
          ],
          'fill-sort-key': 3,
        },
        belowLayerId: 'labels',
        sourceLayer: 'water',
        minzoom: 2,
        maxzoom: 14,
        filter: [
          '==',
          ['get', 'kind'],
          'lake',
        ],
        enableInteraction: true,
      );

      final args = calls('fillLayerAdd')!.single! as List<Object?>;
      expect(args, [
        'source',
        'lakes',
        'labels',
        'water',
        2.0,
        14.0,
        '["==",["get","kind"],"lake"]',
        true,
        {
          'fill-color': '#3388ff',
          'fill-opacity': [
            'interpolate',
            ['linear'],
            ['zoom'],
            10,
            0.2,
            16,
            0.8,
          ],
          'fill-sort-key': 3,
        },
      ]);
      final properties = args[8]! as Map<Object?, Object?>;
      expect(properties['fill-sort-key'], isA<int>());
      expect((properties['fill-opacity']! as List)[3], isA<int>());
      expect((properties['fill-opacity']! as List)[4], isA<double>());
    });

    test('moveCamera and animateCamera send the update', () async {
      onHost('cameraMove', (_) => true);
      onHost('cameraAnimate', (_) => false);

      final moved = await platform.moveCamera(
        CameraUpdate.newLatLngZoom(const LatLng(45, 9), 12),
      );
      final animated = await platform.animateCamera(
        CameraUpdate.zoomTo(3),
        duration: const Duration(milliseconds: 300),
      );

      expect(moved, isTrue);
      expect(animated, isFalse);
      // Native decodes each kind of update as its own class.
      expect(calls('cameraMove'), [
        [
          PgCameraUpdateNewLatLngZoom(
            latLng: PgLatLng(latitude: 45, longitude: 9),
            zoom: 12,
          ),
        ],
      ]);
      expect(calls('cameraAnimate'), [
        [PgCameraUpdateZoomTo(zoom: 3), 300],
      ]);
    });

    test('updateMapOptions sends the options and reads the camera', () async {
      onHost(
        'mapUpdate',
        (_) => PgCameraPosition(
          bearing: 30,
          target: PgLatLng(latitude: 45, longitude: 9),
          tilt: 10,
          zoom: 12,
        ),
      );

      final position = await platform.updateMapOptions({
        'compassEnabled': false,
        'myLocationTrackingMode': MyLocationTrackingMode.tracking.index,
        'cameraTargetBounds': CameraTargetBounds.unbounded.toJson(),
      });

      expect(
        position,
        const CameraPosition(
          bearing: 30,
          target: LatLng(45, 9),
          tilt: 10,
          zoom: 12,
        ),
      );
      expect(calls('mapUpdate'), [
        [
          PgMapOptions(
            compassEnabled: false,
            myLocationTrackingMode: PgMyLocationTrackingMode.tracking,
            cameraTargetBounds: PgCameraTargetBounds(),
          ),
        ],
      ]);
    });

    test('the typed answers become the values of the public API', () async {
      onHost(
        'mapGetVisibleRegion',
        (_) => PgLatLngBounds(
          southwest: PgLatLng(latitude: 1, longitude: 2),
          northeast: PgLatLng(latitude: 3, longitude: 4),
        ),
      );
      onHost('mapToScreenLocation', (_) => PgScreenPoint(x: 10.5, y: 20));
      onHost('mapGetMetersPerPixelAtLatitude', (_) => 0.5);
      onHost('styleGetFilter', (_) => '["has","name"]');
      onHost('mapGetCustomHeaders', (_) => <String, String>{'X-Key': 'v'});

      expect(
        await platform.getVisibleRegion(),
        LatLngBounds(
          southwest: const LatLng(1, 2),
          northeast: const LatLng(3, 4),
        ),
      );
      expect(
        await platform.toScreenLocation(const LatLng(1, 2)),
        const Point(10.5, 20.0),
      );
      expect(await platform.getMetersPerPixelAtLatitude(45), 0.5);
      expect(await platform.getFilter('layer'), ['has', 'name']);
      expect(await platform.getCustomHeaders(), {'X-Key': 'v'});
    });

    test('the image corners cross as a quad', () async {
      onHost('styleAddImageSource', (_) => null);

      await platform.addImageSource(
        'image',
        Uint8List.fromList([1]),
        const LatLngQuad(
          topLeft: LatLng(4, 1),
          topRight: LatLng(4, 2),
          bottomRight: LatLng(3, 2),
          bottomLeft: LatLng(3, 1),
        ),
      );

      final args = calls('styleAddImageSource')!.single! as List<Object?>;
      expect(
        args[3],
        PgLatLngQuad(
          topLeft: PgLatLng(latitude: 4, longitude: 1),
          topRight: PgLatLng(latitude: 4, longitude: 2),
          bottomRight: PgLatLng(latitude: 3, longitude: 2),
          bottomLeft: PgLatLng(latitude: 3, longitude: 1),
        ),
      );
    });

    test('the creation params survive the codec of the messages', () {
      final params = PgCreationParams(
        styleString: 'https://example.com/style.json',
        options: PgMapOptions(
          compassEnabled: true,
          panInertia: PgPanInertia.none,
          myLocationStyle: PgMyLocationStyle(accuracyCircleEnabled: true),
        ),
        initialCameraPosition: PgCameraPosition(
          bearing: 0,
          target: PgLatLng(latitude: 45, longitude: 9),
          tilt: 0,
          zoom: 3,
        ),
        dragEnabled: true,
        iosLongClickDurationMs: 300,
        textureView: false,
      );

      expect(codec.decodeMessage(codec.encodeMessage(params)), params);
    });

    test('toScreenLocationBatch sends and reads a Float64List', () async {
      onHost(
        'mapToScreenLocationBatch',
        (_) => Float64List.fromList([10, 20, 30, 40]),
      );

      final points = await platform.toScreenLocationBatch(const [
        LatLng(1, 2),
        LatLng(3, 4),
      ]);

      expect(points, const [Point(10.0, 20.0), Point(30.0, 40.0)]);
      final args = calls('mapToScreenLocationBatch')!.single! as List<Object?>;
      expect(args.single, isA<Float64List>());
      expect(args.single, [1.0, 2.0, 3.0, 4.0]);
    });

    test('takeSnapshot reads a Uint8List', () async {
      onHost('mapTakeSnapshot', (_) => Uint8List.fromList([137, 80, 78, 71]));

      final bytes = await platform.takeSnapshot(width: 100);

      expect(bytes, isA<Uint8List>());
      expect(bytes, [137, 80, 78, 71]);
      expect(calls('mapTakeSnapshot'), [
        [100, null],
      ]);
    });

    test('queryRenderedFeatures reads the features', () async {
      onHost(
        'mapQueryRenderedFeaturesAtPoint',
        (_) => <Object?>['{"type":"Feature","id":1}'],
      );

      final features = await platform.queryRenderedFeatures(
        const Point(10, 20),
        ['layer'],
        null,
      );
      await platform.queryRenderedFeatures(const Point(10, 20), [], [
        'has',
        'name',
      ]);

      expect(features, [
        {'type': 'Feature', 'id': 1},
      ]);
      // The filter crosses as JSON text, and as null without one.
      expect(calls('mapQueryRenderedFeaturesAtPoint'), [
        [
          10.0,
          20.0,
          ['layer'],
          null,
        ],
        [10.0, 20.0, <String>[], '["has","name"]'],
      ]);
    });

    test('an error reply reaches Dart as a PlatformException', () async {
      onHost(
        'styleRemoveLayer',
        (_) =>
            throw PlatformException(
              code: 'LAYER_NOT_FOUND',
              message: 'No layer with id missing',
              details: {'layerId': 'missing'},
            ),
      );

      await expectLater(
        platform.removeLayer('missing'),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'LAYER_NOT_FOUND')
              .having((e) => e.message, 'message', 'No layer with id missing')
              .having((e) => e.details, 'details', {'layerId': 'missing'}),
        ),
      );
      expect(calls('styleRemoveLayer'), [
        ['missing'],
      ]);
    });

    test('an error reply to getLastLocation reads as no location', () async {
      onHost(
        'locationComponentGetLastLocation',
        (_) => throw PlatformException(code: 'NO_LOCATION'),
      );

      expect(await platform.requestMyLocationLatLng(), isNull);
    });

    test('a null reply to getLastLocation reads as no location', () async {
      onHost('locationComponentGetLastLocation', (_) => null);

      expect(await platform.requestMyLocationLatLng(), isNull);
    });

    test('getLastLocation reads the location', () async {
      onHost(
        'locationComponentGetLastLocation',
        (_) => PgLatLng(latitude: 45, longitude: 9),
      );

      expect(await platform.requestMyLocationLatLng(), const LatLng(45, 9));
    });

    test('a null reply to a non-null method is a null-error', () async {
      onHost('mapGetTelemetryEnabled', (_) => null);

      await expectLater(
        platform.getTelemetryEnabled(),
        throwsA(
          isA<PlatformException>().having((e) => e.code, 'code', 'null-error'),
        ),
      );
    });

    // No handler on the map's channel means native already released the
    // map, on both platforms.
    test('a call nothing answers fails with MAP_DISPOSED', () async {
      await expectLater(
        platform.getLayerIds(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'MAP_DISPOSED',
          ),
        ),
      );
    });

    test('each map calls on the channels of its own view', () async {
      const otherId = 8;
      final other = MapLibrePlatform.createInstance();
      addTearDown(other.dispose);
      onHost('mapWaitForMap', (_) => null, id: otherId);
      onHost('mapPause', (_) => null);
      onHost('mapPause', (_) => null, id: otherId);

      await other.initPlatform(otherId);
      await other.pauseMap();

      expect(calls('mapPause', id: otherId), [null]);
      expect(calls('mapPause'), isNull);
    });
  });

  group('events', () {
    PgLatLng pgLatLng(double latitude, double longitude) =>
        PgLatLng(latitude: latitude, longitude: longitude);

    PgCameraPosition pgCamera(double zoom) => PgCameraPosition(
      bearing: 30,
      target: pgLatLng(45, 9),
      tilt: 10,
      zoom: zoom,
    );

    test('featureOnTap, with a numeric and a string id', () async {
      final taps = <Map<String, dynamic>>[];
      platform.onFeatureTappedPlatform.add(taps.add);

      for (final id in <Object>[7, 'pin']) {
        await fromNative('featureOnTap', [
          PgFeatureTap(
            id: id,
            point: PgScreenPoint(x: 1, y: 2),
            latLng: pgLatLng(3, 4),
            layerId: 'symbols',
          ),
        ]);
      }

      expect(taps, [
        for (final id in <Object>[7, 'pin'])
          {
            'id': id,
            'point': const Point<double>(1, 2),
            'latLng': const LatLng(3, 4),
            'layerId': 'symbols',
          },
      ]);
    });

    test('featureOnDrag, with a numeric and a string id', () async {
      final drags = <Map<String, dynamic>>[];
      platform.onFeatureDraggedPlatform.add(drags.add);

      for (final (id, eventType) in [(3, 'start'), ('pin', 'drag')]) {
        await fromNative('featureOnDrag', [
          PgFeatureDrag(
            id: id,
            point: PgScreenPoint(x: 1, y: 2),
            origin: pgLatLng(10, 20),
            current: pgLatLng(11, 21),
            delta: pgLatLng(1, 1),
            eventType: eventType,
          ),
        ]);
      }

      expect(drags.map((drag) => [drag['id'], drag['eventType']]), [
        [3, 'start'],
        ['pin', 'drag'],
      ]);
      expect(drags.first, {
        'id': 3,
        'point': const Point<double>(1, 2),
        'origin': const LatLng(10, 20),
        'current': const LatLng(11, 21),
        'delta': const LatLng(1, 1),
        'eventType': 'start',
      });
    });

    test('the camera events', () async {
      final moveStarts = <CameraMoveReason>[];
      final moves = <CameraPosition?>[];
      final idles = <CameraPosition?>[];
      platform.onCameraMoveStartedPlatform.add(moveStarts.add);
      platform.onCameraMovePlatform.add(moves.add);
      platform.onCameraIdlePlatform.add(idles.add);

      await fromNative('cameraOnMoveStarted', [true]);
      await fromNative('cameraOnMoveStarted', [false]);
      await fromNative('cameraOnMove', [pgCamera(12)]);
      await fromNative('cameraOnIdle', [pgCamera(13)]);
      // Without a position when the map does not track the camera.
      await fromNative('cameraOnIdle', [null]);

      const position = CameraPosition(
        bearing: 30,
        target: LatLng(45, 9),
        tilt: 10,
        zoom: 12,
      );
      expect(moveStarts, [
        CameraMoveReason.gesture,
        CameraMoveReason.programmatic,
      ]);
      expect(moves, [position]);
      expect(idles, [
        const CameraPosition(
          bearing: 30,
          target: LatLng(45, 9),
          tilt: 10,
          zoom: 13,
        ),
        null,
      ]);
    });

    test('the map events', () async {
      final events = <String>[];
      final clicks = <Map<String, dynamic>>[];
      final modes = <MyLocationTrackingMode>[];
      platform.onMapStyleLoadedPlatform.add((_) => events.add('style'));
      platform.onMapIdlePlatform.add((_) => events.add('idle'));
      platform.onCameraTrackingDismissedPlatform.add(
        (_) => events.add('dismissed'),
      );
      platform.onCameraTrackingChangedPlatform.add(modes.add);
      platform.onMapClickPlatform.add(clicks.add);
      platform.onMapLongClickPlatform.add(clicks.add);

      await fromNative('mapOnStyleLoaded', null);
      await fromNative('mapOnIdle', null);
      await fromNative('mapOnCameraTrackingChanged', [
        PgMyLocationTrackingMode.trackingGps,
      ]);
      await fromNative('mapOnCameraTrackingDismissed', null);
      await fromNative('mapOnMapClick', [
        PgScreenPoint(x: 1, y: 2),
        pgLatLng(3, 4),
      ]);
      await fromNative('mapOnMapLongClick', [
        PgScreenPoint(x: 5, y: 6),
        pgLatLng(7, 8),
      ]);

      expect(events, ['style', 'idle', 'dismissed']);
      expect(modes, [MyLocationTrackingMode.trackingGps]);
      expect(clicks, [
        {'point': const Point<double>(1, 2), 'latLng': const LatLng(3, 4)},
        {'point': const Point<double>(5, 6), 'latLng': const LatLng(7, 8)},
      ]);
    });

    test('mapOnUserLocationUpdated, with and without a heading', () async {
      final locations = <UserLocation>[];
      platform.onUserLocationUpdatedPlatform.add(locations.add);
      final location = PgUserLocation(
        position: pgLatLng(45, 9),
        altitude: 120,
        bearing: 90,
        speed: 3,
        horizontalAccuracy: 5,
        verticalAccuracy: 6,
        timestamp: 1000,
      );

      await fromNative('mapOnUserLocationUpdated', [
        location,
        PgUserHeading(
          magneticHeading: 10,
          trueHeading: 12,
          headingAccuracy: 1,
          x: 0.1,
          y: 0.2,
          z: 0.3,
          timestamp: 2000,
        ),
      ]);
      await fromNative('mapOnUserLocationUpdated', [location, null]);

      expect(locations, hasLength(2));
      final withHeading = locations.first;
      expect(withHeading.position, const LatLng(45, 9));
      expect(
        [
          withHeading.altitude,
          withHeading.bearing,
          withHeading.speed,
          withHeading.horizontalAccuracy,
          withHeading.verticalAccuracy,
        ],
        [120.0, 90.0, 3.0, 5.0, 6.0],
      );
      expect(withHeading.timestamp, DateTime.fromMillisecondsSinceEpoch(1000));
      final heading = withHeading.heading!;
      expect(
        [
          heading.magneticHeading,
          heading.trueHeading,
          heading.headingAccuracy,
          heading.x,
          heading.y,
          heading.z,
        ],
        [10.0, 12.0, 1.0, 0.1, 0.2, 0.3],
      );
      expect(heading.timestamp, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(locations.last.heading, isNull);
      expect(locations.last.position, const LatLng(45, 9));
    });

    test('every event is answered with an empty success envelope', () async {
      expect(await fromNative('mapOnIdle', null), isEmpty);
      expect(await fromNative('cameraOnIdle', [null]), isEmpty);
    });

    test('the events of another map do not reach this one', () async {
      var idles = 0;
      platform.onMapIdlePlatform.add((_) => idles++);

      expect(await fromNative('mapOnIdle', null, id: 8), isNull);
      expect(idles, 0);
    });
  });

  group('channel names', () {
    // The names the native handlers listen on. A rename in
    // pigeons/messages.dart changes the generated code of every language at
    // once, but breaks the hand-written native implementations, so it has to
    // show up here as a deliberate change. Comparing the three generated files
    // also catches one of them generated from a different schema.
    const hostMethods = [
      'mapWaitForMap',
      'mapUpdate',
      'cameraAnimate',
      'cameraMove',
      'mapUpdateMyLocationTrackingMode',
      'locationComponentSetTrackingCameraOptions',
      'locationComponentSetManualLocation',
      'mapMatchMapLanguageWithDeviceDefault',
      'mapUpdateContentInsets',
      'mapSetMapLanguage',
      'mapSetTelemetryEnabled',
      'mapGetTelemetryEnabled',
      'mapSetMaximumFps',
      'mapForceOnlineMode',
      'mapPause',
      'mapResume',
      'cameraEase',
      'mapQueryCameraPosition',
      'mapEditGeoJsonSource',
      'mapEditGeoJsonUrl',
      'mapSetLayerFilter',
      'mapGetStyle',
      'mapSetCustomHeaders',
      'mapGetCustomHeaders',
      'mapQueryRenderedFeaturesAtPoint',
      'mapQueryRenderedFeaturesInRect',
      'mapQuerySourceFeatures',
      'sourceGetClusterExpansionZoom',
      'sourceGetClusterChildren',
      'sourceGetClusterLeaves',
      'mapInvalidateAmbientCache',
      'mapClearAmbientCache',
      'locationComponentGetLastLocation',
      'mapGetVisibleRegion',
      'styleAddImage',
      'styleAddImageSource',
      'styleUpdateImageSource',
      'mapToScreenLocation',
      'mapToScreenLocationBatch',
      'styleRemoveSource',
      'styleAddLayer',
      'styleAddLayerBelow',
      'styleRemoveLayer',
      'styleMoveLayer',
      'styleSetFilter',
      'styleGetFilter',
      'mapToLatLng',
      'mapGetMetersPerPixelAtLatitude',
      'sourceAddGeoJson',
      'sourceSetGeoJson',
      'mapSetCameraBounds',
      'symbolLayerAdd',
      'lineLayerAdd',
      'layerSetProperties',
      'circleLayerAdd',
      'fillLayerAdd',
      'fillExtrusionLayerAdd',
      'styleAddSource',
      'rasterLayerAdd',
      'hillshadeLayerAdd',
      'colorReliefLayerAdd',
      'backgroundLayerAdd',
      'heatmapLayerAdd',
      'sourceSetFeature',
      'sourceSetFeatureState',
      'sourceRemoveFeatureState',
      'sourceGetFeatureState',
      'styleSetLight',
      'layerSetVisibility',
      'layerSetVisibilityBatch',
      'layerSetZoomRange',
      'layerGetVisibility',
      'mapTakeSnapshot',
      'styleGetLayerIds',
      'styleGetSourceIds',
      'styleGetLayerProperties',
      'styleGetSourceProperties',
      'styleSetStyle',
    ];
    const flutterEvents = [
      'featureOnTap',
      'featureOnDrag',
      'cameraOnMoveStarted',
      'cameraOnMove',
      'cameraOnIdle',
      'mapOnStyleLoaded',
      'mapOnMapClick',
      'mapOnMapLongClick',
      'mapOnCameraTrackingChanged',
      'mapOnCameraTrackingDismissed',
      'mapOnIdle',
      'mapOnUserLocationUpdated',
    ];
    const generated = {
      'Dart': 'lib/src/native/messages.g.dart',
      'Kotlin': 'android/src/main/java/org/maplibre/maplibregl/Messages.g.kt',
      'Swift': 'ios/maplibre_gl/Sources/maplibre_gl/Messages.g.swift',
    };

    /// The method names after `<api>.` in the channel names of [path].
    List<String> channelsIn(String path, String api) {
      final source = File(path).readAsStringSync();
      return RegExp(
        'dev\\.flutter\\.pigeon\\.maplibre_gl\\.$api\\.(\\w+)',
      ).allMatches(source).map((match) => match[1]!).toSet().toList();
    }

    test('the list has no duplicates', () {
      expect(hostMethods.toSet(), hasLength(hostMethods.length));
      expect(flutterEvents.toSet(), hasLength(flutterEvents.length));
    });

    for (final MapEntry(key: language, value: path) in generated.entries) {
      test('the $language MapLibreMapHostApi channels are the listed ones', () {
        expect(
          channelsIn(path, 'MapLibreMapHostApi'),
          unorderedEquals(hostMethods),
        );
      });

      test('the $language MapLibreMapFlutterApi channels are the listed '
          'ones', () {
        expect(
          channelsIn(path, 'MapLibreMapFlutterApi'),
          unorderedEquals(flutterEvents),
        );
      });
    }

    test('the Dart client sends on the listed name and the view id', () async {
      onHost('styleGetLayerIds', (_) => <Object?>[]);

      await platform.getLayerIds();

      expect(received.keys, contains('$hostApi.styleGetLayerIds.$viewId'));
    });
  });
}
