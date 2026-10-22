// Integration test for the size addImage draws an image at.
//
// Every platform draws one image pixel per device pixel, so an image is its
// width in pixels divided by the device pixel ratio wide in logical pixels: a
// 96 px PNG is 48 logical px on a 2x screen and 32 on a 3x one. Web used to
// draw one image pixel per logical pixel, 2 to 3 times larger than Android and
// iOS on most screens.
//
// The width is measured where queryRenderedFeatures finds the icon, so no
// renderer change can break it the way a pixel-exact golden would. Headless
// Chrome runs at a ratio of 1, where both rules agree, so CI also runs this
// file on web at a ratio of 2:
//
//   flutter test integration_test/add_image_size_test.dart -d <device>
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/add_image_size_test.dart -d web-server \
//     --web-browser-flag=--force-device-scale-factor=2
import 'dart:math' show Point, pow;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _imagePixels = 96;
const _zoom = 3.0;

/// Away from tile edges at [_zoom]. The probes move along the parallel, where
/// screen x is linear in longitude.
const _center = LatLng(10, 20);
const _layerId = 'square';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('addImage draws one image pixel per device pixel', (
    tester,
  ) async {
    final controller = await pumpMap(
      tester,
      initialCameraPosition: const CameraPosition(target: _center, zoom: _zoom),
    );
    final png = await pumpUntil(tester, _squarePng(_imagePixels), 'PNG');
    await pumpUntil(tester, controller.addImage('square', png), 'addImage');
    await pumpUntil(
      tester,
      controller.addGeoJsonSource('point', {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [_center.longitude, _center.latitude],
            },
            'properties': <String, dynamic>{},
          },
        ],
      }),
      'addGeoJsonSource',
    );
    await pumpUntil(
      tester,
      controller.addSymbolLayer(
        'point',
        _layerId,
        const SymbolLayerProperties(
          iconImage: 'square',
          iconAllowOverlap: true,
          // No margin around the icon in the box the query hits.
          iconPadding: 0,
        ),
      ),
      'addSymbolLayer',
    );

    // Whether the icon is under the point [dx] logical px east of its center.
    // Logical px become longitude, and the platform turns that into its own
    // screen units, so the test holds whatever units toScreenLocation uses.
    Future<bool> query(double dx) async {
      final degreesPerPixel = 360 / (512 * pow(2, _zoom));
      final screen = await controller.toScreenLocation(
        LatLng(_center.latitude, _center.longitude + dx * degreesPerPixel),
      );
      final features = await controller.queryRenderedFeatures(
        Point<double>(screen.x.toDouble(), screen.y.toDouble()),
        [_layerId],
        null,
      );
      return features.isNotEmpty;
    }

    Future<bool> hits(double dx) => pumpUntil(tester, query(dx), 'query $dx');

    await pumpUntilValue(tester, () => query(0), (hit) => hit, 'icon drawn');
    final east = await _edge(hits, 1);
    final west = await _edge(hits, -1);

    final ratio = tester.view.devicePixelRatio;
    expect(
      east + west,
      closeTo(_imagePixels / ratio, 2),
      reason:
          'width in logical px of a $_imagePixels px image '
          'at a device pixel ratio of $ratio',
    );
  });
}

/// The distance in logical px from the icon's center to its edge on the side
/// [sign] points to, to a quarter of a pixel.
Future<double> _edge(Future<bool> Function(double dx) hits, int sign) async {
  var inside = 0.0;
  // Past the edge of a 96 px image at a ratio of 1, inside the 300 px map.
  var outside = 120.0;
  expect(await hits(sign * outside), isFalse, reason: 'icon at $outside px');
  while (outside - inside > 0.25) {
    final middle = (inside + outside) / 2;
    if (await hits(sign * middle)) {
      inside = middle;
    } else {
      outside = middle;
    }
  }
  return (inside + outside) / 2;
}

/// A [size] x [size] PNG of one opaque color.
Future<Uint8List> _squarePng(int size) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFF1565C0),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
