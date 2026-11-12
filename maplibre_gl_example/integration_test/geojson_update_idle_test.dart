// Integration test: the first map idle after setGeoJsonSource shows the new
// data (#1202).
//
// On Android, MapLibre adds GeoJSON data to the source after a conversion on a
// background thread, and a tile gets its new features later again. If the
// call replies before the first step, or a tile stays complete with its old
// features during the second (maplibre-native#4972), a frame with the old
// data can end the update, and the map becomes idle. Then an app that waits
// for the first idle after the call reads the old data. This occurs most
// often after the map was quiet for a few seconds, so each round first waits
// for a quiet map. The layer is a symbol layer: with a circle layer, the
// problem did not occur.
import 'dart:math' show Point;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'update-idle-points';
const _layerId = 'update-idle-symbols';
const _camera = CameraPosition(target: LatLng(0, 2), zoom: 4);
const _rounds = 4;
const _quiet = Duration(seconds: 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('setGeoJsonSource', () {
    testWidgets(
      'the first map idle after the call shows the new data',
      (tester) async {
        var idles = 0;
        final controller = await pumpMap(
          tester,
          builder: (onMapCreated, onStyleLoaded) => MapLibreMap(
            styleString: offlineStyle,
            initialCameraPosition: _camera,
            onMapCreated: onMapCreated,
            onStyleLoadedCallback: onStyleLoaded,
            onMapIdle: () => idles++,
          ),
        );
        final png = (await rootBundle.load(
          'assets/symbols/custom-marker.png',
        )).buffer.asUint8List();
        await pumpUntil(tester, controller.addImage('marker', png), 'addImage');
        await pumpUntil(
          tester,
          controller.addGeoJsonSource(_sourceId, _point(1)),
          'addGeoJsonSource',
        );
        await pumpUntil(
          tester,
          controller.addSymbolLayer(
            _sourceId,
            _layerId,
            const SymbolLayerProperties(
              iconImage: 'marker',
              iconAllowOverlap: true,
            ),
          ),
          'addSymbolLayer',
        );
        await pumpUntilValue(
          tester,
          () => _rendered(controller, 1),
          (found) => found,
          'point 1 rendered',
        );

        for (var round = 0; round < _rounds; round++) {
          final n = round.isEven ? 3 : 1;
          await pumpFor(tester, _quiet);
          // The idle count when the call completes, read in the same
          // microtask as the reply, before any later idle can arrive.
          final idlesAtReply = await pumpUntil(
            tester,
            controller
                .setGeoJsonSource(_sourceId, _point(n))
                .then((_) => idles),
            'setGeoJsonSource $n',
          );
          await pumpUntilValue(
            tester,
            () async => idles,
            (count) => count > idlesAtReply,
            'first idle after setGeoJsonSource $n',
          );
          expect(
            await _rendered(controller, n),
            isTrue,
            reason:
                'round $round: the first idle after the call shows point $n',
          );
        }
        expect(tester.takeException(), isNull);
      },
      // On web, setData has no completion signal that this test can wait for.
      skip: kIsWeb,
    );
  });
}

/// A FeatureCollection with one point, with id [n] at longitude [n] on the
/// equator.
Map<String, dynamic> _point(int n) => {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': n,
      'geometry': {
        'type': 'Point',
        'coordinates': [n.toDouble(), 0.0],
      },
      'properties': {'n': n},
    },
  ],
};

/// Whether the symbol of point [n] is rendered now. Reads the map once and
/// does not wait.
Future<bool> _rendered(MapLibreMapController controller, int n) async {
  final screen = await controller.toScreenLocation(LatLng(0, n.toDouble()));
  final features = await controller.queryRenderedFeatures(
    Point<double>(screen.x.toDouble(), screen.y.toDouble()),
    [_layerId],
    null,
  );
  return features.cast<Map>().any(
    (f) => (f['properties'] as Map?)?['n'].toString() == '$n',
  );
}
