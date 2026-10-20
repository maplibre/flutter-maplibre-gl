// Integration tests for whole-style and miscellaneous map calls.
//
// Covered: replacing the style at runtime (setStyle and a new styleString on
// a rebuilt widget), reading it back (getStyle), image sources and image
// layers, the style root objects (light, sky, terrain, projection, global
// state), snapshots, the rendering controls (max fps, pause and resume),
// telemetry, map language, the wait helpers and clearing the ambient cache.
//
// Each of these either reloads the native style, reads it back from the
// renderer or talks to the platform's file source, so none of it can be
// checked against a mock: a real map has to be on screen.
//
// The style assets of the example app (assets/*.json) all point at remote
// tiles, glyphs or PMTiles, so loading a style from an asset path is not
// covered here: it would make the run depend on the network.
//
// Run on Android or iOS:
//   flutter test integration_test/style_misc_test.dart -d <device id>
//
// Run on Chrome (with chromedriver on :4444):
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/style_misc_test.dart \
//     -d chrome
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _secondBackgroundId = 'second-background';
const _secondSourceId = 'second-source';
const _secondLayerId = 'second-points';

/// A second offline style, different from [offlineStyle] in every id, so a
/// test can tell which of the two is loaded.
final String _secondStyle = jsonEncode({
  'version': 8,
  'name': 'integration-test-second',
  'sources': {
    _secondSourceId: {'type': 'geojson', 'data': pointCollection()},
  },
  'layers': [
    {
      'id': _secondBackgroundId,
      'type': 'background',
      'paint': {'background-color': '#88aacc'},
    },
    {'id': _secondLayerId, 'type': 'circle', 'source': _secondSourceId},
  ],
});

/// Corners of an image source a few degrees around the camera target.
const _quad = LatLngQuad(
  topLeft: LatLng(2, -2),
  topRight: LatLng(2, 2),
  bottomRight: LatLng(-2, 2),
  bottomLeft: LatLng(-2, -2),
);

const _movedQuad = LatLngQuad(
  topLeft: LatLng(4, -4),
  topRight: LatLng(4, 4),
  bottomRight: LatLng(-4, 4),
  bottomLeft: LatLng(-4, -4),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setStyle replaces the whole style and reports a new load', (
    tester,
  ) async {
    final loads = _StyleLoads();
    final controller = await pumpMap(
      tester,
      builder:
          (onMapCreated, onStyleLoaded) => MapLibreMap(
            styleString: offlineStyle,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 3,
            ),
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: () {
              onStyleLoaded();
              loads.onLoaded();
            },
          ),
    );
    expect(loads.count, 1);

    // Runtime additions belong to the style they were added to, so the new
    // style must not inherit them.
    await pumpUntil(
      tester,
      controller.addGeoJsonSource('probe', pointCollection()),
      'addGeoJsonSource',
    );
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        'probe',
        'probe-circles',
        const CircleLayerProperties(circleColor: '#ff0000'),
      ),
      'addCircleLayer',
    );

    final reloaded = loads.next;
    await pumpUntil(tester, controller.setStyle(_secondStyle), 'setStyle');
    await pumpUntil(tester, reloaded, 'onStyleLoaded after setStyle');
    expect(loads.count, 2);

    final layerIds = await pumpUntil(
      tester,
      controller.getLayerIds(),
      'getLayerIds',
    );
    expect(layerIds, containsAll([_secondBackgroundId, _secondLayerId]));
    expect(layerIds, isNot(contains(backgroundLayerId)));
    expect(layerIds, isNot(contains('probe-circles')));

    final sourceIds = await pumpUntil(
      tester,
      controller.getSourceIds(),
      'getSourceIds',
    );
    expect(sourceIds, contains(_secondSourceId));
    expect(sourceIds, isNot(contains('probe')));
  });

  testWidgets('getStyle returns the loaded style as JSON', (tester) async {
    final loads = _StyleLoads();
    final controller = await pumpMap(
      tester,
      builder:
          (onMapCreated, onStyleLoaded) => MapLibreMap(
            styleString: offlineStyle,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 3,
            ),
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: () {
              onStyleLoaded();
              loads.onLoaded();
            },
          ),
    );

    final initial = await _readStyle(tester, controller);
    expect(initial['version'], 8);
    expect(_layerIdsOf(initial), contains(backgroundLayerId));

    // After a swap the answer follows the style on screen, not the first one.
    final reloaded = loads.next;
    await pumpUntil(tester, controller.setStyle(_secondStyle), 'setStyle');
    await pumpUntil(tester, reloaded, 'onStyleLoaded after setStyle');

    final swapped = await _readStyle(tester, controller);
    expect(
      _layerIdsOf(swapped),
      containsAll([_secondBackgroundId, _secondLayerId]),
    );
    expect(_layerIdsOf(swapped), isNot(contains(backgroundLayerId)));
  });

  testWidgets('image sources and image layers: add, update, order, remove', (
    tester,
  ) async {
    final controller = await pumpMap(tester);
    final first = await _loadPng(tester, 'assets/sydney0.png');
    final second = await _loadPng(tester, 'assets/sydney1.png');

    if (testPlatform == TestPlatform.web) {
      // Not implemented in the web plugin (documented on addImageSource and
      // updateImageSource). The calls throw before reaching maplibre-gl-js.
      await _expectThrows<UnimplementedError>(
        tester,
        Future.sync(() => controller.addImageSource('image', first, _quad)),
        'addImageSource',
      );
      await _expectThrows<UnimplementedError>(
        tester,
        Future.sync(() => controller.updateImageSource('image', second, null)),
        'updateImageSource',
      );
      await _expectThrows<UnimplementedError>(
        tester,
        Future.sync(() => controller.addImageLayer('image-layer', 'image')),
        'addImageLayer',
      );
      await _expectThrows<UnimplementedError>(
        tester,
        Future.sync(
          () => controller.addImageLayerBelow(
            'image-below',
            'image',
            backgroundLayerId,
          ),
        ),
        'addImageLayerBelow',
      );
      return;
    }

    await pumpUntil(
      tester,
      controller.addImageSource('image', first, _quad),
      'addImageSource',
    );
    expect(
      await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
      contains('image'),
    );

    // Image and coordinates can each be replaced on their own.
    await pumpUntil(
      tester,
      controller.updateImageSource('image', second, null),
      'updateImageSource (image)',
    );
    await pumpUntil(
      tester,
      controller.updateImageSource('image', null, _movedQuad),
      'updateImageSource (coordinates)',
    );

    await pumpUntil(
      tester,
      controller.addImageLayer('image-layer', 'image'),
      'addImageLayer',
    );
    // The second and third arguments are the image source and the layer to
    // insert below, whatever their parameter names say.
    await pumpUntil(
      tester,
      controller.addImageLayerBelow('image-below', 'image', 'image-layer'),
      'addImageLayerBelow',
    );

    final layerIds = await pumpUntil(
      tester,
      controller.getLayerIds(),
      'getLayerIds',
    );
    expect(layerIds, containsAll(['image-layer', 'image-below']));
    expect(
      layerIds.indexOf('image-below'),
      lessThan(layerIds.indexOf('image-layer')),
      reason: 'addImageLayerBelow must insert under the given layer',
    );

    // Layers first: a source still in use by a layer cannot be removed.
    await pumpUntil(
      tester,
      controller.removeLayer('image-below'),
      'removeLayer (below)',
    );
    await pumpUntil(
      tester,
      controller.removeLayer('image-layer'),
      'removeLayer',
    );
    await pumpUntil(tester, controller.removeSource('image'), 'removeSource');

    expect(
      await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
      isNot(anyOf(contains('image-layer'), contains('image-below'))),
    );
    expect(
      await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
      isNot(contains('image')),
    );
  });

  testWidgets('setLight takes constants everywhere, expressions on web only', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    await pumpUntil(
      tester,
      controller.setLight(
        const LightProperties(
          anchor: 'map',
          position: [1.5, 90.0, 80.0],
          color: '#ff0000',
          intensity: 0.4,
        ),
      ),
      'setLight (constants)',
    );

    const expressionLight = LightProperties(
      intensity: [
        'interpolate',
        ['linear'],
        ['zoom'],
        0,
        0.2,
        10,
        0.8,
      ],
    );
    if (testPlatform == TestPlatform.web) {
      await pumpUntil(
        tester,
        controller.setLight(expressionLight),
        'setLight (expression)',
      );
    } else {
      // Documented on setLight: MapLibre Native takes constant values only,
      // so an expression is rejected rather than silently dropped.
      await expectPlatformError(
        tester,
        controller.setLight(expressionLight),
        'setLight (expression)',
        code: 'INVALID_ARGUMENT',
      );
    }
  });

  testWidgets('sky, terrain, projection and global state: web applies them, '
      'native rejects them as unsupported', (tester) async {
    final controller = await pumpMap(tester);

    const sky = SkyProperties(skyColor: '#3366ff', horizonColor: '#ffffff');

    if (testPlatform != TestPlatform.web) {
      // Documented on each call: MapLibre Native has none of these root
      // objects, so the method channel refuses before reaching the platform.
      await _expectThrows<UnsupportedError>(
        tester,
        controller.setSky(sky),
        'setSky',
      );
      await _expectThrows<UnsupportedError>(
        tester,
        controller.setTerrain(null),
        'setTerrain(null)',
      );
      await _expectThrows<UnsupportedError>(
        tester,
        controller.setProjection('globe'),
        'setProjection',
      );
      await _expectThrows<UnsupportedError>(
        tester,
        controller.setGlobalStateProperty('highlight', true),
        'setGlobalStateProperty',
      );
      return;
    }

    await pumpUntil(tester, controller.setSky(sky), 'setSky');
    // Null removes the terrain; with none set it must still be accepted.
    await pumpUntil(tester, controller.setTerrain(null), 'setTerrain(null)');
    await pumpUntil(
      tester,
      controller.setGlobalStateProperty('highlight', true),
      'setGlobalStateProperty',
    );

    await pumpUntil(
      tester,
      controller.setProjection('globe'),
      'setProjection(globe)',
    );
    var style = await _readStyle(tester, controller);
    expect((style['projection'] as Map?)?['type'], 'globe');

    await pumpUntil(
      tester,
      controller.setProjection('mercator'),
      'setProjection(mercator)',
    );
    style = await _readStyle(tester, controller);
    expect((style['projection'] as Map?)?['type'], 'mercator');
  });

  testWidgets('takeSnapshot returns PNG bytes', (tester) async {
    final controller = await pumpMap(tester);
    // Let the first frames land so the snapshot has something to capture.
    await pumpFor(tester, const Duration(milliseconds: 500));

    final bytes = await pumpUntil(
      tester,
      controller.takeSnapshot(),
      'takeSnapshot',
    );
    expect(bytes.length, greaterThan(8));
    // PNG signature: 0x89 'P' 'N' 'G'.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  testWidgets('setMaximumFps, pauseMap and resumeMap keep the map usable', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    await pumpUntil(tester, controller.setMaximumFps(30), 'setMaximumFps');

    // Pausing stops rendering only: style calls still answer while paused.
    await pumpUntil(tester, controller.pauseMap(), 'pauseMap');
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(
      await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds paused'),
      contains(backgroundLayerId),
    );
    await pumpUntil(tester, controller.resumeMap(), 'resumeMap');

    // Resuming twice is harmless, as is a second fps change after resume.
    await pumpUntil(tester, controller.resumeMap(), 'resumeMap again');
    await pumpUntil(tester, controller.setMaximumFps(60), 'setMaximumFps 60');

    await pumpUntil(
      tester,
      controller.moveCamera(CameraUpdate.zoomTo(4)),
      'moveCamera after resume',
    );
  });

  testWidgets('telemetry reads back as disabled after disabling it', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    // Only false is written: on iOS the flag is persisted in UserDefaults and
    // would outlive the test.
    await pumpUntil(
      tester,
      controller.setTelemetryEnabled(false),
      'setTelemetryEnabled',
    );
    expect(
      await pumpUntil(
        tester,
        controller.getTelemetryEnabled(),
        'getTelemetryEnabled',
      ),
      isFalse,
    );
  });

  testWidgets('map language calls complete on a style without labels', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    // The offline style has no symbol layers, so there is nothing to rewrite;
    // the calls must still succeed rather than fail on the empty case.
    await pumpUntil(tester, controller.setMapLanguage('it'), 'setMapLanguage');
    await pumpUntil(
      tester,
      controller.matchMapLanguageWithDeviceDefault(),
      'matchMapLanguageWithDeviceDefault',
    );
    expect(
      await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
      contains(backgroundLayerId),
    );
  });

  testWidgets('wait helpers complete after a move and with no tiles to load', (
    tester,
  ) async {
    final controller = await pumpMap(tester);

    // Start waiting before the move: on web the helper listens for the next
    // idle event, which the move itself may already have produced by the time
    // a later call registers.
    final idle = controller.waitUntilMapIsIdleAfterMovement();
    await pumpUntil(
      tester,
      controller.moveCamera(
        CameraUpdate.newCameraPosition(
          const CameraPosition(target: LatLng(10, 10), zoom: 4),
        ),
      ),
      'moveCamera',
    );
    await pumpUntil(tester, idle, 'waitUntilMapIsIdleAfterMovement');

    // The offline style has no tiled sources, so there is nothing to wait for.
    await pumpUntil(
      tester,
      controller.waitUntilMapTilesAreLoaded(),
      'waitUntilMapTilesAreLoaded',
    );
  });

  testWidgets('clearAmbientCache completes on native, has no web handler', (
    tester,
  ) async {
    // A map is pumped so the native plugin is attached on every platform.
    await pumpMap(tester);

    if (testPlatform == TestPlatform.web) {
      // There is no offline support on web (documented in global.dart) and no
      // handler for the global channel, so the call fails as unhandled.
      await _expectThrows<MissingPluginException>(
        tester,
        clearAmbientCache(),
        'clearAmbientCache',
      );
      return;
    }
    await pumpUntil(tester, clearAmbientCache(), 'clearAmbientCache');
  });

  testWidgets(
    'rebuilding the widget with a new styleString reloads the style',
    (tester) async {
      final loads = _StyleLoads();
      final created = Completer<MapLibreMapController>();

      MapLibreMap buildMap({
        required String style,
        required bool gestures,
      }) => MapLibreMap(
        styleString: style,
        initialCameraPosition: const CameraPosition(
          target: LatLng(0, 0),
          zoom: 3,
        ),
        rotateGesturesEnabled: gestures,
        tiltGesturesEnabled: gestures,
        zoomGesturesEnabled: gestures,
        compassEnabled: gestures,
        onMapCreated: (controller) {
          if (!created.isCompleted) created.complete(controller);
        },
        onStyleLoadedCallback: loads.onLoaded,
      );

      final firstLoad = loads.next;
      await tester.pumpWidget(
        _mapApp(buildMap(style: offlineStyle, gestures: true)),
      );
      final controller = await pumpUntil(
        tester,
        created.future,
        'onMapCreated',
      );
      await pumpUntil(tester, firstLoad, 'onStyleLoaded');

      // Same tree shape, so the map state is kept and only its options change.
      final secondLoad = loads.next;
      await tester.pumpWidget(
        _mapApp(buildMap(style: _secondStyle, gestures: false)),
      );
      await pumpUntil(tester, secondLoad, 'onStyleLoaded after rebuild');
      expect(loads.count, 2);

      final layerIds = await pumpUntil(
        tester,
        controller.getLayerIds(),
        'getLayerIds',
      );
      expect(layerIds, contains(_secondBackgroundId));
      expect(layerIds, isNot(contains(backgroundLayerId)));

      // Flipping the gesture flags back must not disturb the loaded style.
      await tester.pumpWidget(
        _mapApp(buildMap(style: _secondStyle, gestures: true)),
      );
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(loads.count, 2);
    },
  );
}

/// Counts style loads and hands out a future for the next one.
class _StyleLoads {
  int count = 0;
  Completer<void> _next = Completer<void>();

  /// Completes on the next style load after this getter is read.
  Future<void> get next => _next.future;

  void onLoaded() {
    count++;
    final current = _next;
    _next = Completer<void>();
    current.complete();
  }
}

/// The same tree [pumpMap] builds, so pumping it again updates the map in
/// place instead of creating a new one.
Widget _mapApp(MapLibreMap map) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 400, height: 400, child: map),
    ),
  ),
);

/// Reads the style through getStyle and decodes it.
Future<Map<String, dynamic>> _readStyle(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final json = await pumpUntil(tester, controller.getStyle(), 'getStyle');
  expect(json, isNotNull, reason: 'getStyle returned null');
  return (jsonDecode(json!) as Map).cast<String, dynamic>();
}

List<Object?> _layerIdsOf(Map<String, dynamic> style) => [
  for (final layer in style['layers'] as List) (layer as Map)['id'],
];

Future<Uint8List> _loadPng(WidgetTester tester, String asset) async {
  final data = await pumpUntil(tester, rootBundle.load(asset), 'load $asset');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Expects [future] to fail with an [E]. Other errors propagate, so a wrong
/// error type fails the test with the real cause.
Future<void> _expectThrows<E extends Object>(
  WidgetTester tester,
  Future<Object?> future,
  String label,
) async {
  try {
    await pumpUntil(tester, future, label);
  } on E {
    return;
  }
  fail('$label: expected $E, the call succeeded');
}
