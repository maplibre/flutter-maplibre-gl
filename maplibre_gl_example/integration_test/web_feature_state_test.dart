// Integration test for feature state on web.
//
// All three calls cross into maplibre-gl-js, and two of them were broken from
// 0.26.0 until 0.27.0 in ways no unit test could see: `getFeatureState` threw
// on a bad cast, and `removeFeatureState` with no feature id built a target
// that cleared nothing. Both need a live map to reproduce, so they are driven
// here rather than mocked.
//
// Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/web_feature_state_test.dart \
//     -d web-server --browser-name=chrome
//
// The assertions only run on web; elsewhere the test is a no-op so the suite
// stays green everywhere.
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const _sourceId = 'probe';
const _layerId = 'probe-fill';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('set, read, remove one key, reset the whole source', (
    tester,
  ) async {
    if (!kIsWeb) return;

    final controller = await _pumpMapWithSource(tester);

    // No state yet: the contract is null, not an empty map, so an app can tell
    // "nothing set" from "set to nothing". maplibre-gl-js answers {} here.
    expect(await controller.getFeatureState(_sourceId, '1'), isNull);

    await controller.setFeatureState(_sourceId, '1', {
      'selected': true,
      'score': 7,
    });
    expect(await controller.getFeatureState(_sourceId, '1'), {
      'selected': true,
      'score': 7,
    });

    // One key off the feature, the rest untouched.
    await controller.removeFeatureState(
      _sourceId,
      featureId: '1',
      stateKey: 'selected',
    );
    expect(await controller.getFeatureState(_sourceId, '1'), {'score': 7});

    // A key with no feature to take it from is rejected, as on Android, rather
    // than quietly doing nothing.
    await expectLater(
      controller.removeFeatureState(_sourceId, stateKey: 'score'),
      throwsA(isA<PlatformException>()),
    );
    expect(await controller.getFeatureState(_sourceId, '1'), {'score': 7});

    // The bare call resets every feature of the source.
    await controller.setFeatureState(_sourceId, '2', {'selected': true});
    await controller.removeFeatureState(_sourceId);
    expect(await controller.getFeatureState(_sourceId, '1'), isNull);
    expect(await controller.getFeatureState(_sourceId, '2'), isNull);
  });
}

/// Builds a map with a two-feature GeoJSON source and a layer that renders it,
/// and returns its controller once the source is in the style.
Future<MapLibreMapController> _pumpMapWithSource(WidgetTester tester) async {
  final controllerCompleter = Completer<MapLibreMapController>();
  final styleLoaded = Completer<void>();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: MapLibreMap(
            styleString: MapLibreStyles.demo,
            initialCameraPosition: const CameraPosition(
              target: LatLng(0, 0),
              zoom: 3,
            ),
            onMapCreated: controllerCompleter.complete,
            onStyleLoadedCallback: () {
              if (!styleLoaded.isCompleted) styleLoaded.complete();
            },
          ),
        ),
      ),
    ),
  );

  final controller = await _await(
    tester,
    controllerCompleter.future,
    'onMapCreated',
  );
  await _await(tester, styleLoaded.future, 'onStyleLoaded');

  await controller.addGeoJsonSource(_sourceId, {
    'type': 'FeatureCollection',
    'features': [
      for (var id = 1; id <= 2; id++)
        {
          'type': 'Feature',
          'id': id,
          'geometry': {
            'type': 'Point',
            'coordinates': [id.toDouble(), 0.0],
          },
          'properties': <String, dynamic>{},
        },
    ],
  });
  await controller.addCircleLayer(
    _sourceId,
    _layerId,
    const CircleLayerProperties(circleRadius: 12),
  );
  return controller;
}

/// Awaits [future] while pumping frames, failing with [label] on timeout.
Future<T> _await<T>(
  WidgetTester tester,
  Future<T> future,
  String label, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  var done = false;
  T? result;
  unawaited(
    future.then((value) {
      done = true;
      result = value;
    }),
  );
  while (!done) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $label');
    await tester.pump(const Duration(milliseconds: 100));
  }
  return result as T;
}
