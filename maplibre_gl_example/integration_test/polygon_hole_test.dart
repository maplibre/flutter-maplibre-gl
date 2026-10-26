// Integration tests for taps inside the hole of a polygon (#893).
//
// MapLibre Native finds a polygon for any point or box inside one of its
// holes, so queryRenderedFeatures on Android and iOS keeps returning it there.
// Taps and drags check those polygons again (PolygonHitTest.java and
// PolygonHitTest.swift): inside a hole the polygon is hit only within the
// touch tolerance of a ring edge, as on web where MapLibre GL JS already
// leaves holes out.
//
// Run on an Android device or emulator:
//   flutter test integration_test/polygon_hole_test.dart -d <device>
//
// The tap assertions only run on Android. On iOS the map's gesture recognizers
// do not see the pointers Flutter synthesizes (see
// feature_hit_tolerance_test.dart), so iOS relies on PolygonHitTest.swift
// doing the same math as PolygonHitTest.java. The query in the hole is only
// checked on web, the one platform where it is defined to find nothing.
//
// Both windings of the inner ring are covered: the one the report used (same
// direction as the outer ring) and the one RFC 7946 prescribes (opposite).
import 'dart:developer' show Timeline;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'holed';
const _layerId = 'holed-fill';

/// Center of the hole. At zoom 10 the whole polygon fits the 300 dp map and
/// no tile edge crosses it.
const _center = LatLng(48.05, 2.05);

/// On the filled ring, halfway between the outer and the inner border.
const _onRing = LatLng(48.01, 2.05);

/// On the west border of the hole, level with its center.
const _holeWestBorder = LatLng(48.05, 2.02);

/// The ring of the report: counterclockwise, like the outer ring.
const _holeSameWinding = [
  [2.02, 48.02],
  [2.08, 48.02],
  [2.08, 48.08],
  [2.02, 48.08],
  [2.02, 48.02],
];

bool get _onAndroid => testPlatform == TestPlatform.android;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final variant
      in {
        'same winding as the outer ring': _holeSameWinding,
        'opposite winding (RFC 7946)': _holeSameWinding.reversed.toList(),
      }.entries) {
    group(variant.key, () {
      testWidgets('a tap in the hole taps the map', (tester) async {
        if (!_onAndroid) return;
        final map = await _pumpHoledMap(tester, variant.value);

        await map.tap(_center);

        expect(map.featureTaps, isEmpty);
        expect(map.clicks, hasLength(1));
      });

      testWidgets('a tap on the filled ring taps the polygon', (tester) async {
        if (!_onAndroid) return;
        final map = await _pumpHoledMap(tester, variant.value);

        await map.tap(_onRing);

        expect(map.featureTaps, [_layerId]);
      });

      testWidgets('a tap in the hole 5 dp from its border taps the polygon', (
        tester,
      ) async {
        if (!_onAndroid) return;
        final map = await _pumpHoledMap(tester, variant.value);

        await map.tap(_holeWestBorder, nudge: const Offset(5, 0));

        expect(map.featureTaps, [_layerId]);
      });

      testWidgets('a query in the hole finds no polygon on web', (
        tester,
      ) async {
        if (!kIsWeb) return;
        final map = await _pumpHoledMap(tester, variant.value);

        final hits = await pumpUntil(
          tester,
          map.query(_center),
          'query in the hole',
        );

        expect(hits, isEmpty, reason: 'the hole is not part of the polygon');
      });
    });
  }
}

/// Lets the platform view answer.
Future<void> _settle(WidgetTester tester) =>
    pumpFor(tester, const Duration(milliseconds: 500));

/// One finger whose events carry real timestamps, as in
/// feature_hit_tolerance_test.dart: Android times long presses from the
/// event's down time, so the zero timestamps of a plain `TestGesture` would
/// make every touch a long press.
class _Finger {
  _Finger(this.tester);

  final WidgetTester tester;
  late TestGesture _gesture;

  Duration get _now => Duration(microseconds: Timeline.now);

  Future<void> down(Offset at) async {
    _gesture = await tester.createGesture();
    await _gesture.down(at, timeStamp: _now);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> up() async {
    await _gesture.up(timeStamp: _now);
  }
}

class _MapProbe {
  _MapProbe(this.tester);

  final WidgetTester tester;

  /// Layer ids of the features tapped.
  final featureTaps = <String>[];
  final clicks = <LatLng>[];
  late MapLibreMapController controller;

  Future<Offset> _platformPoint(LatLng at) async {
    final p = await pumpUntil(
      tester,
      controller.toScreenLocation(at),
      'toScreenLocation',
    );
    return Offset(p.x.toDouble(), p.y.toDouble());
  }

  /// Features of the fill layer in an 8 dp box around [at], the area a tap
  /// looks in.
  Future<List> query(LatLng at) async {
    final center = await _platformPoint(at);
    return controller.queryRenderedFeaturesInRect(
      Rect.fromCircle(center: center, radius: 8),
      [_layerId],
      null,
    );
  }

  /// Taps at [at], moved by [nudge] logical pixels.
  Future<void> tap(LatLng at, {Offset nudge = Offset.zero}) async {
    final local = await _platformPoint(at);
    final topLeft = tester.getTopLeft(find.byType(MapLibreMap));
    final finger = _Finger(tester);
    await finger.down(topLeft + local + nudge);
    await finger.up();
    await _settle(tester);
  }
}

/// A map showing a square polygon with a square hole, drawn and queryable.
Future<_MapProbe> _pumpHoledMap(
  WidgetTester tester,
  List<List<double>> hole,
) async {
  final probe = _MapProbe(tester);
  final controller =
      probe.controller = await pumpMap(
        tester,
        builder:
            (onMapCreated, onStyleLoaded) => MapLibreMap(
              styleString: offlineStyle,
              initialCameraPosition: const CameraPosition(
                target: _center,
                zoom: 10,
              ),
              onMapCreated: onMapCreated,
              onStyleLoadedCallback: onStyleLoaded,
              onMapClick: (_, latLng) => probe.clicks.add(latLng),
            ),
      );
  controller.onFeatureTapped.add(
    (point, latLng, id, layerId, annotation) => probe.featureTaps.add(layerId),
  );

  await pumpUntil(
    tester,
    controller.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': 1,
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [2.0, 48.0],
                [2.1, 48.0],
                [2.1, 48.1],
                [2.0, 48.1],
                [2.0, 48.0],
              ],
              hole,
            ],
          },
          'properties': {'name': 'holed'},
        },
      ],
    }),
    'addGeoJsonSource',
  );
  await pumpUntil(
    tester,
    controller.addFillLayer(
      _sourceId,
      _layerId,
      const FillLayerProperties(fillColor: '#FF0000', fillOpacity: 0.5),
    ),
    'addFillLayer',
  );

  // Taps only see what is drawn: wait until the filled ring is queryable.
  await pumpUntilValue(
    tester,
    () => probe.query(_onRing),
    (hits) => hits.isNotEmpty,
    'polygon drawn',
  );
  return probe;
}
