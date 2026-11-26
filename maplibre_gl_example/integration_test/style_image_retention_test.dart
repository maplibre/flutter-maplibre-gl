// Regression test for native eviction of an image registered from Dart after
// the style first requested it as missing. See STYLE_IMAGE_RETENTION.md.
//
//   flutter test integration_test/style_image_retention_test.dart -d <device>
import 'dart:math' show Point;
import 'dart:typed_data' show Uint8List;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'retention-point';
const _layerId = 'retention-symbol';
// Deliberately not an asset path: the native missing-image fallback cannot
// recover this image from the Flutter bundle.
const _imageId = 'dart-generated-retention-square';
const _camera = CameraPosition(target: LatLng(0, 0), zoom: 3);
// 512 * 512 * 4 = 1,048,576 decoded bytes, above Native's 819,200-byte
// on-demand image-cache limit. Compression does not reduce this cache size.
const _imagePixels = 512;

Map<String, dynamic> _point() => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': 1,
      'geometry': {
        'type': 'Point',
        'coordinates': [0.0, 0.0],
      },
      'properties': {'fixture': 'retention'},
    },
  ],
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a late Dart image survives retirement of its requesting GeoJSON tiles',
    (tester) async {
      var idleCount = 0;
      final controller = await pumpMap(
        tester,
        builder: (onMapCreated, onStyleLoaded) => MapLibreMap(
          styleString: offlineStyle,
          initialCameraPosition: _camera,
          symbolPlacementTransitionsEnabled: false,
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onStyleLoaded,
          onMapIdle: () => idleCount++,
        ),
      );

      Future<void> waitForIdleAfter(int before, String phase) async {
        await pumpUntilValue<int>(
          tester,
          () async => idleCount,
          (count) => count > before,
          '$phase: fresh map idle',
        );
      }

      Future<void> addLayer() => controller.addSymbolLayer(
        _sourceId,
        _layerId,
        const SymbolLayerProperties(
          iconImage: _imageId,
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconPadding: 0,
        ),
      );

      Future<List> rendered() async {
        final screen = await controller.toScreenLocation(_camera.target);
        return controller.queryRenderedFeatures(
          Point<double>(screen.x.toDouble(), screen.y.toDouble()),
          [_layerId],
          null,
        );
      }

      await pumpUntil(
        tester,
        controller.addGeoJsonSource(_sourceId, _point()),
        'add source before image',
      );
      final missingIdle = idleCount;
      await pumpUntil(tester, addLayer(), 'request missing image');
      await waitForIdleAfter(missingIdle, 'missing image');
      expect(
        await pumpUntil(tester, rendered(), 'query missing image'),
        isEmpty,
        reason: 'the layer must request the image before Dart registers it',
      );

      final png = await pumpUntil(tester, _squarePng(), 'generate PNG');
      await pumpUntil(
        tester,
        controller.addImage(_imageId, png, false, 16),
        'register late Dart image once',
      );
      // A missing image may already have completed tile layout. Recreate only
      // the layer so both platforms get a fresh layout with the image present.
      await pumpUntil(tester, controller.removeLayer(_layerId), 'remove layer');
      await pumpUntil(tester, addLayer(), 'lay out late image');
      await pumpUntilValue(
        tester,
        rendered,
        (features) => features.isNotEmpty,
        'late image initially rendered',
      );

      await pumpUntil(tester, controller.removeLayer(_layerId), 'retire layer');
      await pumpUntil(
        tester,
        controller.removeSource(_sourceId),
        'retire requesting source and its tile cache',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'remaining sources'),
        isNot(contains(_sourceId)),
      );
      // Source removal need not emit idle when the map was already idle.
      // Explicit camera updates request native render passes with no source;
      // after worker teardown, a fully-loaded pass can trim the image cache.
      Future<void> renderEmptyMapAt(double zoom) async {
        final before = idleCount;
        await pumpUntil(
          tester,
          controller.moveCamera(CameraUpdate.zoomTo(zoom)),
          'render empty map at zoom $zoom',
        );
        await waitForIdleAfter(before, 'empty map at zoom $zoom');
      }

      await renderEmptyMapAt(4);
      await pumpFor(tester, const Duration(seconds: 1));
      await renderEmptyMapAt(_camera.zoom);

      await pumpUntil(
        tester,
        controller.addGeoJsonSource(_sourceId, _point()),
        'recreate source without registering the image again',
      );
      await pumpUntil(tester, addLayer(), 'reuse retained image');
      await pumpUntilValue(
        tester,
        rendered,
        (features) => features.isNotEmpty,
        'Dart image retained after native cache cleanup',
      );
      expect(tester.takeException(), isNull);
    },
    skip: kIsWeb,
  );
}

Future<Uint8List> _squarePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 512, 512),
    ui.Paint()..color = const ui.Color(0xFF1565C0),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(_imagePixels, _imagePixels);
  picture.dispose();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
