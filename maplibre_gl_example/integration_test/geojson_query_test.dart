// Integration tests for GeoJSON data, feature queries, clusters and feature
// state.
//
// Covered: setGeoJsonSource and setGeoJsonFeature as seen through
// querySourceFeatures, the shape of the features every query returns,
// queryRenderedFeatures and queryRenderedFeaturesInRect with layer ids and
// filters, the cluster inspection calls on a clustered GeoJSON source, and the
// feature state calls (on iOS, their documented UnsupportedError).
//
// None of this can be mocked meaningfully: source features come out of the
// native tiler, rendered features out of a real render pass, clusters out of
// the native cluster index, and feature state out of the renderer. Each test
// pumps its own map from the offline style, adds its data through the
// controller and polls while frames pump, since tiling and rendering are
// asynchronous on every platform.
//
// Run on a device or simulator (Android, iOS):
//   flutter test integration_test/geojson_query_test.dart -d <device id>
//
// Run on Chrome (with chromedriver listening on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/geojson_query_test.dart -d chrome
import 'dart:convert';
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'probe';
const _layerId = 'probe-circle';
const _otherSourceId = 'other';
const _otherLayerId = 'other-circle';
const _clusterSourceId = 'clustered';
const _clusterLayerId = 'clustered-circle';

/// Three points for the rendered queries, placed away from the zoom 3 tile
/// edges (the equator and the prime meridian) so no feature is split across
/// tiles, and far enough apart at zoom 3 that their circles never overlap.
const _p1 = LatLng(5, -8);
const _p2 = LatLng(5, 8);
const _p3 = LatLng(-6, -8);

/// Circle radius for the rendered queries: big enough that a query at the
/// projected center hits the circle even with sub-pixel rounding.
const _radius = 15.0;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('querySourceFeatures', () {
    testWidgets('returns every feature of the source', (tester) async {
      final controller = await _pumpMapWithPoints(tester);

      // The source is tiled asynchronously, so the first queries can come back
      // empty until the tiles covering the points are loaded.
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => _ids(features).containsAll({1, 2, 3}),
        'querySourceFeatures',
      );
    });

    testWidgets('applies a filter expression', (tester) async {
      final controller = await _pumpMapWithPoints(tester);
      await _waitForSourceIds(tester, controller, {1, 2, 3});

      final filtered = await pumpUntil(
        tester,
        controller.querySourceFeatures(_sourceId, null, [
          '==',
          ['get', 'n'],
          2,
        ]),
        'querySourceFeatures with filter',
      );
      expect(_ids(filtered), {2});
    });

    testWidgets('features carry type, geometry and properties', (
      tester,
    ) async {
      final controller = await _pumpMapWithPoints(tester);
      final features = await _waitForSourceIds(tester, controller, {
        1,
        2,
        3,
      });

      final feature = _byId(features, 2);
      expect(feature['type'], 'Feature');
      final geometry = feature['geometry'] as Map;
      expect(geometry['type'], 'Point');
      // Source features are decoded from tiles, so coordinates are quantized
      // to the tile grid rather than exactly what was added.
      final coordinates = geometry['coordinates'] as List;
      expect((coordinates[0] as num).toDouble(), closeTo(2, 0.05));
      expect((coordinates[1] as num).toDouble(), closeTo(5, 0.05));
      final properties = feature['properties'] as Map;
      expect((properties['n'] as num).toInt(), 2);
    });

    testWidgets('a numeric GeoJSON id comes back as that number', (
      tester,
    ) async {
      final controller = await _pumpMapWithPoints(tester);
      final features = await _waitForSourceIds(tester, controller, {
        1,
        2,
        3,
      });

      // The id was added as the number 2, and RFC 7946 lets an id be a number
      // or a string. Handing it back as the string "2" breaks code that
      // compares ids with the data it added.
      final id = _byId(features, 2)['id'];
      expect(id, isA<num>(), reason: 'id came back as ${id.runtimeType}');
      expect(id, 2);
    });
  });

  group('GeoJSON updates', () {
    testWidgets('setGeoJsonSource replaces the data', (tester) async {
      final controller = await _pumpMapWithPoints(tester);
      await _waitForSourceIds(tester, controller, {1, 2, 3});

      await pumpUntil(
        tester,
        controller.setGeoJsonSource(_sourceId, {
          'type': 'FeatureCollection',
          'features': [
            _point(7, const LatLng(5, 4), {'n': 7}),
            _point(8, const LatLng(5, 6), {'n': 8}),
          ],
        }),
        'setGeoJsonSource',
      );

      // The old features must be gone, not merged with the new ones.
      await _waitForSourceIds(tester, controller, {7, 8});
    });

    testWidgets('setGeoJsonFeature updates one feature only', (tester) async {
      final controller = await _pumpMapWithPoints(tester);
      await _waitForSourceIds(tester, controller, {1, 2, 3});

      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(
          _sourceId,
          _point(2, const LatLng(5, 2.5), {'n': 20}),
        ),
        'setGeoJsonFeature',
      );

      final features = await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) {
          final updated = features.where((f) => _id(f) == 2);
          return updated.isNotEmpty &&
              ((updated.first as Map)['properties'] as Map)['n'] == 20;
        },
        'feature 2 updated',
      );

      expect(_ids(features), {1, 2, 3});
      expect(_n(_byId(features, 1)), 1);
      expect(_n(_byId(features, 3)), 3);
      final coordinates =
          (_byId(features, 2)['geometry'] as Map)['coordinates'] as List;
      expect((coordinates[0] as num).toDouble(), closeTo(2.5, 0.05));
    });

    testWidgets('queries answer while setGeoJsonSource is applied', (
      tester,
    ) async {
      final controller = await _pumpMapWithRenderedPoints(tester);
      final p1 = await _screen(tester, controller, _p1);
      await _waitForRendered(tester, controller, p1, [_layerId]);

      // Same places, new properties. The queries run while the update is
      // still being applied: on web the map then reports its style as not
      // loaded, which made them fail or answer nothing, while Android and iOS
      // answered with the features.
      final update = controller.setGeoJsonSource(_sourceId, {
        'type': 'FeatureCollection',
        'features': [
          _point(1, _p1, {'n': 10}),
          _point(2, _p2, {'n': 20}),
          _point(3, _p3, {'n': 30}),
        ],
      });
      final source = await pumpUntil(
        tester,
        controller.querySourceFeatures(_sourceId, null, null),
        'querySourceFeatures',
      );
      final rendered = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(p1, [_layerId], null),
        'queryRenderedFeatures',
      );
      await pumpUntil(tester, update, 'setGeoJsonSource');

      expect(_ids(source), isNotEmpty);
      expect(_ids(rendered), contains(1));
    });
  });

  group('queryRenderedFeatures', () {
    testWidgets('finds the feature drawn at a point', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(tester);
      final p1 = await _screen(tester, controller, _p1);

      final features = await _waitForRendered(tester, controller, p1, [
        _layerId,
      ]);
      expect(_ids(features), {1});

      final feature = _byId(features, 1);
      expect(feature['type'], 'Feature');
      expect((feature['geometry'] as Map)['type'], 'Point');
      expect(_n(feature), 1);
    });

    testWidgets('only searches the given layers', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(
        tester,
        withOtherLayer: true,
      );
      final p1 = await _screen(tester, controller, _p1);

      // Both layers draw a circle at p1; each query must only see its own.
      await _waitForRendered(
        tester,
        controller,
        p1,
        [_layerId, _otherLayerId],
        accept: (ids) => ids.containsAll({1, 99}),
      );

      final main = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(p1, [_layerId], null),
        'query main layer',
      );
      expect(_ids(main), {1});

      final other = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(p1, [_otherLayerId], null),
        'query other layer',
      );
      expect(_ids(other), {99});
    });

    testWidgets('applies a filter expression', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(
        tester,
        withOtherLayer: true,
      );
      final p1 = await _screen(tester, controller, _p1);
      final layers = [_layerId, _otherLayerId];
      await _waitForRendered(
        tester,
        controller,
        p1,
        layers,
        accept: (ids) => ids.containsAll({1, 99}),
      );

      final matching = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(p1, layers, [
          '==',
          ['get', 'n'],
          1,
        ]),
        'query with matching filter',
      );
      expect(_ids(matching), {1});

      final none = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(p1, layers, [
          '==',
          ['get', 'n'],
          2,
        ]),
        'query with filter matching nothing here',
      );
      expect(none, isEmpty);
    });
  });

  group('queryRenderedFeaturesInRect', () {
    testWidgets('finds the features drawn in a rectangle', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(tester);
      final rect = await _leftColumnRect(tester, controller);

      // The rectangle covers p1 and p3 but stays well clear of p2.
      final features = await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _ids(features).containsAll({1, 3}),
        'queryRenderedFeaturesInRect',
      );
      expect(_ids(features), {1, 3});
    });

    testWidgets('only searches the given layers', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(
        tester,
        withOtherLayer: true,
      );
      final rect = await _leftColumnRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [
          _layerId,
          _otherLayerId,
        ], null),
        (features) => _ids(features).containsAll({1, 3, 99}),
        'queryRenderedFeaturesInRect on both layers',
      );

      final other = await pumpUntil(
        tester,
        controller.queryRenderedFeaturesInRect(rect, [_otherLayerId], null),
        'query other layer in rect',
      );
      expect(_ids(other), {99});
    });

    testWidgets('applies a filter given as a JSON string', (tester) async {
      final controller = await _pumpMapWithRenderedPoints(tester);
      final rect = await _leftColumnRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _ids(features).containsAll({1, 3}),
        'queryRenderedFeaturesInRect',
      );

      // Unlike queryRenderedFeatures, this call takes the expression encoded
      // as JSON, and dropping it silently would answer with both features.
      final filtered = await pumpUntil(
        tester,
        controller.queryRenderedFeaturesInRect(
          rect,
          [_layerId],
          jsonEncode([
            '==',
            ['get', 'n'],
            3,
          ]),
        ),
        'queryRenderedFeaturesInRect with filter',
      );
      expect(_ids(filtered), {3});
    });
  });

  group('clusters', () {
    testWidgets('getClusterExpansionZoom is past the current zoom', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      final clusterId = await _waitForCluster(tester, controller);

      final zoom = await pumpUntil(
        tester,
        controller.getClusterExpansionZoom(_clusterSourceId, clusterId),
        'getClusterExpansionZoom',
      );
      // The six points sit a few pixels apart at zoom 3, so they only split
      // further in, and never past clusterMaxZoom + 1.
      expect(zoom, greaterThan(3));
      expect(zoom, lessThanOrEqualTo(15));
    });

    testWidgets('getClusterChildren accounts for every point', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      final clusterId = await _waitForCluster(tester, controller);

      final children = await pumpUntil(
        tester,
        controller.getClusterChildren(_clusterSourceId, clusterId),
        'getClusterChildren',
      );
      expect(children, isNotEmpty);
      // A child is either a smaller cluster or one of the original points, so
      // their sizes add up to the parent's point_count.
      var total = 0;
      for (final child in children) {
        final properties = child['properties'] as Map;
        total +=
            properties.containsKey('point_count')
                ? (properties['point_count'] as num).toInt()
                : 1;
      }
      expect(total, 6);
    });

    testWidgets('getClusterLeaves returns the original points', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      final clusterId = await _waitForCluster(tester, controller);

      final leaves = await pumpUntil(
        tester,
        controller.getClusterLeaves(_clusterSourceId, clusterId),
        'getClusterLeaves',
      );
      expect(leaves, hasLength(6));
      expect(leaves.map(_n).toSet(), {1, 2, 3, 4, 5, 6});
      for (final leaf in leaves) {
        expect(leaf['type'], 'Feature');
        expect((leaf['geometry'] as Map)['type'], 'Point');
      }
    });

    testWidgets('getClusterLeaves pages with limit and offset', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      final clusterId = await _waitForCluster(tester, controller);

      final pages = <List<Map<String, dynamic>>>[];
      for (final offset in [0, 2, 4]) {
        pages.add(
          await pumpUntil(
            tester,
            controller.getClusterLeaves(
              _clusterSourceId,
              clusterId,
              limit: 2,
              offset: offset,
            ),
            'getClusterLeaves offset $offset',
          ),
        );
      }
      for (final page in pages) {
        expect(page, hasLength(2));
      }
      // Pages do not overlap and together cover the whole cluster.
      final seen = [for (final page in pages) ...page.map(_n)];
      expect(seen.toSet(), {1, 2, 3, 4, 5, 6});
      expect(seen, hasLength(6));

      final past = await pumpUntil(
        tester,
        controller.getClusterLeaves(
          _clusterSourceId,
          clusterId,
          limit: 2,
          offset: 6,
        ),
        'getClusterLeaves past the end',
      );
      expect(past, isEmpty);
    });

    testWidgets('an unknown source is an error for every cluster call', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      await _waitForCluster(tester, controller);

      await expectPlatformError(
        tester,
        controller.getClusterExpansionZoom('missing', 1),
        'getClusterExpansionZoom on a missing source',
        code: 'SOURCE_NOT_FOUND',
      );
      await expectPlatformError(
        tester,
        controller.getClusterChildren('missing', 1),
        'getClusterChildren on a missing source',
        code: 'SOURCE_NOT_FOUND',
      );
      await expectPlatformError(
        tester,
        controller.getClusterLeaves('missing', 1),
        'getClusterLeaves on a missing source',
        code: 'SOURCE_NOT_FOUND',
      );
    });

    testWidgets('an unknown cluster id is CLUSTER_NOT_FOUND for every call', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      await _waitForCluster(tester, controller);

      // A stale id is an error rather than 0 or an empty list: 0 is a valid
      // zoom, and an empty list looks like a cluster with nothing in it. On
      // Android and iOS this call used to crash the app.
      await expectPlatformError(
        tester,
        controller.getClusterExpansionZoom(_clusterSourceId, _unknownClusterId),
        'getClusterExpansionZoom for an unknown id',
        code: 'CLUSTER_NOT_FOUND',
      );
      await expectPlatformError(
        tester,
        controller.getClusterChildren(_clusterSourceId, _unknownClusterId),
        'getClusterChildren for an unknown id',
        code: 'CLUSTER_NOT_FOUND',
      );
      await expectPlatformError(
        tester,
        controller.getClusterLeaves(_clusterSourceId, _unknownClusterId),
        'getClusterLeaves for an unknown id',
        code: 'CLUSTER_NOT_FOUND',
      );
    });
  });

  group('feature state', () {
    testWidgets('is unsupported on iOS', (tester) async {
      if (testPlatform != TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);

      // Documented on the controller: the iOS SDK has no feature state API, so
      // every call fails with an UnsupportedError before reaching native.
      await _expectUnsupported(
        controller.setFeatureState(_sourceId, '1', {'selected': true}),
      );
      await _expectUnsupported(
        controller.getFeatureState(_sourceId, '1'),
      );
      await _expectUnsupported(
        controller.removeFeatureState(_sourceId),
      );
    });

    testWidgets('reads null before any state is set', (tester) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);

      // Null, not an empty map, so an app can tell "nothing set" from "set to
      // nothing".
      expect(
        await pumpUntil(
          tester,
          controller.getFeatureState(_sourceId, '1'),
          'getFeatureState',
        ),
        isNull,
      );
    });

    testWidgets('reads back what was set', (tester) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);

      await _setState(tester, controller, '1', {'selected': true, 'score': 7});
      await _waitForState(tester, controller, '1', {
        'selected': true,
        'score': 7,
      });
      // Another feature of the same source is untouched.
      expect(
        await pumpUntil(
          tester,
          controller.getFeatureState(_sourceId, '2'),
          'getFeatureState of feature 2',
        ),
        isNull,
      );
    });

    testWidgets('removes one key with featureId and stateKey', (
      tester,
    ) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);
      await _setState(tester, controller, '1', {'selected': true, 'score': 7});
      await _waitForState(tester, controller, '1', {
        'selected': true,
        'score': 7,
      });

      await pumpUntil(
        tester,
        controller.removeFeatureState(
          _sourceId,
          featureId: '1',
          stateKey: 'selected',
        ),
        'removeFeatureState one key',
      );
      await _waitForState(tester, controller, '1', {'score': 7});
    });

    testWidgets('removes a whole feature state with featureId alone', (
      tester,
    ) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);
      await _setState(tester, controller, '1', {'selected': true, 'score': 7});
      await _setState(tester, controller, '2', {'selected': true});
      await _waitForState(tester, controller, '2', {'selected': true});

      await pumpUntil(
        tester,
        controller.removeFeatureState(_sourceId, featureId: '1'),
        'removeFeatureState one feature',
      );
      await _waitForState(tester, controller, '1', null);
      // Only feature 1 was cleared.
      expect(
        await pumpUntil(
          tester,
          controller.getFeatureState(_sourceId, '2'),
          'getFeatureState of feature 2',
        ),
        {'selected': true},
      );
    });

    testWidgets('resets the whole source with no featureId', (tester) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);
      await _setState(tester, controller, '1', {'score': 7});
      await _setState(tester, controller, '2', {'selected': true});
      await _waitForState(tester, controller, '2', {'selected': true});

      await pumpUntil(
        tester,
        controller.removeFeatureState(_sourceId),
        'removeFeatureState whole source',
      );
      await _waitForState(tester, controller, '1', null);
      await _waitForState(tester, controller, '2', null);
    });

    testWidgets('rejects a stateKey without a featureId', (tester) async {
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithPoints(tester);
      await _setState(tester, controller, '1', {'score': 7});
      await _waitForState(tester, controller, '1', {'score': 7});

      // A key lives inside one feature's state, so there is nothing to take it
      // from. Rejecting it beats quietly doing nothing, or resetting the whole
      // source.
      await expectPlatformError(
        tester,
        controller.removeFeatureState(_sourceId, stateKey: 'score'),
        'removeFeatureState with stateKey only',
        code: 'INVALID_ARGUMENT',
      );
      expect(
        await pumpUntil(
          tester,
          controller.getFeatureState(_sourceId, '1'),
          'getFeatureState after the rejected call',
        ),
        {'score': 7},
      );
    });
  });
}

/// An id that is not a cluster of [_clusterSourceId]: decoded by the cluster
/// index it points at a zoom level the index does not have.
const _unknownClusterId = 999999;

/// A map with [pointCollection] (ids 1..3 at lat 5, off the zoom 3 tile
/// edges) in [_sourceId], drawn by a circle layer so its tiles get loaded.
Future<MapLibreMapController> _pumpMapWithPoints(WidgetTester tester) async {
  final controller = await pumpMap(tester);
  await pumpUntil(
    tester,
    controller.addGeoJsonSource(_sourceId, pointCollection(lat: 5)),
    'addGeoJsonSource',
  );
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(circleRadius: 6),
    ),
    'addCircleLayer',
  );
  return controller;
}

/// A map with [_p1], [_p2] and [_p3] (ids and `n` 1..3) drawn as big circles
/// in [_layerId]. With [withOtherLayer], a second source and layer draw one
/// more feature (id and `n` 99) on top of [_p1].
Future<MapLibreMapController> _pumpMapWithRenderedPoints(
  WidgetTester tester, {
  bool withOtherLayer = false,
}) async {
  final controller = await pumpMap(tester);
  await pumpUntil(
    tester,
    controller.addGeoJsonSource(_sourceId, {
      'type': 'FeatureCollection',
      'features': [
        _point(1, _p1, {'n': 1}),
        _point(2, _p2, {'n': 2}),
        _point(3, _p3, {'n': 3}),
      ],
    }),
    'addGeoJsonSource',
  );
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(circleRadius: _radius),
    ),
    'addCircleLayer',
  );
  if (withOtherLayer) {
    await pumpUntil(
      tester,
      controller.addGeoJsonSource(_otherSourceId, {
        'type': 'FeatureCollection',
        'features': [
          _point(99, _p1, {'n': 99}),
        ],
      }),
      'addGeoJsonSource other',
    );
    await pumpUntil(
      tester,
      controller.addCircleLayer(
        _otherSourceId,
        _otherLayerId,
        const CircleLayerProperties(circleRadius: _radius),
      ),
      'addCircleLayer other',
    );
  }
  return controller;
}

/// A map with six points packed within a few pixels of each other at zoom 3,
/// in a clustered source, so they form a single cluster of six.
Future<MapLibreMapController> _pumpMapWithCluster(WidgetTester tester) async {
  final controller = await pumpMap(tester);
  await pumpUntil(
    tester,
    controller.addSource(
      _clusterSourceId,
      GeojsonSourceProperties(
        data: {
          'type': 'FeatureCollection',
          'features': [
            for (var i = 0; i < 6; i++)
              _point(i + 1, LatLng(10 + 0.05 * (i % 2), 10 + 0.05 * i), {
                'n': i + 1,
              }),
          ],
        },
        cluster: true,
        clusterRadius: 50,
        clusterMaxZoom: 14,
      ),
    ),
    'addSource clustered',
  );
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _clusterSourceId,
      _clusterLayerId,
      const CircleLayerProperties(circleRadius: 10),
    ),
    'addCircleLayer clustered',
  );
  return controller;
}

/// Waits for the six-point cluster to show up in the source and returns its
/// `cluster_id`. No query filter is used, so this does not depend on how each
/// platform translates one.
Future<int> _waitForCluster(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final features = await pumpUntilValue(
    tester,
    () => controller.querySourceFeatures(_clusterSourceId, null, null),
    (features) => features.any(_isFullCluster),
    'cluster in querySourceFeatures',
  );
  final cluster = features.firstWhere(_isFullCluster) as Map;
  return ((cluster['properties'] as Map)['cluster_id'] as num).toInt();
}

bool _isFullCluster(dynamic feature) {
  final properties = (feature as Map)['properties'] as Map?;
  return properties != null &&
      properties['cluster_id'] != null &&
      (properties['point_count'] as num?)?.toInt() == 6;
}

/// Polls [_sourceId] until its feature ids are exactly [ids].
Future<List> _waitForSourceIds(
  WidgetTester tester,
  MapLibreMapController controller,
  Set<int> ids,
) {
  return pumpUntilValue(
    tester,
    () => controller.querySourceFeatures(_sourceId, null, null),
    (features) => _sameSet(_ids(features), ids),
    'querySourceFeatures ids $ids',
  );
}

/// Polls a rendered point query until it finds something [accept] likes (by
/// default, anything), since the layer is only queryable once drawn.
Future<List> _waitForRendered(
  WidgetTester tester,
  MapLibreMapController controller,
  Point<double> point,
  List<String> layerIds, {
  bool Function(Set<int> ids)? accept,
}) {
  return pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, layerIds, null),
    (features) => (accept ?? (ids) => ids.isNotEmpty)(_ids(features)),
    'queryRenderedFeatures on $layerIds',
  );
}

/// The screen location of [latLng], in the units queryRenderedFeatures takes
/// on this platform (toScreenLocation answers in the same ones).
Future<Point<double>> _screen(
  WidgetTester tester,
  MapLibreMapController controller,
  LatLng latLng,
) async {
  final point = await pumpUntil(
    tester,
    controller.toScreenLocation(latLng),
    'toScreenLocation',
  );
  return Point(point.x.toDouble(), point.y.toDouble());
}

/// A screen rectangle around [_p1] and [_p3] that stays clear of [_p2].
Future<Rect> _leftColumnRect(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final a = await _screen(tester, controller, const LatLng(10, -12));
  final b = await _screen(tester, controller, const LatLng(-11, -4));
  return Rect.fromPoints(Offset(a.x, a.y), Offset(b.x, b.y));
}

Future<void> _setState(
  WidgetTester tester,
  MapLibreMapController controller,
  String featureId,
  Map<String, dynamic> state,
) {
  return pumpUntil(
    tester,
    controller.setFeatureState(_sourceId, featureId, state),
    'setFeatureState $featureId',
  );
}

/// Polls getFeatureState until it equals [expected] (null for no state).
Future<void> _waitForState(
  WidgetTester tester,
  MapLibreMapController controller,
  String featureId,
  Map<String, dynamic>? expected,
) async {
  await pumpUntilValue(
    tester,
    () => controller.getFeatureState(_sourceId, featureId),
    (state) =>
        expected == null
            ? state == null
            : state != null &&
                state.length == expected.length &&
                expected.entries.every((e) => state[e.key] == e.value),
    'getFeatureState $featureId == $expected',
  );
}

/// The iOS guard throws before any channel call, so the future has already
/// failed and needs no frames pumped to settle.
Future<void> _expectUnsupported(Future<Object?> future) =>
    expectLater(future, throwsUnsupportedError);

Map<String, dynamic> _point(
  int id,
  LatLng at,
  Map<String, dynamic> properties,
) => {
  'type': 'Feature',
  'id': id,
  'geometry': {
    'type': 'Point',
    'coordinates': [at.longitude, at.latitude],
  },
  'properties': properties,
};

/// The feature id as an int, whether it came back as a number or as a numeric
/// string, so the tests about which features are returned do not depend on
/// the id type (pinned separately).
int? _id(dynamic feature) => num.tryParse('${(feature as Map)['id']}')?.toInt();

/// The distinct ids in [features]; a feature near a tile edge can be reported
/// once per tile.
Set<int> _ids(List features) => {
  for (final feature in features)
    if (_id(feature) case final id?) id,
};

Map _byId(List features, int id) =>
    features.firstWhere((f) => _id(f) == id) as Map;

int _n(dynamic feature) =>
    (((feature as Map)['properties'] as Map)['n'] as num).toInt();

bool _sameSet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
