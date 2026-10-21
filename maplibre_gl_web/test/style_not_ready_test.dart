// Drives the style and source calls of the web controller before any style has
// loaded, against a stand-in for maplibre-gl-js that records what it is asked,
// so it needs a browser, but never the library itself:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

/// Android and iOS answer these calls with STYLE_NOT_READY, and this message,
/// until the style has loaded. maplibre-gl-js throws an error of its own for
/// most of them, or ignores them.
void main() {
  /// A map that records the name of every method called on it.
  JSObject recordingMap(List<String> calls) {
    final map = JSObject();
    for (final name in [
      'addSource',
      'addLayer',
      'getSource',
      'getLayer',
      'on',
      'off',
    ]) {
      map.setProperty(
        name.toJS,
        (() {
          calls.add(name);
        }).toJS,
      );
    }
    return map;
  }

  const quad = LatLngQuad(
    topLeft: LatLng(2, -2),
    topRight: LatLng(2, 2),
    bottomRight: LatLng(-2, 2),
    bottomLeft: LatLng(-2, -2),
  );
  final bytes = Uint8List(4);

  final calls = <String, Future<void> Function(MapLibreMapController)>{
    'addImageSource': (c) => c.addImageSource('image', bytes, quad),
    'updateImageSource': (c) => c.updateImageSource('image', bytes, quad),
    'addLayer (image)': (c) => c.addLayer('image-layer', 'image', null, null),
    'addLayerBelow (image)':
        (c) => c.addLayerBelow('image-layer', 'image', 'below', null, null),
    'addGeoJsonSource':
        (c) => c.addGeoJsonSource('points', {
          'type': 'FeatureCollection',
          'features': <Object>[],
        }),
    'setGeoJsonSource':
        (c) => c.setGeoJsonSource('points', {
          'type': 'FeatureCollection',
          'features': <Object>[],
        }),
    'setFeatureForGeoJsonSource':
        (c) => c.setFeatureForGeoJsonSource('points', {
          'type': 'Feature',
          'id': 1,
          'geometry': {
            'type': 'Point',
            'coordinates': [0, 0],
          },
        }),
    'addSource':
        (c) => c.addSource('tiles', const VectorSourceProperties(url: 'x')),
    'addCircleLayer':
        (c) => c.addCircleLayer(
          'points',
          'circles',
          const {},
          enableInteraction: false,
        ),
    'addBackgroundLayer': (c) => c.addBackgroundLayer('background', const {}),
  };

  for (final call in calls.entries) {
    test('${call.key} throws STYLE_NOT_READY before the style loads', () async {
      final recorded = <String>[];
      final controller =
          MapLibreMapController()..debugSetMap(
            MapLibreMap.fromJsObject(
              recordingMap(recorded) as MapLibreMapJsImpl,
            ),
          );

      await expectLater(
        call.value(controller),
        throwsA(
          isA<PlatformException>()
              .having((e) => e.code, 'code', 'STYLE_NOT_READY')
              .having(
                (e) => e.message,
                'message',
                'Style is null or not fully loaded. Has onStyleLoaded() '
                    'already been invoked?',
              ),
        ),
      );
      expect(recorded, isEmpty, reason: 'nothing reaches maplibre-gl-js');
    });
  }
}
