// Shared helpers for the integration tests that drive a real map on Android,
// iOS and web.
//
// Every test builds its map from [offlineStyle], an inline style with no
// remote sources, glyphs or sprites, so a run never depends on the network
// and every platform starts from the same style. Data the test needs (GeoJSON
// sources, layers, images) is added through the controller, which is the code
// under test.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// The platform the test runs on, for the few contracts that differ by
/// platform.
enum TestPlatform { android, ios, web }

TestPlatform get testPlatform {
  if (kIsWeb) return TestPlatform.web;
  return defaultTargetPlatform == TargetPlatform.iOS
      ? TestPlatform.ios
      : TestPlatform.android;
}

/// Id of the single layer in [offlineStyle].
const String backgroundLayerId = 'background';

/// A style with one background layer and nothing that needs the network.
final String offlineStyle = jsonEncode({
  'version': 8,
  'name': 'integration-test',
  'sources': <String, dynamic>{},
  'layers': [
    {
      'id': backgroundLayerId,
      'type': 'background',
      'paint': {'background-color': '#dddddd'},
    },
  ],
});

/// A GeoJSON FeatureCollection of points with numeric ids 1..[count], placed
/// one degree apart along the equator, each with `{'n': id}` as properties.
Map<String, dynamic> pointCollection({int count = 3, double lat = 0}) => {
  'type': 'FeatureCollection',
  'features': [
    for (var id = 1; id <= count; id++)
      {
        'type': 'Feature',
        'id': id,
        'geometry': {
          'type': 'Point',
          'coordinates': [id.toDouble(), lat],
        },
        'properties': {'n': id},
      },
  ],
};

/// Pumps a [MapLibreMap] that fills a [size] box and returns its controller
/// once the style has loaded.
///
/// Extra widget arguments a test needs can be passed through [builder], which
/// receives the callbacks the harness relies on and must forward them.
Future<MapLibreMapController> pumpMap(
  WidgetTester tester, {
  String? styleString,
  CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(0, 0),
    zoom: 3,
  ),
  Size size = const Size(400, 400),
  MapLibreMap Function(
    MapCreatedCallback onMapCreated,
    OnStyleLoadedCallback onStyleLoaded,
  )?
  builder,
}) async {
  final controllerCompleter = Completer<MapLibreMapController>();
  final styleLoaded = Completer<void>();

  void onMapCreated(MapLibreMapController controller) {
    if (!controllerCompleter.isCompleted) {
      controllerCompleter.complete(controller);
    }
  }

  void onStyleLoaded() {
    if (!styleLoaded.isCompleted) styleLoaded.complete();
  }

  final map =
      builder?.call(onMapCreated, onStyleLoaded) ??
      MapLibreMap(
        styleString: styleString ?? offlineStyle,
        initialCameraPosition: initialCameraPosition,
        onMapCreated: onMapCreated,
        onStyleLoadedCallback: onStyleLoaded,
      );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: size.width, height: size.height, child: map),
        ),
      ),
    ),
  );

  final controller = await pumpUntil(
    tester,
    controllerCompleter.future,
    'onMapCreated',
  );
  await pumpUntil(tester, styleLoaded.future, 'onStyleLoaded');
  return controller;
}

/// Awaits [future] while pumping frames, failing with [label] if it does not
/// complete within [timeout]. Platform calls only make progress while frames
/// are pumped, so a bare `await` can hang the whole suite on a stuck map.
Future<T> pumpUntil<T>(
  WidgetTester tester,
  Future<T> future,
  String label, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  // A caller already pumping (for example a pumpUntilValue reader that wraps
  // its own call) keeps frames going; pumping again here would run two
  // tester.pump calls at once, which flutter_test rejects.
  if (_pumping) {
    return future.timeout(
      timeout,
      onTimeout: () => fail('Timed out waiting for $label'),
    );
  }
  _pumping = true;
  try {
    return await _pumpUntil(future, tester, label, timeout);
  } finally {
    _pumping = false;
  }
}

bool _pumping = false;

Future<T> _pumpUntil<T>(
  Future<T> future,
  WidgetTester tester,
  String label,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  var done = false;
  Object? error;
  StackTrace? stack;
  T? result;
  unawaited(
    future.then(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    ),
  );
  while (!done) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $label');
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (error != null) await Future<Never>.error(error!, stack);
  return result as T;
}

/// Pumps frames for [duration], for state that settles asynchronously (a
/// camera animation, a render pass before a query).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Polls [read] while pumping frames until [accept] holds, returning the last
/// value read. Fails with [label] after [timeout]. Use it for results that
/// depend on rendering, such as rendered-feature queries.
Future<T> pumpUntilValue<T>(
  WidgetTester tester,
  Future<T> Function() read,
  bool Function(T value) accept,
  String label, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final value = await pumpUntil(tester, read(), label);
    if (accept(value)) return value;
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $label (last value: $value)');
    }
    await pumpFor(tester, const Duration(milliseconds: 200));
  }
}

/// Expects [future] to fail with a [PlatformException], optionally with
/// [code]. Returns the exception for further checks.
Future<PlatformException> expectPlatformError(
  WidgetTester tester,
  Future<Object?> future,
  String label, {
  String? code,
}) async {
  try {
    await pumpUntil(tester, future, label);
  } on PlatformException catch (e) {
    if (code != null) {
      expect(e.code, code, reason: '$label: ${e.message}');
    }
    return e;
  }
  fail('$label: expected a PlatformException, the call succeeded');
}
