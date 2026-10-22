// Integration tests for GeoJSON feature ids: a feature added with the id 2,
// "2", 2.5 or "poi-12" comes back with that value and type from every query
// and cluster call, is selected by an ['id'] filter on that value, keeps its
// feature state, and reaches the tap and drag callbacks as text. Whatever the
// plugin adds to the data to get there never shows up in what the app reads.
// A source with generateId keeps the ids it generates.
//
// Run on a device or simulator (Android, iOS):
//   flutter test integration_test/feature_id_test.dart -d <device id>
//
// Run on Chrome (with chromedriver listening on :4444):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/feature_id_test.dart -d chrome
//
// Taps and drags are checked here on Android only: on iOS the map does not see
// the pointers Flutter synthesizes, and on web they are in
// feature_drag_web_test.dart, which needs package:web.
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'ids';
const _layerId = 'ids-circle';
const _clusterSourceId = 'ids-clustered';
const _clusterLayerId = 'ids-clustered-circle';

/// Circle radius, big enough that a query at the projected center hits it.
const _radius = 15.0;

/// The radius a feature takes with the `big` feature state.
const _bigRadius = 40.0;

/// The features by name: the id each one has in the data, and where it is,
/// away from the zoom 3 tile edges and far enough apart that no two circles
/// overlap, even when one of them is big.
final _features = <String, ({Object id, LatLng at})>{
  'number': (id: 2, at: const LatLng(5, -8)),
  'text': (id: '2', at: const LatLng(5, 8)),
  'decimal': (id: 2.5, at: const LatLng(-6, -8)),
  'name': (id: 'poi-12', at: const LatLng(-6, 8)),
};

/// What every query should answer: the id of each feature, by name.
final Map<String, Object> _expectedIds = {
  for (final MapEntry(:key, :value) in _features.entries) key: value.id,
};

/// The ids `generateId` gives [_features]: their index, over their own id.
final Map<String, Object> _generatedIds = {
  for (final (index, name) in _features.keys.indexed) name: index,
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('feature ids come back as in the data', () {
    testWidgets('from querySourceFeatures', (tester) async {
      final controller = await _pumpMapWithFeatures(tester);

      final features = await _waitForAll(tester, controller);
      expect(_idsByName(features), _expectedIds);
      _expectOwnProperties(features);
    });

    testWidgets('from queryRenderedFeatures', (tester) async {
      final controller = await _pumpMapWithFeatures(tester);
      await _waitForAll(tester, controller);

      final features = <Object?>[];
      for (final MapEntry(:key, :value) in _features.entries) {
        final point = await _screen(tester, controller, value.at);
        features.addAll(
          await pumpUntilValue<List>(
            tester,
            () => controller.queryRenderedFeatures(point, [_layerId], null),
            (features) => _idsByName(features).containsKey(key),
            'queryRenderedFeatures at $key',
          ),
        );
      }
      expect(_idsByName(features), _expectedIds);
      _expectOwnProperties(features);
    });

    testWidgets('from queryRenderedFeaturesInRect', (tester) async {
      final controller = await _pumpMapWithFeatures(tester);
      await _waitForAll(tester, controller);
      final rect = await _allFeaturesRect(tester, controller);

      final features = await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _idsByName(features).length == _features.length,
        'queryRenderedFeaturesInRect',
      );
      expect(_idsByName(features), _expectedIds);
      _expectOwnProperties(features);
    });

    testWidgets('from getClusterLeaves and getClusterChildren', (
      tester,
    ) async {
      final controller = await _pumpMapWithCluster(tester);
      final cluster = await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_clusterSourceId, null, null),
        (features) => features.any(_isFullCluster),
        'cluster of every feature',
      );
      final clusterId =
          (((cluster.firstWhere(_isFullCluster) as Map)['properties']
                      as Map)['cluster_id']
                  as num)
              .toInt();

      final leaves = await pumpUntil(
        tester,
        controller.getClusterLeaves(_clusterSourceId, clusterId),
        'getClusterLeaves',
      );
      expect(_idsByName(leaves), _expectedIds);
      _expectOwnProperties(leaves);

      // A child is a smaller cluster or one of the features.
      final children = await pumpUntil(
        tester,
        controller.getClusterChildren(_clusterSourceId, clusterId),
        'getClusterChildren',
      );
      expect(children, isNotEmpty);
      final ids = _idsByName(children);
      for (final MapEntry(:key, :value) in ids.entries) {
        expect(value, _expectedIds[key], reason: 'child $key');
      }
      _expectOwnProperties([
        for (final child in children)
          if (!_isCluster(child)) child,
      ]);
    });

    testWidgets('after setGeoJsonSource, editGeoJsonSource and '
        'setGeoJsonFeature', (tester) async {
      final controller = await _pumpMapWithFeatures(tester, data: _point99);
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => features.isNotEmpty,
        'querySourceFeatures before the update',
      );

      await pumpUntil(
        tester,
        controller.setGeoJsonSource(_sourceId, _featureCollection()),
        'setGeoJsonSource',
      );
      expect(
        _idsByName(await _waitForAll(tester, controller)),
        _expectedIds,
        reason: 'setGeoJsonSource',
      );

      await pumpUntil(
        tester,
        controller.setGeoJsonSource(_sourceId, _point99),
        'setGeoJsonSource back',
      );
      await pumpUntil(
        tester,
        controller.editGeoJsonSource(
          _sourceId,
          jsonEncode(_featureCollection()),
        ),
        'editGeoJsonSource',
      );
      expect(
        _idsByName(await _waitForAll(tester, controller)),
        _expectedIds,
        reason: 'editGeoJsonSource',
      );

      // Moved by a degree, so the query can tell the new feature apart.
      for (final name in ['decimal', 'name']) {
        final feature = _features[name]!;
        await pumpUntil(
          tester,
          controller.setGeoJsonFeature(
            _sourceId,
            _feature(
              name,
              feature.id,
              LatLng(feature.at.latitude, feature.at.longitude + 1),
            ),
          ),
          'setGeoJsonFeature $name',
        );
      }
      final features = await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) =>
            _longitudeOf(features, 'decimal') > -7.5 &&
            _longitudeOf(features, 'name') > 8.5,
        'setGeoJsonFeature applied',
      );
      expect(_idsByName(features), _expectedIds, reason: 'setGeoJsonFeature');
      _expectOwnProperties(features);
    });
  });

  // Data from a URL does not pass through the plugin, so its ids are the ones
  // MapLibre keeps. A data: URL reaches maplibre-gl-js only.
  testWidgets('a url gives the ids MapLibre keeps, and setGeoJsonSource '
      'brings back the ones of the data', (tester) async {
    if (testPlatform != TestPlatform.web) return;
    final controller = await _pumpMapWithFeatures(tester);
    await _waitForAll(tester, controller);

    final url =
        Uri.dataFromString(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              _feature('five', 5, _features['number']!.at),
              _feature('six', 6, _features['text']!.at),
            ],
          }),
          mimeType: 'application/json',
        ).toString();
    await pumpUntil(
      tester,
      controller.editGeoJsonUrl(_sourceId, url),
      'editGeoJsonUrl',
    );
    final fromUrl = await pumpUntilValue(
      tester,
      () => controller.querySourceFeatures(_sourceId, null, null),
      (features) => _idsByName(features).length == 2,
      'querySourceFeatures after editGeoJsonUrl',
    );
    expect(_idsByName(fromUrl), {'five': 5, 'six': 6});

    await pumpUntil(
      tester,
      controller.setGeoJsonSource(_sourceId, _featureCollection()),
      'setGeoJsonSource',
    );
    expect(_idsByName(await _waitForAll(tester, controller)), _expectedIds);
  });

  group('an id filter selects the feature with that id', () {
    testWidgets('in the queries', (tester) async {
      final controller = await _pumpMapWithFeatures(tester);
      await _waitForAll(tester, controller);
      final rect = await _allFeaturesRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _idsByName(features).length == _features.length,
        'every feature drawn',
      );

      for (final MapEntry(:key, :value) in _features.entries) {
        final filter = [
          '==',
          ['id'],
          value.id,
        ];
        final source = await pumpUntil(
          tester,
          controller.querySourceFeatures(_sourceId, null, filter),
          'querySourceFeatures with $filter',
        );
        expect(_idsByName(source).keys, [key], reason: 'source: $filter');

        final point = await _screen(tester, controller, value.at);
        final rendered = await pumpUntil(
          tester,
          controller.queryRenderedFeatures(point, [_layerId], filter),
          'queryRenderedFeatures with $filter',
        );
        expect(_idsByName(rendered).keys, [key], reason: 'point: $filter');

        final inRect = await pumpUntil(
          tester,
          controller.queryRenderedFeaturesInRect(rect, [
            _layerId,
          ], jsonEncode(filter)),
          'queryRenderedFeaturesInRect with $filter',
        );
        expect(_idsByName(inRect).keys, [key], reason: 'rect: $filter');
      }
    });

    testWidgets('in a layer filter, which reads back as set', (tester) async {
      final controller = await _pumpMapWithFeatures(tester);
      await _waitForAll(tester, controller);
      final rect = await _allFeaturesRect(tester, controller);

      for (final MapEntry(:key, :value) in _features.entries) {
        final filter = [
          '==',
          ['id'],
          value.id,
        ];
        await pumpUntil(
          tester,
          controller.setLayerFilter(_layerId, filter),
          'setLayerFilter $filter',
        );
        await pumpUntilValue(
          tester,
          () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
          (features) => _sameKeys(_idsByName(features).keys, [key]),
          'only $key drawn with $filter',
        );
        expect(
          await pumpUntil(
            tester,
            controller.getLayerFilter(_layerId),
            'getLayerFilter',
          ),
          filter,
        );
        // iOS reads layers from the style it loaded, without those added since.
        if (testPlatform != TestPlatform.ios) {
          final layer = await pumpUntil(
            tester,
            controller.getLayerProperties(_layerId),
            'getLayerProperties',
          );
          expect(layer?['filter'], filter);
        }
      }
    });
  });

  testWidgets('feature state follows the feature with that id', (
    tester,
  ) async {
    // The iOS SDK has no feature state API: see geojson_query_test.dart.
    if (testPlatform == TestPlatform.ios) return;
    final controller = await _pumpMapWithFeatures(
      tester,
      circleRadius: _bigByState,
    );
    await _waitForAll(tester, controller);

    for (final name in ['decimal', 'name']) {
      await _expectGrownByState(tester, controller, name, _expectedIds);
    }
  });

  testWidgets('nothing the plugin adds shows in the source or the style', (
    tester,
  ) async {
    final controller = await _pumpMapWithFeatures(tester);
    await _waitForAll(tester, controller);
    await pumpUntil(
      tester,
      controller.setLayerFilter(_layerId, [
        '==',
        ['id'],
        'poi-12',
      ]),
      'setLayerFilter',
    );

    final source = await pumpUntil(
      tester,
      controller.getSourceProperties(_sourceId),
      'getSourceProperties',
    );
    // iOS reads sources from the style it loaded, without those added since.
    if (testPlatform != TestPlatform.ios) expect(source?['type'], 'geojson');
    expect(source ?? const {}, isNot(contains('promoteId')));
    expect(jsonEncode(source), isNot(contains(_reserved)));

    final style = await pumpUntil(tester, controller.getStyle(), 'getStyle');
    expect(style, isNot(contains(_reserved)));
  });

  testWidgets('a promoteId of the app is kept on web', (tester) async {
    if (testPlatform != TestPlatform.web) return;
    final controller = await pumpMap(tester);
    await pumpUntil(
      tester,
      controller.addGeoJsonSource(_sourceId, {
        'type': 'FeatureCollection',
        'features': [
          _feature('name', 'poi-12', _features['name']!.at, ref: 'ref-1'),
        ],
      }, promoteId: 'ref'),
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

    final features = await pumpUntilValue(
      tester,
      () => controller.querySourceFeatures(_sourceId, null, null),
      (features) => features.isNotEmpty,
      'querySourceFeatures',
    );
    expect(_idsByName(features), {'name': 'ref-1'});
    expect(
      (await pumpUntil(
        tester,
        controller.getSourceProperties(_sourceId),
        'getSourceProperties',
      ))?['promoteId'],
      'ref',
    );
  });

  // generateId numbers the features by their index, over their own ids.
  group('a source with generateId keeps the ids it generates', () {
    testWidgets('in the queries and an id filter, also after '
        'setGeoJsonSource', (tester) async {
      final controller = await _pumpMapWithFeatures(tester, generateId: true);
      final features = await _waitForAll(tester, controller);
      expect(_idsByName(features), _generatedIds);
      _expectOwnProperties(features);

      final filter = <Object>[
        '==',
        ['id'],
        _generatedIds['name']!,
      ];
      expect(
        _idsByName(
          await pumpUntil(
            tester,
            controller.querySourceFeatures(_sourceId, null, filter),
            'querySourceFeatures with $filter',
          ),
        ).keys,
        ['name'],
      );

      // The same features the other way round, numbered again.
      final reversed = {
        'type': 'FeatureCollection',
        'features':
            (_featureCollection()['features'] as List).reversed.toList(),
      };
      await pumpUntil(
        tester,
        controller.setGeoJsonSource(_sourceId, reversed),
        'setGeoJsonSource',
      );
      final renumbered = await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => _idsByName(features)['name'] == 0,
        'querySourceFeatures after setGeoJsonSource',
      );
      expect(_idsByName(renumbered), {
        for (final MapEntry(:key, :value) in _generatedIds.entries)
          key: _features.length - 1 - (value as int),
      });
    });

    testWidgets('in feature state', (tester) async {
      // The iOS SDK has no feature state API: see geojson_query_test.dart.
      if (testPlatform == TestPlatform.ios) return;
      final controller = await _pumpMapWithFeatures(
        tester,
        generateId: true,
        circleRadius: _bigByState,
      );
      await _waitForAll(tester, controller);

      await _expectGrownByState(tester, controller, 'name', _generatedIds);
    });

    // On web the tap is in feature_drag_web_test.dart.
    testWidgets('in a tap, on Android', (tester) async {
      if (testPlatform != TestPlatform.android) return;
      final taps = <String>[];
      final controller = await _pumpMapWithFeatures(tester, generateId: true);
      controller.onFeatureTapped.add(
        (point, latLng, id, layerId, annotation) => taps.add(id),
      );
      await _waitForAll(tester, controller);
      final rect = await _allFeaturesRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _idsByName(features).length == _features.length,
        'every feature drawn',
      );

      for (final MapEntry(:key, :value) in _features.entries) {
        final finger = _Finger(tester);
        await finger.down(await _onScreen(tester, controller, value.at));
        await finger.up();
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(taps, ['${_generatedIds[key]}'], reason: 'tap on $key');
        taps.clear();
      }
    });
  });

  group('taps and drags report the id as text', () {
    testWidgets('on Android', (tester) async {
      if (testPlatform != TestPlatform.android) return;
      final taps = <String>[];
      final drags = <String>{};
      final controller = await _pumpMapWithFeatures(tester);
      controller.onFeatureTapped.add(
        (point, latLng, id, layerId, annotation) => taps.add(id),
      );
      controller.onFeatureDrag.add(
        (point, origin, current, delta, id, annotation, type) => drags.add(id),
      );
      await _waitForAll(tester, controller);
      final rect = await _allFeaturesRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _idsByName(features).length == _features.length,
        'every feature drawn',
      );

      for (final MapEntry(:key, :value) in _features.entries) {
        final at = await _onScreen(tester, controller, value.at);
        final finger = _Finger(tester);
        await finger.down(at);
        await finger.up();
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(taps, [value.id.toString()], reason: 'tap on $key');
        taps.clear();

        await finger.down(at);
        for (var i = 0; i < 10; i++) {
          await finger.moveBy(const Offset(2, 0));
        }
        await finger.up();
        await pumpFor(tester, const Duration(milliseconds: 500));
        expect(drags, {value.id.toString()}, reason: 'drag of $key');
        drags.clear();
      }
    });
  });
}

/// The start of every property name the plugin reserves for itself.
const _reserved = 'maplibre_gl:';

/// One feature that is not among [_features], to start from other data.
final Map<String, dynamic> _point99 = {
  'type': 'FeatureCollection',
  'features': [_feature('other', 99, const LatLng(5, 0))],
};

Map<String, dynamic> _feature(
  String name,
  Object id,
  LatLng at, {
  String? ref,
}) => {
  'type': 'Feature',
  'id': id,
  'geometry': {
    'type': 'Point',
    'coordinates': [at.longitude, at.latitude],
  },
  'properties': {'name': name, 'draggable': true, if (ref != null) 'ref': ref},
};

Map<String, dynamic> _featureCollection({LatLng Function(LatLng at)? place}) =>
    {
      'type': 'FeatureCollection',
      'features': [
        for (final MapEntry(:key, :value) in _features.entries)
          _feature(key, value.id, place?.call(value.at) ?? value.at),
      ],
    };

/// A map with [data] (by default [_features]) in [_sourceId], drawn as
/// circles of [circleRadius] in [_layerId]. With [generateId], the source is
/// added with addSource and `generateId`.
Future<MapLibreMapController> _pumpMapWithFeatures(
  WidgetTester tester, {
  Map<String, dynamic>? data,
  Object circleRadius = _radius,
  bool generateId = false,
}) async {
  final controller = await pumpMap(tester);
  data ??= _featureCollection();
  await pumpUntil(
    tester,
    generateId
        ? controller.addSource(
          _sourceId,
          GeojsonSourceProperties(data: data, generateId: true),
        )
        : controller.addGeoJsonSource(_sourceId, data),
    'add the source',
  );
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _sourceId,
      _layerId,
      CircleLayerProperties(circleRadius: circleRadius),
    ),
    'addCircleLayer',
  );
  return controller;
}

/// A map with [_features] packed within a few pixels of each other, in a
/// clustered source added with addSource, so they form a single cluster.
Future<MapLibreMapController> _pumpMapWithCluster(WidgetTester tester) async {
  final controller = await pumpMap(tester);
  var i = 0;
  await pumpUntil(
    tester,
    controller.addSource(
      _clusterSourceId,
      GeojsonSourceProperties(
        data: _featureCollection(
          place: (_) => LatLng(10 + 0.05 * (i % 2), 10 + 0.05 * i++),
        ),
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

/// Polls [_sourceId] until it holds every one of [_features].
Future<List> _waitForAll(
  WidgetTester tester,
  MapLibreMapController controller,
) => pumpUntilValue(
  tester,
  () => controller.querySourceFeatures(_sourceId, null, null),
  (features) => _sameKeys(_idsByName(features).keys, _features.keys),
  'querySourceFeatures with every feature',
);

/// The id of each feature in [features], by its `name` property. A feature
/// near a tile edge can be reported once per tile, with the same id.
Map<String, Object?> _idsByName(List features) => {
  for (final feature in features.cast<Map>())
    if ((feature['properties'] as Map?)?['name'] case final String name)
      name: feature['id'],
};

/// Expects the properties of [features] to be the ones they were added with.
void _expectOwnProperties(List features) {
  for (final feature in features.cast<Map>()) {
    final properties = feature['properties'] as Map;
    expect(
      properties.keys.toSet(),
      {'name', 'draggable'},
      reason: 'properties of ${properties['name']}',
    );
  }
}

bool _isCluster(dynamic feature) =>
    ((feature as Map)['properties'] as Map?)?['cluster_id'] != null;

bool _isFullCluster(dynamic feature) =>
    _isCluster(feature) &&
    (((feature as Map)['properties'] as Map)['point_count'] as num).toInt() ==
        _features.length;

bool _sameKeys(Iterable<String> a, Iterable<String> b) =>
    a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

double _longitudeOf(List features, String name) {
  for (final feature in features.cast<Map>()) {
    if ((feature['properties'] as Map?)?['name'] == name) {
      final coordinates = (feature['geometry'] as Map)['coordinates'] as List;
      return (coordinates[0] as num).toDouble();
    }
  }
  return double.negativeInfinity;
}

/// Screen units per logical pixel in queries: physical pixels on Android.
double _queryScale(WidgetTester tester) =>
    testPlatform == TestPlatform.android ? tester.view.devicePixelRatio : 1.0;

/// The screen location of [latLng], in the units the queries take.
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

/// Where [latLng] is in global logical coordinates, for a gesture.
Future<Offset> _onScreen(
  WidgetTester tester,
  MapLibreMapController controller,
  LatLng latLng,
) async {
  final point = await _screen(tester, controller, latLng);
  final scale = _queryScale(tester);
  return tester.getTopLeft(find.byType(MapLibreMap)) +
      Offset(point.x / scale, point.y / scale);
}

/// A screen rectangle around every one of [_features].
Future<Rect> _allFeaturesRect(
  WidgetTester tester,
  MapLibreMapController controller,
) async {
  final a = await _screen(tester, controller, const LatLng(15, -20));
  final b = await _screen(tester, controller, const LatLng(-15, 20));
  return Rect.fromPoints(Offset(a.x, a.y), Offset(b.x, b.y));
}

/// A circle radius of [_bigRadius] for a feature with the `big` feature
/// state, and [_radius] otherwise.
const List<Object> _bigByState = [
  'case',
  [
    'boolean',
    ['feature-state', 'big'],
    false,
  ],
  _bigRadius,
  _radius,
];

/// Expects the feature [name] to grow with the `big` feature state set on
/// its id in [ids], and to shrink back once the state is removed.
Future<void> _expectGrownByState(
  WidgetTester tester,
  MapLibreMapController controller,
  String name,
  Map<String, Object> ids,
) async {
  final id = ids[name]!.toString();
  // Inside the big circle only, on the side away from the other features.
  final center = await _screen(tester, controller, _features[name]!.at);
  final side = _features[name]!.at.longitude < 0 ? -1 : 1;
  final scale = _queryScale(tester);
  final edge = Point<double>(
    center.x + side * 20 * scale,
    center.y + 15 * scale,
  );
  Future<List> queryEdge() =>
      controller.queryRenderedFeatures(edge, [_layerId], null);
  expect(
    _idsByName(await pumpUntil(tester, queryEdge(), 'query $name edge')),
    isEmpty,
  );

  await pumpUntil(
    tester,
    controller.setFeatureState(_sourceId, id, {'big': true}),
    'setFeatureState $id',
  );
  final grown = await pumpUntilValue(
    tester,
    queryEdge,
    (features) => _idsByName(features).isNotEmpty,
    '$name grown by its feature state',
  );
  expect(_idsByName(grown), {name: ids[name]});
  expect(
    await pumpUntil(
      tester,
      controller.getFeatureState(_sourceId, id),
      'getFeatureState $id',
    ),
    {'big': true},
  );

  await pumpUntil(
    tester,
    controller.removeFeatureState(_sourceId, featureId: id),
    'removeFeatureState $id',
  );
  await pumpUntilValue(
    tester,
    queryEdge,
    (features) => _idsByName(features).isEmpty,
    '$name back to its size',
  );
}

/// One finger whose events carry real timestamps: with the zero timestamps of
/// a plain `TestGesture`, Android takes every touch for a long press.
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

  Future<void> moveBy(Offset by) async {
    await _gesture.moveBy(by, timeStamp: _now);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> up() => _gesture.up(timeStamp: _now);
}
