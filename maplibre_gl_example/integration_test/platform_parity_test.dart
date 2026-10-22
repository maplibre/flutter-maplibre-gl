// Integration tests for calls that must answer the same on Android, iOS and
// web, errors included: feature queries and filters, image sources, layer
// adds (missing or incompatible source, belowLayerId, filter, property
// values, source layer, zoom range), setLayerProperties, the GeoJSON source
// calls and their data, addSource, removeSource, getSourceProperties of image
// sources, colors, NaN coordinates, setCameraBounds, takeSnapshot, and the
// calls made while no style is loaded.
//
// The calls without a style run on Android and iOS only: web cannot drop a
// loaded style, so a web unit test covers them there. Video sources are web
// only.
//
// Run on Android or iOS:
//   flutter test integration_test/platform_parity_test.dart -d <device id>
//
// Run on Chrome (with chromedriver on :4444):
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/platform_parity_test.dart \
//     -d web-server
import 'dart:convert';
import 'dart:math' show Point;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'support/map_harness.dart';

const _sourceId = 'points';
const _layerId = 'points-circle';

/// Three points away from the zoom 3 tile edges and far apart on screen, with
/// ids and `n` 1, 2 and 3.
const _p1 = LatLng(5, -8);
const _p2 = LatLng(5, 8);
const _p3 = LatLng(-6, -8);

/// An expression MapLibre rejects on every platform: the operator does not
/// exist.
const List<Object> _unknownOperator = ['no-such-operator', 1];

/// The message of STYLE_NOT_READY, the same on Android and iOS.
const _styleNotReadyMessage =
    'Style is null or not fully loaded. Has onStyleLoaded() already been '
    'invoked?';

/// A style that fails to parse, so the map holds no style after setStyle.
const _brokenStyle = '{"version": 8, "sources": {}, "layers": [';

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

/// A FeatureCollection of [_p1] alone, with id 1 and `n` 1.
const Map<String, dynamic> _onePoint = {
  'type': 'FeatureCollection',
  'features': [
    {
      'type': 'Feature',
      'id': 1,
      'geometry': {
        'type': 'Point',
        'coordinates': [-8.0, 5.0],
      },
      'properties': {'n': 1},
    },
  ],
};

/// Tiles and an image that never load: the host does not exist, so nothing
/// leaves the device.
const _tileUrl = 'https://tiles.invalid/{z}/{x}/{y}.png';
const _imageUrl = 'https://tiles.invalid/image.png';

/// [_quad] and [_movedQuad] as the style spec writes the corners of an image
/// source: [longitude, latitude] from the top left, clockwise.
const List<List<num>> _corners = [
  [-2, 2],
  [2, 2],
  [2, -2],
  [-2, -2],
];
const List<List<num>> _movedCorners = [
  [-4, 4],
  [4, 4],
  [4, -4],
  [-4, -4],
];

/// Data that is not GeoJSON: each fails the same way on every platform.
final Map<String, Map<String, dynamic>> _notGeoJson = {
  'no type': {
    'coordinates': [1, 2],
  },
  'an unknown type': {
    'type': 'Circle',
    'coordinates': [1, 2],
  },
  'a FeatureCollection without features': {'type': 'FeatureCollection'},
  'features that are not a list': {
    'type': 'FeatureCollection',
    'features': <String, dynamic>{},
  },
  'a geometry in place of a feature': {
    'type': 'FeatureCollection',
    'features': [
      {
        'type': 'Point',
        'coordinates': [1, 2],
      },
    ],
  },
  'a Feature without a geometry member': {
    'type': 'Feature',
    'properties': <String, dynamic>{},
  },
  'a Point without coordinates': {'type': 'Point'},
  'a Point of one number': {
    'type': 'Point',
    'coordinates': [1],
  },
  'a LineString with a short position': {
    'type': 'LineString',
    'coordinates': [
      [1, 2],
      [3],
    ],
  },
  'a Polygon of positions': {
    'type': 'Polygon',
    'coordinates': [
      [1, 2],
      [3, 4],
    ],
  },
  'properties that are not an object': {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
    'properties': 'none',
  },
  'an id that is a boolean': {
    'type': 'Feature',
    'id': true,
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
  },
  'a GeometryCollection without geometries': {'type': 'GeometryCollection'},
  // MapLibre Native rejects it, where maplibre-gl-js reads it as no id.
  'a null id': {
    'type': 'Feature',
    'id': null,
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
    'properties': <String, dynamic>{},
  },
};

/// GeoJSON MapLibre reads, at the edges of what the spec allows: each goes in
/// on every platform.
final Map<String, Map<String, dynamic>> _geoJson = {
  'an empty FeatureCollection': {
    'type': 'FeatureCollection',
    'features': <Object>[],
  },
  'a bare geometry': {
    'type': 'Point',
    'coordinates': [1, 2],
  },
  'a Feature without properties': {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
  },
  'a Feature with null properties': {
    'type': 'Feature',
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
    'properties': null,
  },
  'a Feature with a null geometry': {
    'type': 'Feature',
    'id': 'a',
    'geometry': null,
    'properties': <String, dynamic>{},
  },
  'a GeometryCollection': {
    'type': 'GeometryCollection',
    'geometries': [
      {
        'type': 'Point',
        'coordinates': [1, 2],
      },
      {
        'type': 'LineString',
        'coordinates': [
          [1, 2],
          [3, 4],
        ],
      },
    ],
  },
  'positions with an altitude': {
    'type': 'LineString',
    'coordinates': [
      [1, 2, 10],
      [3, 4, 20],
    ],
  },
  'members MapLibre does not read': {
    'type': 'Feature',
    'bbox': [1, 2, 1, 2],
    'foreign': {'any': 'thing'},
    'geometry': {
      'type': 'Point',
      'coordinates': [1, 2],
    },
    'properties': <String, dynamic>{},
  },
};

/// Bytes that no platform decodes as an image.
final Uint8List _notAnImage = Uint8List.fromList(utf8.encode('not an image'));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('query filters', () {
    testWidgets('an invalid filter fails every query with INVALID_EXPRESSION', (
      tester,
    ) async {
      final controller = await _pumpMapWithPoints(tester);
      final p1 = await _screen(tester, controller, _p1);
      await _waitForRendered(tester, controller, p1);
      final rect = await _leftColumnRect(tester, controller);

      await _expectInvalidFilter(
        tester,
        controller.queryRenderedFeatures(p1, [_layerId], _unknownOperator),
        'queryRenderedFeatures',
      );
      await _expectInvalidFilter(
        tester,
        controller.queryRenderedFeaturesInRect(rect, [
          _layerId,
        ], jsonEncode(_unknownOperator)),
        'queryRenderedFeaturesInRect',
      );
      await _expectInvalidFilter(
        tester,
        controller.querySourceFeatures(_sourceId, null, _unknownOperator),
        'querySourceFeatures',
      );
      // A known operator with the wrong arguments, and an array that is not
      // an expression at all.
      await _expectInvalidFilter(
        tester,
        controller.querySourceFeatures(_sourceId, null, [
          '==',
          ['get', 'n'],
        ]),
        'querySourceFeatures, missing argument',
      );
      await _expectInvalidFilter(
        tester,
        controller.querySourceFeatures(_sourceId, null, [1, 2]),
        'querySourceFeatures, not an expression',
      );

      // The map is still there and still answers.
      final features = await pumpUntil(
        tester,
        controller.queryRenderedFeatures(
          p1,
          [_layerId],
          [
            '==',
            ['get', 'n'],
            1,
          ],
        ),
        'queryRenderedFeatures after the errors',
      );
      expect(_ids(features), {1});
    });

    testWidgets('the rect query filters only with an expression array', (
      tester,
    ) async {
      final controller = await _pumpMapWithPoints(tester);
      final rect = await _leftColumnRect(tester, controller);
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeaturesInRect(rect, [_layerId], null),
        (features) => _ids(features).containsAll({1, 3}),
        'queryRenderedFeaturesInRect',
      );

      // Like the point and source queries: any other JSON value is no filter.
      for (final filter in ['false', 'true', '3', '{"n": 3}', 'null']) {
        final features = await pumpUntil(
          tester,
          controller.queryRenderedFeaturesInRect(rect, [_layerId], filter),
          'queryRenderedFeaturesInRect with $filter',
        );
        expect(_ids(features), {1, 3}, reason: 'filter $filter');
      }

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
        'queryRenderedFeaturesInRect with an expression',
      );
      expect(_ids(filtered), {3});

      // Text that is not JSON cannot be a filter.
      final error = await expectPlatformError(
        tester,
        controller.queryRenderedFeaturesInRect(rect, [_layerId], 'n == 3'),
        'queryRenderedFeaturesInRect with text that is not JSON',
        code: 'INVALID_EXPRESSION',
      );
      expect(error.message, 'Invalid filter: Not valid JSON.');
    });

    testWidgets('a query filter keeps its numbers exact', (tester) async {
      final controller = await pumpMap(tester);
      // 123456789 as a float is 123456792: a filter rounded that way picks
      // the other feature.
      await pumpUntil(
        tester,
        controller.addGeoJsonSource(_sourceId, {
          'type': 'FeatureCollection',
          'features': [
            _point(1, _p1, {'n': 123456789}),
            _point(2, _p2, {'n': 123456792}),
          ],
        }),
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
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => _ids(features).containsAll({1, 2}),
        'querySourceFeatures',
      );

      final features = await pumpUntil(
        tester,
        controller.querySourceFeatures(_sourceId, null, [
          '==',
          ['get', 'n'],
          123456789,
        ]),
        'querySourceFeatures with a large number',
      );
      expect(_ids(features), {1});
    });
  });

  group('setLayerFilter of the platform', () {
    testWidgets('sets a valid filter on every layer type that has one, and '
        'answers false for anything else', (tester) async {
      final (controller, platform) = await _pumpMapWithPlatform(tester);
      await _addPoints(tester, controller);
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          _layerId,
          const CircleLayerProperties(circleRadius: 6),
        ),
        'addCircleLayer',
      );
      await pumpUntil(
        tester,
        controller.addHeatmapLayer(
          _sourceId,
          'points-heatmap',
          const HeatmapLayerProperties(heatmapRadius: 20),
        ),
        'addHeatmapLayer',
      );
      await pumpUntil(
        tester,
        controller.addFillExtrusionLayer(
          _sourceId,
          'points-extrusion',
          const FillExtrusionLayerProperties(fillExtrusionHeight: 10),
        ),
        'addFillExtrusionLayer',
      );

      const filter = [
        '==',
        ['get', 'n'],
        2,
      ];
      // Every layer type that has a filter takes one.
      for (final layerId in [_layerId, 'points-heatmap', 'points-extrusion']) {
        expect(
          await _setLayerFilter(tester, platform, layerId, jsonEncode(filter)),
          isTrue,
          reason: layerId,
        );
        expect(
          await pumpUntil(
            tester,
            controller.getLayerFilter(layerId),
            'getLayerFilter $layerId',
          ),
          filter,
          reason: layerId,
        );
      }

      // A filter MapLibre rejects answers false, and the layer keeps its
      // filter.
      for (final rejected in [
        jsonEncode(_unknownOperator),
        jsonEncode([
          '==',
          ['get', 'n'],
        ]),
        '5',
        'n == 2',
      ]) {
        expect(
          await _setLayerFilter(tester, platform, _layerId, rejected),
          isFalse,
          reason: rejected,
        );
      }
      expect(
        await pumpUntil(
          tester,
          controller.getLayerFilter(_layerId),
          'getLayerFilter after the rejected filters',
        ),
        filter,
      );

      // No such layer, and a layer type without a filter.
      expect(
        await _setLayerFilter(tester, platform, 'missing', jsonEncode(filter)),
        isFalse,
      );
      expect(
        await _setLayerFilter(
          tester,
          platform,
          backgroundLayerId,
          jsonEncode(filter),
        ),
        isFalse,
      );

      // The text null removes the filter, as for setLayerFilter of the
      // controller.
      expect(await _setLayerFilter(tester, platform, _layerId, 'null'), isTrue);
      expect(
        await pumpUntil(
          tester,
          controller.getLayerFilter(_layerId),
          'getLayerFilter after null',
        ),
        isNull,
      );
    });
  });

  group('image sources', () {
    testWidgets('addImageSource rejects an id in use with '
        'SOURCE_ALREADY_EXISTS', (tester) async {
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await _addPoints(tester, controller);
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      await expectPlatformError(
        tester,
        controller.addImageSource('image', image, _movedQuad),
        'addImageSource with the id of an image source',
        code: 'SOURCE_ALREADY_EXISTS',
      );
      await expectPlatformError(
        tester,
        controller.addImageSource(_sourceId, image, _quad),
        'addImageSource with the id of a GeoJSON source',
        code: 'SOURCE_ALREADY_EXISTS',
      );
      // The id is checked before the bytes.
      await expectPlatformError(
        tester,
        controller.addImageSource('image', _notAnImage, _quad),
        'addImageSource with an id in use and bytes that are not an image',
        code: 'SOURCE_ALREADY_EXISTS',
      );
      await expectPlatformError(
        tester,
        controller.addImageSource('other-image', _notAnImage, _quad),
        'addImageSource with bytes that are not an image',
        code: 'INVALID_IMAGE',
      );

      final ids = await pumpUntil(
        tester,
        controller.getSourceIds(),
        'getSourceIds',
      );
      expect(ids.where((id) => id == 'image'), hasLength(1));
      expect(ids, isNot(contains('other-image')));
    });

    testWidgets('updateImageSource with bytes that are not an image fails '
        'before it changes anything', (tester) async {
      final controller = await pumpMap(tester);
      final first = await _loadPng(tester, 'assets/sydney0.png');
      final second = await _loadPng(tester, 'assets/sydney1.png');
      await pumpUntil(
        tester,
        controller.addImageSource('image', first, _quad),
        'addImageSource',
      );
      await pumpUntil(
        tester,
        controller.addImageLayer('image-layer', 'image'),
        'addImageLayer',
      );

      // A failed call must not move the corners. No call reads them back, so
      // this checks the error and that the source still updates.
      await expectPlatformError(
        tester,
        controller.updateImageSource('image', _notAnImage, _movedQuad),
        'updateImageSource with bytes that are not an image',
        code: 'INVALID_IMAGE',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        contains('image'),
      );
      await pumpUntil(
        tester,
        controller.updateImageSource('image', second, _movedQuad),
        'updateImageSource with an image',
      );
    });
  });

  group('layer adds', () {
    testWidgets('a missing source fails with SOURCE_NOT_FOUND', (tester) async {
      final controller = await pumpMap(tester);
      final layersBefore = await pumpUntil(
        tester,
        controller.getLayerIds(),
        'getLayerIds',
      );

      final calls = <String, Future<Object?> Function()>{
        'addCircleLayer':
            () => controller.addCircleLayer(
              'no-such-source',
              'circles',
              const CircleLayerProperties(),
            ),
        'addLayer':
            () => controller.addLayer(
              'no-such-source',
              'lines',
              const LineLayerProperties(),
            ),
        'addRasterLayer':
            () => controller.addRasterLayer(
              'no-such-source',
              'raster',
              const RasterLayerProperties(),
            ),
        'addImageLayer':
            () => controller.addImageLayer('image-layer', 'no-such-source'),
        'addImageLayerBelow':
            () => controller.addImageLayerBelow(
              'image-below',
              'no-such-source',
              backgroundLayerId,
            ),
      };
      for (final call in calls.entries) {
        await expectPlatformError(
          tester,
          call.value(),
          call.key,
          code: 'SOURCE_NOT_FOUND',
        );
      }
      expect(
        await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
        layersBefore,
      );
    });

    testWidgets('a layer that cannot draw the type of its source fails with '
        'UNSUPPORTED_SOURCE_TYPE', (tester) async {
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await _addPoints(tester, controller);
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );
      await pumpUntil(
        tester,
        controller.addSource(
          'raster',
          const RasterSourceProperties(tiles: [_tileUrl], tileSize: 256),
        ),
        'addSource raster',
      );
      await pumpUntil(
        tester,
        controller.addSource(
          'dem',
          const RasterDemSourceProperties(tiles: [_tileUrl], tileSize: 256),
        ),
        'addSource raster-dem',
      );
      await pumpUntil(
        tester,
        controller.addSource(
          'vector',
          const VectorSourceProperties(tiles: [_tileUrl]),
        ),
        'addSource vector',
      );
      final layersBefore = await pumpUntil(
        tester,
        controller.getLayerIds(),
        'getLayerIds',
      );

      final calls = <(String, String, String, String), Future<void> Function()>{
        ('raster-on-geojson', 'raster', _sourceId, 'geojson'):
            () => controller.addRasterLayer(
              _sourceId,
              'raster-on-geojson',
              const RasterLayerProperties(),
            ),
        ('image-on-geojson', 'raster', _sourceId, 'geojson'):
            () => controller.addImageLayer('image-on-geojson', _sourceId),
        ('image-below-on-geojson', 'raster', _sourceId, 'geojson'):
            () => controller.addImageLayerBelow(
              'image-below-on-geojson',
              _sourceId,
              backgroundLayerId,
            ),
        ('hillshade-on-geojson', 'hillshade', _sourceId, 'geojson'):
            () => controller.addHillshadeLayer(
              _sourceId,
              'hillshade-on-geojson',
              const HillshadeLayerProperties(),
            ),
        ('fill-on-raster', 'fill', 'raster', 'raster'):
            () => controller.addFillLayer(
              'raster',
              'fill-on-raster',
              const FillLayerProperties(),
            ),
        ('line-on-raster', 'line', 'raster', 'raster'):
            () => controller.addLayer(
              'raster',
              'line-on-raster',
              const LineLayerProperties(),
            ),
        ('hillshade-on-raster', 'hillshade', 'raster', 'raster'):
            () => controller.addHillshadeLayer(
              'raster',
              'hillshade-on-raster',
              const HillshadeLayerProperties(),
            ),
        ('circle-on-image', 'circle', 'image', 'image'):
            () => controller.addCircleLayer(
              'image',
              'circle-on-image',
              const CircleLayerProperties(),
            ),
        ('symbol-on-image', 'symbol', 'image', 'image'):
            () => controller.addSymbolLayer(
              'image',
              'symbol-on-image',
              const SymbolLayerProperties(),
            ),
        ('heatmap-on-image', 'heatmap', 'image', 'image'):
            () => controller.addHeatmapLayer(
              'image',
              'heatmap-on-image',
              const HeatmapLayerProperties(),
            ),
        ('extrusion-on-image', 'fill-extrusion', 'image', 'image'):
            () => controller.addFillExtrusionLayer(
              'image',
              'extrusion-on-image',
              const FillExtrusionLayerProperties(),
            ),
        ('relief-on-image', 'color-relief', 'image', 'image'):
            () => controller.addColorReliefLayer(
              'image',
              'relief-on-image',
              const ColorReliefLayerProperties(),
            ),
        ('raster-on-dem', 'raster', 'dem', 'raster-dem'):
            () => controller.addRasterLayer(
              'dem',
              'raster-on-dem',
              const RasterLayerProperties(),
            ),
        ('raster-on-vector', 'raster', 'vector', 'vector'):
            () => controller.addLayer(
              'vector',
              'raster-on-vector',
              const RasterLayerProperties(),
            ),
      };
      for (final MapEntry(key: (layerId, type, sourceId, sourceType), :value)
          in calls.entries) {
        final error = await expectPlatformError(
          tester,
          value(),
          layerId,
          code: 'UNSUPPORTED_SOURCE_TYPE',
        );
        expect(
          error.message,
          "Layer '$layerId' of type '$type' cannot use source '$sourceId' of "
          "type '$sourceType'.",
        );
      }
      expect(
        await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
        layersBefore,
      );

      // The layers that can draw these sources still go in.
      final valid = <String, Future<void> Function()>{
        'raster-on-image':
            () => controller.addImageLayer('raster-on-image', 'image'),
        'raster-on-raster':
            () => controller.addRasterLayer(
              'raster',
              'raster-on-raster',
              const RasterLayerProperties(),
            ),
        'hillshade-on-dem':
            () => controller.addHillshadeLayer(
              'dem',
              'hillshade-on-dem',
              const HillshadeLayerProperties(),
            ),
        'line-on-vector':
            () => controller.addLineLayer(
              'vector',
              'line-on-vector',
              const LineLayerProperties(),
              sourceLayer: 'roads',
            ),
        'circle-on-geojson':
            () => controller.addCircleLayer(
              _sourceId,
              'circle-on-geojson',
              const CircleLayerProperties(),
            ),
      };
      for (final call in valid.entries) {
        await pumpUntil(tester, call.value(), call.key);
      }
      expect(
        await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
        [...layersBefore, ...valid.keys],
      );
    });

    testWidgets('a missing belowLayerId puts the layer on top', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await _addPoints(tester, controller);
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      final calls = <String, Future<Object?> Function()>{
        'circles':
            () => controller.addCircleLayer(
              _sourceId,
              'circles',
              const CircleLayerProperties(),
              belowLayerId: 'no-such-layer',
            ),
        'image-below':
            () => controller.addImageLayerBelow(
              'image-below',
              'image',
              'no-such-layer',
            ),
        'second-background':
            () => controller.addBackgroundLayer(
              'second-background',
              const BackgroundLayerProperties(backgroundOpacity: 0),
              belowLayerId: 'no-such-layer',
            ),
      };
      for (final call in calls.entries) {
        await pumpUntil(tester, call.value(), 'add ${call.key}');
        final ids = await pumpUntil(
          tester,
          controller.getLayerIds(),
          'getLayerIds',
        );
        expect(ids.last, call.key);
      }
    });

    testWidgets('an invalid filter fails with INVALID_EXPRESSION', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      await _addPoints(tester, controller);

      for (final filter in <Object>[
        _unknownOperator,
        [
          '==',
          ['get', 'n'],
        ],
        [1, 2],
      ]) {
        final error = await expectPlatformError(
          tester,
          controller.addCircleLayer(
            _sourceId,
            _layerId,
            const CircleLayerProperties(),
            filter: filter,
          ),
          'addCircleLayer with $filter',
          code: 'INVALID_EXPRESSION',
        );
        expect(error.message, startsWith('Invalid filter: '));
      }
      expect(
        await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
        isNot(contains(_layerId)),
      );

      // A valid filter still goes in.
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          _layerId,
          const CircleLayerProperties(),
          filter: [
            '==',
            ['get', 'n'],
            2,
          ],
        ),
        'addCircleLayer with a valid filter',
      );
      expect(
        await pumpUntil(
          tester,
          controller.getLayerFilter(_layerId),
          'getLayerFilter',
        ),
        [
          '==',
          ['get', 'n'],
          2,
        ],
      );
    });
  });

  group('GeoJSON source updates', () {
    testWidgets('a missing source fails with SOURCE_NOT_FOUND', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      await expectPlatformError(
        tester,
        controller.setGeoJsonSource('no-such-source', _onePoint),
        'setGeoJsonSource on a missing source',
        code: 'SOURCE_NOT_FOUND',
      );
      await expectPlatformError(
        tester,
        controller.setGeoJsonFeature(
          'no-such-source',
          _point(1, _p1, {'n': 5}),
        ),
        'setGeoJsonFeature on a missing source',
        code: 'SOURCE_NOT_FOUND',
      );
    });

    // Web answers SOURCE_NOT_FOUND for these until it makes the same change.
    testWidgets(
      'a source that is not GeoJSON fails with UNSUPPORTED_SOURCE_TYPE',
      (tester) async {
        final controller = await pumpMap(tester);
        final image = await _loadPng(tester, 'assets/sydney0.png');
        await pumpUntil(
          tester,
          controller.addImageSource('image', image, _quad),
          'addImageSource',
        );

        final calls = <String, Future<void> Function()>{
          'setGeoJsonSource':
              () => controller.setGeoJsonSource('image', _onePoint),
          'setGeoJsonFeature':
              () => controller.setGeoJsonFeature(
                'image',
                _point(1, _p1, {'n': 5}),
              ),
        };
        for (final call in calls.entries) {
          final error = await expectPlatformError(
            tester,
            call.value(),
            '${call.key} on an image source',
            code: 'UNSUPPORTED_SOURCE_TYPE',
          );
          expect(
            error.message,
            "Source 'image' is not a GeoJSON source. ${call.key} only applies "
            'to GeoJSON sources.',
          );
        }
      },
      skip: kIsWeb,
    );

    testWidgets('the cluster calls on a source that is not GeoJSON fail with '
        'UNSUPPORTED_SOURCE_TYPE', (tester) async {
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      final calls = <String, Future<Object?> Function()>{
        'getClusterExpansionZoom':
            () => controller.getClusterExpansionZoom('image', 1),
        'getClusterChildren': () => controller.getClusterChildren('image', 1),
        'getClusterLeaves': () => controller.getClusterLeaves('image', 1),
      };
      for (final call in calls.entries) {
        final error = await expectPlatformError(
          tester,
          call.value(),
          '${call.key} on an image source',
          code: 'UNSUPPORTED_SOURCE_TYPE',
        );
        expect(
          error.message,
          "Source 'image' is not a GeoJSON source. ${call.key} only applies "
          'to clustered GeoJSON sources.',
        );
      }
    });

    testWidgets('a source removed and added again leaves setGeoJsonFeature '
        'none of its old data', (tester) async {
      final controller = await pumpMap(tester);
      await pumpUntil(
        tester,
        controller.addGeoJsonSource(_sourceId, _onePoint),
        'addGeoJsonSource',
      );
      await pumpUntil(
        tester,
        controller.removeSource(_sourceId),
        'removeSource',
      );
      await pumpUntil(
        tester,
        controller.addSource(
          _sourceId,
          GeojsonSourceProperties(
            data: {
              'type': 'FeatureCollection',
              'features': [
                _point(2, _p2, {'n': 2}),
              ],
            },
          ),
        ),
        'addSource with other data',
      );
      // A layer, so the source has tiles to query.
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          _layerId,
          const CircleLayerProperties(circleRadius: 6),
        ),
        'addCircleLayer',
      );

      // Feature 1 was in the removed source only: nothing changes.
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
      await pumpFor(tester, const Duration(milliseconds: 500));
      final features = await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => features.isNotEmpty,
        'querySourceFeatures',
      );
      expect(_ids(features), {2});
    });

    testWidgets('setGeoJsonFeature takes a Feature only, and replaces it in '
        'a source of one Feature too', (tester) async {
      final controller = await pumpMap(tester);
      await pumpUntil(
        tester,
        controller.addGeoJsonSource(_sourceId, _point(1, _p1, {'n': 1})),
        'addGeoJsonSource with a Feature',
      );
      // A layer, so the source has tiles to query.
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          _layerId,
          const CircleLayerProperties(circleRadius: 6),
        ),
        'addCircleLayer',
      );

      for (final notAFeature in <Map<String, dynamic>>[
        {
          'type': 'Point',
          'coordinates': [_p1.longitude, _p1.latitude],
        },
        _onePoint,
      ]) {
        await expectPlatformError(
          tester,
          controller.setGeoJsonFeature(_sourceId, notAFeature),
          'setGeoJsonFeature with a ${notAFeature['type']}',
          code: 'INVALID_GEOJSON',
        );
      }

      // The data is a lone Feature, which counts as a collection of one.
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, [
          '==',
          ['get', 'n'],
          5,
        ]),
        (features) => _ids(features).contains(1),
        'querySourceFeatures after setGeoJsonFeature',
      );
    });

    testWidgets('setGeoJsonFeature changes nothing in a source it did not '
        'give its data', (tester) async {
      final controller = await pumpMap(tester);
      await pumpUntil(
        tester,
        controller.addSource(
          _sourceId,
          const GeojsonSourceProperties(data: _onePoint),
        ),
        'addSource',
      );

      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
    });
  });

  group('sources through addSource', () {
    testWidgets('a video source is web only, and a source with nothing to '
        'load INVALID_ARGUMENT', (tester) async {
      final controller = await pumpMap(tester);

      const video = VideoSourceProperties(
        urls: ['https://tiles.invalid/video.mp4'],
        coordinates: _corners,
      );
      if (kIsWeb) {
        await pumpUntil(
          tester,
          controller.addSource('video', video),
          'addSource video',
        );
      } else {
        final error = await expectPlatformError(
          tester,
          controller.addSource('video', video),
          'addSource video',
          code: 'UNSUPPORTED_SOURCE_TYPE',
        );
        expect(
          error.message,
          "Source 'video' is a video source. Video sources are only supported "
          'on web.',
        );
      }

      final sources = <String, SourceProperties>{
        'vector without url or tiles': const VectorSourceProperties(),
        'raster without url or tiles': const RasterSourceProperties(),
        'geojson without data': const GeojsonSourceProperties(),
        'image without a url': const ImageSourceProperties(
          coordinates: _corners,
        ),
        'image without corners': const ImageSourceProperties(url: _imageUrl),
        'image with three corners': ImageSourceProperties(
          url: _imageUrl,
          coordinates: _corners.take(3).toList(),
        ),
        'image with a corner off the map': const ImageSourceProperties(
          url: _imageUrl,
          coordinates: [
            [-2, 2],
            [2, 2],
            [2, -2],
            [-2, -95],
          ],
        ),
        'image with a corner of one number': const ImageSourceProperties(
          url: _imageUrl,
          coordinates: [
            [-2, 2],
            [2, 2],
            [2, -2],
            [-2],
          ],
        ),
      };
      for (final source in sources.entries) {
        final type = source.value.toJson()['type'];
        final error = await expectPlatformError(
          tester,
          controller.addSource('broken', source.value),
          'addSource ${source.key}',
          code: 'INVALID_ARGUMENT',
        );
        expect(
          error.message,
          "Source 'broken' cannot be built from its properties as a '$type' "
          'source.',
          reason: source.key,
        );
      }
      final ids = await pumpUntil(
        tester,
        controller.getSourceIds(),
        'getSourceIds',
      );
      expect(ids, isNot(contains('broken')));
      expect(ids.contains('video'), kIsWeb);
    });

    testWidgets('an image source from a url draws like any image source', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      await pumpUntil(
        tester,
        controller.addSource(
          'url-image',
          const ImageSourceProperties(url: _imageUrl, coordinates: _corners),
        ),
        'addSource image',
      );
      await pumpUntil(
        tester,
        controller.addImageLayer('url-image-layer', 'url-image'),
        'addImageLayer',
      );
      expect(
        await pumpUntil(
          tester,
          controller.getSourceProperties('url-image'),
          'getSourceProperties',
        ),
        {'type': 'image', 'url': _imageUrl, 'coordinates': _corners},
      );
    });

    testWidgets('getSourceProperties reads every image source the same way', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await pumpUntil(
        tester,
        controller.addImageSource('bytes-image', image, _quad),
        'addImageSource',
      );
      await pumpUntil(
        tester,
        controller.addSource(
          'url-image',
          const ImageSourceProperties(url: _imageUrl, coordinates: _corners),
        ),
        'addSource image',
      );
      Future<Map<String, dynamic>?> read(String sourceId) => pumpUntil(
        tester,
        controller.getSourceProperties(sourceId),
        'getSourceProperties $sourceId',
      );

      expect(await read('bytes-image'), {
        'type': 'image',
        'coordinates': _corners,
      });
      expect(await read('url-image'), {
        'type': 'image',
        'url': _imageUrl,
        'coordinates': _corners,
      });

      // The corners follow updateImageSource, and the url goes once the
      // source shows bytes.
      await pumpUntil(
        tester,
        controller.updateImageSource('bytes-image', null, _movedQuad),
        'updateImageSource corners',
      );
      await pumpUntil(
        tester,
        controller.updateImageSource('url-image', image, _movedQuad),
        'updateImageSource bytes',
      );
      for (final sourceId in ['bytes-image', 'url-image']) {
        expect(await read(sourceId), {
          'type': 'image',
          'coordinates': _movedCorners,
        }, reason: sourceId);
      }
    });
  });

  group('GeoJSON data', () {
    testWidgets('data that is not GeoJSON fails with INVALID_GEOJSON and '
        'changes nothing', (tester) async {
      final controller = await _pumpMapWithPoints(tester);
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) => _ids(features).containsAll({1, 2, 3}),
        'querySourceFeatures',
      );

      for (final notGeoJson in _notGeoJson.entries) {
        final data = notGeoJson.value;
        final label = notGeoJson.key;
        final calls = <String, Future<Object?> Function()>{
          'addGeoJsonSource':
              () => controller.addGeoJsonSource('new-source', data),
          'setGeoJsonSource':
              () => controller.setGeoJsonSource(_sourceId, data),
          'addSource':
              () => controller.addSource(
                'new-source',
                GeojsonSourceProperties(data: data),
              ),
          'editGeoJsonSource':
              () => controller.editGeoJsonSource(_sourceId, jsonEncode(data)),
        };
        for (final call in calls.entries) {
          final sourceId =
              call.key.startsWith('add') ? 'new-source' : _sourceId;
          final error = await expectPlatformError(
            tester,
            call.value(),
            '${call.key} with $label',
            code: 'INVALID_GEOJSON',
          );
          expect(
            error.message,
            startsWith("The data for source '$sourceId' is not GeoJSON: "),
            reason: '${call.key} with $label',
          );
        }
      }

      // Text that is not JSON, where a string is taken.
      final notJson = await expectPlatformError(
        tester,
        controller.editGeoJsonSource(_sourceId, 'not json'),
        'editGeoJsonSource with text that is not JSON',
        code: 'INVALID_GEOJSON',
      );
      expect(
        notJson.message,
        "The data for source '$_sourceId' is not GeoJSON: Not valid JSON.",
      );

      // A Feature MapLibre cannot read.
      final feature = await expectPlatformError(
        tester,
        controller.setGeoJsonFeature(_sourceId, {
          'type': 'Feature',
          'id': 1,
          'properties': {'n': 5},
        }),
        'setGeoJsonFeature without a geometry',
        code: 'INVALID_GEOJSON',
      );
      expect(
        feature.message,
        "The feature for source '$_sourceId' is not a GeoJSON Feature: A "
        'Feature must have a "geometry" member.',
      );

      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        isNot(contains('new-source')),
      );
      expect(
        _ids(
          await pumpUntil(
            tester,
            controller.querySourceFeatures(_sourceId, null, null),
            'querySourceFeatures after the errors',
          ),
        ),
        {1, 2, 3},
      );
    });

    testWidgets('GeoJSON MapLibre reads goes in everywhere', (tester) async {
      final controller = await pumpMap(tester);

      // Every call is tried, and what failed is listed at the end.
      final failures = <String>[];
      var i = 0;
      for (final geojson in _geoJson.entries) {
        final sourceId = 'source-${i++}';
        final data = geojson.value;
        final calls = <String, Future<Object?> Function()>{
          'addGeoJsonSource': () => controller.addGeoJsonSource(sourceId, data),
          'setGeoJsonSource': () => controller.setGeoJsonSource(sourceId, data),
          'editGeoJsonSource':
              () => controller.editGeoJsonSource(sourceId, jsonEncode(data)),
          'addSource':
              () => controller.addSource(
                '$sourceId-properties',
                GeojsonSourceProperties(data: data),
              ),
        };
        for (final call in calls.entries) {
          try {
            final answer = await pumpUntil(
              tester,
              call.value(),
              '${call.key} ${geojson.key}',
            );
            if (answer == false) failures.add('${call.key} ${geojson.key}');
          } on PlatformException catch (e) {
            failures.add('${call.key} ${geojson.key}: ${e.code} ${e.message}');
          }
        }
      }
      expect(failures, isEmpty);
    });

    testWidgets('editGeoJsonSource and editGeoJsonUrl answer false without a '
        'GeoJSON source, and set the data setGeoJsonFeature changes', (
      tester,
    ) async {
      final controller = await _pumpMapWithPoints(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      for (final sourceId in ['no-such-source', 'image']) {
        expect(
          await pumpUntil(
            tester,
            controller.editGeoJsonSource(sourceId, jsonEncode(_onePoint)),
            'editGeoJsonSource on $sourceId',
          ),
          isFalse,
        );
        expect(
          await pumpUntil(
            tester,
            controller.editGeoJsonUrl(sourceId, 'https://tiles.invalid/a.json'),
            'editGeoJsonUrl on $sourceId',
          ),
          isFalse,
        );
      }

      // setGeoJsonFeature changes the data editGeoJsonSource set.
      expect(
        await pumpUntil(
          tester,
          controller.editGeoJsonSource(_sourceId, jsonEncode(_onePoint)),
          'editGeoJsonSource',
        ),
        isTrue,
      );
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, null),
        (features) =>
            _ids(features).length == 1 &&
            features.every(
              (feature) => ((feature as Map)['properties'] as Map)['n'] == 5,
            ),
        'querySourceFeatures after setGeoJsonFeature',
      );
    });
  });

  group('sources replaced or removed', () {
    testWidgets('editGeoJsonUrl answers true for a GeoJSON source, and '
        'setGeoJsonFeature then has no data to change', (tester) async {
      final controller = await _pumpMapWithPoints(tester);

      // The host does not exist, so nothing leaves the device.
      expect(
        await pumpUntil(
          tester,
          controller.editGeoJsonUrl(_sourceId, 'https://tiles.invalid/a.json'),
          'editGeoJsonUrl',
        ),
        isTrue,
      );
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature after editGeoJsonUrl',
      );
    });

    testWidgets('removeSource keeps a GeoJSON source a layer still uses, '
        'with the data setGeoJsonFeature changes', (tester) async {
      final controller = await _pumpMapWithPoints(tester);

      await pumpUntil(
        tester,
        controller.removeSource(_sourceId),
        'removeSource of a source in use',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        contains(_sourceId),
      );
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
      await pumpUntilValue(
        tester,
        () => controller.querySourceFeatures(_sourceId, null, [
          '==',
          ['get', 'n'],
          5,
        ]),
        (features) => _ids(features).contains(1),
        'querySourceFeatures after setGeoJsonFeature',
      );

      await pumpUntil(
        tester,
        controller.removeLayer(_layerId),
        'removeLayer',
      );
      await pumpUntil(
        tester,
        controller.removeSource(_sourceId),
        'removeSource',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        isNot(contains(_sourceId)),
      );
    });

    testWidgets('an image source shows bytes until it is removed, and its id '
        'can show bytes again', (tester) async {
      final controller = await pumpMap(tester);
      final first = await _loadPng(tester, 'assets/sydney0.png');
      final second = await _loadPng(tester, 'assets/sydney1.png');
      Future<Map<String, dynamic>?> read() => pumpUntil(
        tester,
        controller.getSourceProperties('image'),
        'getSourceProperties',
      );

      await pumpUntil(
        tester,
        controller.addImageSource('image', first, _quad),
        'addImageSource',
      );
      await pumpUntil(
        tester,
        controller.addImageLayer('image-layer', 'image'),
        'addImageLayer',
      );
      await pumpUntil(
        tester,
        controller.updateImageSource('image', second, null),
        'updateImageSource',
      );
      expect(await read(), {'type': 'image', 'coordinates': _corners});

      await pumpUntil(
        tester,
        controller.removeLayer('image-layer'),
        'removeLayer',
      );
      await pumpUntil(
        tester,
        controller.removeSource('image'),
        'removeSource',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        isNot(contains('image')),
      );

      await pumpUntil(
        tester,
        controller.addImageSource('image', second, _movedQuad),
        'addImageSource again',
      );
      await pumpUntil(
        tester,
        controller.addImageLayer('image-layer', 'image'),
        'addImageLayer again',
      );
      expect(await read(), {'type': 'image', 'coordinates': _movedCorners});
    });
  });

  group('layer property values MapLibre rejects', () {
    testWidgets('fail a layer add with INVALID_EXPRESSION or '
        'INVALID_ARGUMENT, naming the property', (tester) async {
      final controller = await pumpMap(tester);
      await _addPoints(tester, controller);
      final layersBefore = await pumpUntil(
        tester,
        controller.getLayerIds(),
        'getLayerIds',
      );

      final cases =
          <(String, String, String, String), Future<Object?> Function()>{
            (
              'an unknown operator',
              'circle-radius',
              'INVALID_EXPRESSION',
              'Invalid expression',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(circleRadius: _unknownOperator),
                ),
            (
              'a missing argument',
              'circle-radius',
              'INVALID_EXPRESSION',
              'Invalid expression',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(circleRadius: ['get']),
                ),
            (
              'a string for a number',
              'circle-radius',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(circleRadius: 'big'),
                ),
            (
              'a string that is no color',
              'circle-color',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(circleColor: 'not-a-color'),
                ),
            (
              'three numbers for two',
              'circle-translate',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(circleTranslate: [1, 2, 3]),
                ),
            (
              'an unknown enum value',
              'line-cap',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addLineLayer(
                  _sourceId,
                  'bad',
                  const LineLayerProperties(lineCap: 'pointy'),
                ),
            (
              'a string for a number of a background',
              'background-opacity',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addBackgroundLayer(
                  'bad',
                  const BackgroundLayerProperties(backgroundOpacity: 'half'),
                ),
            // The property whose name comes first is the one named.
            (
              'two invalid values',
              'circle-color',
              'INVALID_ARGUMENT',
              'Invalid value',
            ): () => controller.addCircleLayer(
                  _sourceId,
                  'bad',
                  const CircleLayerProperties(
                    circleRadius: 'big',
                    circleColor: 'not-a-color',
                  ),
                ),
          };
      for (final MapEntry(key: (label, property, code, kind), :value)
          in cases.entries) {
        final error = await expectPlatformError(
          tester,
          value(),
          label,
          code: code,
        );
        expect(
          error.message,
          startsWith("$kind for property '$property' of layer 'bad': "),
          reason: label,
        );
      }

      // An invalid filter is named before an invalid property.
      final filter = await expectPlatformError(
        tester,
        controller.addCircleLayer(
          _sourceId,
          'bad',
          const CircleLayerProperties(circleRadius: 'big'),
          filter: _unknownOperator,
        ),
        'an invalid filter and an invalid property',
        code: 'INVALID_EXPRESSION',
      );
      expect(filter.message, startsWith('Invalid filter: '));

      expect(
        await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
        layersBefore,
      );
    });

    testWidgets('take every valid kind of value', (tester) async {
      final controller = await pumpMap(tester);
      await _addPoints(tester, controller);

      var i = 0;
      for (final color in [
        '#ff0000',
        '#F00',
        'red',
        'DarkBlue',
        'rgba(255, 0, 0, 0.5)',
        'hsl(0, 100%, 50%)',
      ]) {
        await pumpUntil(
          tester,
          controller.addCircleLayer(
            _sourceId,
            'circles-${i++}',
            CircleLayerProperties(
              circleColor: color,
              circleRadius: 4,
              circleTranslate: const [1, 2],
              circlePitchScale: 'map',
            ),
          ),
          'addCircleLayer with $color',
        );
      }
      await pumpUntil(
        tester,
        controller.addLineLayer(
          _sourceId,
          'lines',
          const LineLayerProperties(
            lineCap: 'round',
            lineDasharray: [2, 1],
            lineColor: [
              'case',
              [
                '==',
                ['get', 'n'],
                1,
              ],
              'red',
              'blue',
            ],
          ),
        ),
        'addLineLayer',
      );
      await pumpUntil(
        tester,
        controller.addSymbolLayer(
          _sourceId,
          'symbols',
          const SymbolLayerProperties(
            iconAllowOverlap: true,
            iconOffset: [0, 1],
            textFont: ['Noto Sans Regular'],
            textAnchor: 'top',
          ),
        ),
        'addSymbolLayer',
      );
      await pumpUntil(
        tester,
        controller.setLayerProperties(
          'circles-0',
          const CircleLayerProperties(circleColor: 'blue', circleRadius: 6),
        ),
        'setLayerProperties',
      );
    });

    testWidgets('fail setLayerProperties without applying any of them', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      await _addPoints(tester, controller);
      await pumpUntil(
        tester,
        controller.addCircleLayer(
          _sourceId,
          _layerId,
          const CircleLayerProperties(circleRadius: 15),
        ),
        'addCircleLayer',
      );
      final center = await _screen(tester, controller, _p1);
      // 9 logical pixels to the right: Android measures the screen in
      // physical pixels.
      final scale =
          testPlatform == TestPlatform.android
              ? tester.view.devicePixelRatio
              : 1.0;
      final aside = Point(center.x + 9 * scale, center.y);
      await _waitForRendered(tester, controller, aside);

      // circle-radius comes before circle-stroke-width, so a call that sets
      // properties one by one would shrink the circle before it fails.
      final error = await expectPlatformError(
        tester,
        controller.setLayerProperties(
          _layerId,
          const CircleLayerProperties(
            circleRadius: 2,
            circleStrokeWidth: 'thick',
          ),
        ),
        'setLayerProperties with an invalid value',
        code: 'INVALID_ARGUMENT',
      );
      expect(
        error.message,
        startsWith(
          "Invalid value for property 'circle-stroke-width' of layer "
          "'$_layerId': ",
        ),
      );
      final expression = await expectPlatformError(
        tester,
        controller.setLayerProperties(
          _layerId,
          const CircleLayerProperties(circleRadius: _unknownOperator),
        ),
        'setLayerProperties with an invalid expression',
        code: 'INVALID_EXPRESSION',
      );
      expect(
        expression.message,
        startsWith(
          "Invalid expression for property 'circle-radius' of layer "
          "'$_layerId': ",
        ),
      );

      // The radius is still 15: the circle still reaches 9 pixels out.
      await pumpFor(tester, const Duration(milliseconds: 500));
      expect(
        _ids(
          await pumpUntil(
            tester,
            controller.queryRenderedFeatures(aside, [_layerId], null),
            'queryRenderedFeatures aside',
          ),
        ),
        {1},
      );

      // A valid call still goes through, and the circle shrinks.
      await pumpUntil(
        tester,
        controller.setLayerProperties(
          _layerId,
          const CircleLayerProperties(circleRadius: 2),
        ),
        'setLayerProperties',
      );
      await pumpUntilValue(
        tester,
        () => controller.queryRenderedFeatures(aside, [_layerId], null),
        (features) => features.isEmpty,
        'queryRenderedFeatures aside after the change',
      );
    });
  });

  group('values the engine cannot take', () {
    // Web checks these sources differently until it makes the same change.
    testWidgets(
      'addSource fails with INVALID_ARGUMENT for tile options MapLibre '
      'rejects and for GeoJSON data that names no url',
      (tester) async {
        final controller = await pumpMap(tester);

        const tiles = ['https://tiles.invalid/{z}/{x}/{y}.pbf'];
        final sources = <String, SourceProperties>{
          'bounds of three numbers': const VectorSourceProperties(
            tiles: tiles,
            bounds: [-10, -10, 10],
          ),
          'bounds with south above north': const VectorSourceProperties(
            tiles: tiles,
            bounds: [-10, 20, 10, 10],
          ),
          'bounds with west east of east': const RasterSourceProperties(
            tiles: [_tileUrl],
            bounds: [20, -10, 10, 10],
          ),
          'minzoom above maxzoom': const RasterSourceProperties(
            tiles: [_tileUrl],
            minzoom: 10,
            maxzoom: 5,
          ),
          'a negative maxzoom': const RasterDemSourceProperties(
            tiles: [_tileUrl],
            minzoom: 0,
            maxzoom: -1,
          ),
          'an empty data url': const GeojsonSourceProperties(data: ''),
          'a data url with spaces': const GeojsonSourceProperties(
            data: 'not a url',
          ),
        };
        for (final source in sources.entries) {
          final type = source.value.toJson()['type'];
          final error = await expectPlatformError(
            tester,
            controller.addSource('broken', source.value),
            'addSource ${source.key}',
            code: 'INVALID_ARGUMENT',
          );
          expect(
            error.message,
            "Source 'broken' cannot be built from its properties as a "
            "'$type' source.",
            reason: source.key,
          );
        }
        expect(
          await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
          isNot(contains('broken')),
        );

        // Latitudes beyond the poles are clamped, as MapLibre does.
        await pumpUntil(
          tester,
          controller.addSource(
            'clamped',
            const VectorSourceProperties(
              tiles: tiles,
              bounds: [-180, -95, 180, 95],
            ),
          ),
          'addSource with bounds beyond the poles',
        );
      },
      skip: kIsWeb,
    );

    testWidgets(
      'removeSource keeps a source a layer still uses, with its corners',
      (tester) async {
        final controller = await pumpMap(tester);
        final image = await _loadPng(tester, 'assets/sydney0.png');
        await pumpUntil(
          tester,
          controller.addImageSource('image', image, _quad),
          'addImageSource',
        );
        await pumpUntil(
          tester,
          controller.addImageLayer('image-layer', 'image'),
          'addImageLayer',
        );

        await pumpUntil(
          tester,
          controller.removeSource('image'),
          'removeSource of a source in use',
        );

        expect(
          await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
          contains('image'),
        );
        expect(
          await pumpUntil(
            tester,
            controller.getSourceProperties('image'),
            'getSourceProperties',
          ),
          {'type': 'image', 'coordinates': _corners},
        );
      },
      // Web forgets what it knew about the source even when maplibre-gl-js
      // keeps it.
      skip: kIsWeb,
    );

    testWidgets('a hex color with a digit that is not hex fails with '
        'INVALID_ARGUMENT, and the alpha of a long one comes last', (
      tester,
    ) async {
      final controller = await pumpMap(tester);
      await _addPoints(tester, controller);

      for (final color in ['#ggg', '#ff00zz', '#12345']) {
        final error = await expectPlatformError(
          tester,
          controller.addCircleLayer(
            _sourceId,
            'bad',
            CircleLayerProperties(circleColor: color),
          ),
          'addCircleLayer with $color',
          code: 'INVALID_ARGUMENT',
        );
        expect(
          error.message,
          startsWith(
            "Invalid value for property 'circle-color' of layer "
            "'bad': ",
          ),
          reason: color,
        );
      }

      // #rrggbbaa and #rgba, as in CSS: half transparent red.
      for (final color in ['#ff000080', '#f008']) {
        await pumpUntil(
          tester,
          controller.setLayerProperties(
            backgroundLayerId,
            BackgroundLayerProperties(backgroundColor: color),
          ),
          'setLayerProperties with $color',
        );
        final layer = await pumpUntil(
          tester,
          controller.getLayerProperties(backgroundLayerId),
          'getLayerProperties',
        );
        final read = (layer!['paint'] as Map)['background-color'];
        if (kIsWeb) {
          expect(read, color);
          continue;
        }
        final rgba = RegExp(
          r'^rgba\(([\d.]+),\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)\)$',
        ).firstMatch('$read');
        expect(rgba, isNotNull, reason: '$color read as $read');
        final channels = [
          for (var i = 1; i <= 4; i++) double.parse(rgba!.group(i)!),
        ];
        expect(channels[0], closeTo(255, 1), reason: '$color read as $read');
        expect(channels[1], closeTo(0, 1), reason: '$color read as $read');
        expect(channels[2], closeTo(0, 1), reason: '$color read as $read');
        expect(channels[3], closeTo(0.5, 0.05), reason: '$color read as $read');
      }
    });

    // maplibre-gl-js answers these with its own errors.
    testWidgets(
      'NaN coordinates and camera values fail with INVALID_ARGUMENT',
      (tester) async {
        final controller = await pumpMap(tester);
        final image = await _loadPng(tester, 'assets/sydney0.png');
        const nan = double.nan;
        const coordinates = 'Latitude and longitude must be finite numbers.';

        final calls = <String, (String, Future<Object?> Function())>{
          'moveCamera newLatLng': (
            coordinates,
            () => controller.moveCamera(
              CameraUpdate.newLatLng(const LatLng(nan, 0)),
            ),
          ),
          'animateCamera newCameraPosition': (
            coordinates,
            () => controller.animateCamera(
              CameraUpdate.newCameraPosition(
                const CameraPosition(target: LatLng(0, nan), zoom: 3),
              ),
            ),
          ),
          'moveCamera zoomTo': (
            'Zoom, bearing, tilt, offsets and padding must be finite numbers.',
            () => controller.moveCamera(CameraUpdate.zoomTo(nan)),
          ),
          'easeCamera tiltTo': (
            'Zoom, bearing, tilt, offsets and padding must be finite numbers.',
            () => controller.easeCamera(CameraUpdate.tiltTo(nan)),
          ),
          'addImageSource': (
            coordinates,
            () => controller.addImageSource(
              'nan-image',
              image,
              const LatLngQuad(
                topLeft: LatLng(2, -2),
                topRight: LatLng(2, nan),
                bottomRight: LatLng(-2, 2),
                bottomLeft: LatLng(-2, -2),
              ),
            ),
          ),
          'toScreenLocation': (
            coordinates,
            () => controller.toScreenLocation(const LatLng(nan, 0)),
          ),
          'toScreenLocationBatch': (
            coordinates,
            () => controller.toScreenLocationBatch(const [
              LatLng(1, 1),
              LatLng(nan, 0),
            ]),
          ),
          'setCameraBounds': (
            coordinates,
            () => controller.setCameraBounds(
              west: nan,
              north: 10,
              south: -10,
              east: 10,
              padding: 0,
            ),
          ),
          'toLatLng': (
            'Screen coordinates must be finite numbers.',
            () => controller.toLatLng(const Point(nan, 10)),
          ),
        };
        for (final MapEntry(key: label, value: (message, call))
            in calls.entries) {
          final error = await expectPlatformError(
            tester,
            call(),
            label,
            code: 'INVALID_ARGUMENT',
          );
          expect(error.message, message, reason: label);
        }

        // updateImageSource checks the corners before it changes anything.
        await pumpUntil(
          tester,
          controller.addImageSource('image', image, _quad),
          'addImageSource',
        );
        final error = await expectPlatformError(
          tester,
          controller.updateImageSource(
            'image',
            null,
            const LatLngQuad(
              topLeft: LatLng(nan, -2),
              topRight: LatLng(2, 2),
              bottomRight: LatLng(-2, 2),
              bottomLeft: LatLng(-2, -2),
            ),
          ),
          'updateImageSource',
          code: 'INVALID_ARGUMENT',
        );
        expect(error.message, coordinates);
        expect(
          await pumpUntil(
            tester,
            controller.getSourceProperties('image'),
            'getSourceProperties',
          ),
          {'type': 'image', 'coordinates': _corners},
        );
      },
      skip: kIsWeb,
    );

    // maplibre-gl-js takes any padding and clamps the latitudes.
    testWidgets(
      'setCameraBounds fails with INVALID_ARGUMENT for a padding beyond 32 '
      'bits and a latitude beyond the poles',
      (tester) async {
        final controller = await pumpMap(tester);

        final padding = await expectPlatformError(
          tester,
          controller.setCameraBounds(
            west: -10,
            north: 10,
            south: -10,
            east: 10,
            padding: 1 << 40,
          ),
          'setCameraBounds with a padding beyond 32 bits',
          code: 'INVALID_ARGUMENT',
        );
        expect(
          padding.message,
          'Padding 1099511627776 does not fit in 32 bits.',
        );

        final latitude = await expectPlatformError(
          tester,
          controller.setCameraBounds(
            west: -10,
            north: 95,
            south: -10,
            east: 10,
            padding: 0,
          ),
          'setCameraBounds with a latitude beyond the poles',
          code: 'INVALID_ARGUMENT',
        );
        expect(latitude.message, 'Latitude must be within -90 and 90.');
      },
      skip: kIsWeb,
    );

    testWidgets('a second takeSnapshot answers the first one too', (
      tester,
    ) async {
      final controller = await pumpMap(tester);

      // The first snapshot is cancelled when the second one starts before it
      // finishes, and fails with SNAPSHOT_ERROR; one that finished first
      // answers its image. Either way it answers.
      final first = controller
          .takeSnapshot(width: 64, height: 64)
          .then<Object>(
            (bytes) => bytes,
            onError: (Object error) => error,
          );
      final second = controller.takeSnapshot(width: 64, height: 64);

      final firstAnswer = await pumpUntil(tester, first, 'first takeSnapshot');
      if (firstAnswer is PlatformException) {
        expect(firstAnswer.code, 'SNAPSHOT_ERROR');
        expect(
          firstAnswer.message,
          'A newer takeSnapshot call cancelled this one.',
        );
      } else {
        expect(firstAnswer, isA<Uint8List>());
      }
      expect(
        await pumpUntil(tester, second, 'second takeSnapshot'),
        isNotEmpty,
      );
    });
  });

  // Web drops these layers without an error until it makes the same change.
  group('layer adds MapLibre would draw nothing for', () {
    testWidgets(
      'a layer on a vector source without a sourceLayer fails with '
      'SOURCE_LAYER_REQUIRED',
      (tester) async {
        final controller = await pumpMap(tester);
        await pumpUntil(
          tester,
          controller.addSource(
            'vector',
            const VectorSourceProperties(
              tiles: ['https://tiles.invalid/{z}/{x}/{y}.pbf'],
            ),
          ),
          'addSource vector',
        );
        final layersBefore = await pumpUntil(
          tester,
          controller.getLayerIds(),
          'getLayerIds',
        );

        final calls = <String, Future<void> Function()>{
          'line-no-source-layer':
              () => controller.addLineLayer(
                'vector',
                'line-no-source-layer',
                const LineLayerProperties(),
              ),
          'fill-empty-source-layer':
              () => controller.addFillLayer(
                'vector',
                'fill-empty-source-layer',
                const FillLayerProperties(),
                sourceLayer: '',
              ),
          'circle-no-source-layer':
              () => controller.addLayer(
                'vector',
                'circle-no-source-layer',
                const CircleLayerProperties(),
              ),
        };
        for (final call in calls.entries) {
          final error = await expectPlatformError(
            tester,
            call.value(),
            call.key,
            code: 'SOURCE_LAYER_REQUIRED',
          );
          expect(
            error.message,
            "Source 'vector' is a vector source, so layer '${call.key}' "
            "requires a 'sourceLayer'.",
          );
        }
        expect(
          await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
          layersBefore,
        );

        await pumpUntil(
          tester,
          controller.addLineLayer(
            'vector',
            'roads',
            const LineLayerProperties(),
            sourceLayer: 'roads',
          ),
          'addLineLayer with a sourceLayer',
        );
      },
      skip: kIsWeb,
    );

    testWidgets(
      'a zoom outside 0 to 24 fails with INVALID_ARGUMENT',
      (tester) async {
        final controller = await pumpMap(tester);
        await _addPoints(tester, controller);
        final layersBefore = await pumpUntil(
          tester,
          controller.getLayerIds(),
          'getLayerIds',
        );

        final calls = <String, Future<void> Function()>{
          'circle-minzoom':
              () => controller.addCircleLayer(
                _sourceId,
                'circle-minzoom',
                const CircleLayerProperties(),
                minzoom: -1,
              ),
          'line-maxzoom':
              () => controller.addLineLayer(
                _sourceId,
                'line-maxzoom',
                const LineLayerProperties(),
                maxzoom: 24.5,
              ),
          'background-maxzoom':
              () => controller.addBackgroundLayer(
                'background-maxzoom',
                const BackgroundLayerProperties(),
                maxzoom: 30,
              ),
        };
        for (final call in calls.entries) {
          final error = await expectPlatformError(
            tester,
            call.value(),
            call.key,
            code: 'INVALID_ARGUMENT',
          );
          expect(
            error.message,
            "The minzoom and maxzoom of layer '${call.key}' must be within 0 "
            'and 24.',
          );
        }
        expect(
          await pumpUntil(tester, controller.getLayerIds(), 'getLayerIds'),
          layersBefore,
        );

        await pumpUntil(
          tester,
          controller.addCircleLayer(
            _sourceId,
            'circle-full-range',
            const CircleLayerProperties(),
            minzoom: 0,
            maxzoom: 24,
          ),
          'addCircleLayer from 0 to 24',
        );
      },
      skip: kIsWeb,
    );
  });

  group('without a style', () {
    testWidgets('calls that need a style answer STYLE_NOT_READY', (
      tester,
    ) async {
      if (kIsWeb) return;
      final controller = await pumpMap(tester);
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      // The style is dropped as soon as a new one is set, and this one never
      // loads.
      await pumpUntil(
        tester,
        controller.setStyle(_brokenStyle),
        'setStyle with a broken style',
      );

      // One at a time: a call that fails before it is awaited would be an
      // unhandled error.
      final calls = <String, Future<Object?> Function()>{
        'addGeoJsonSource':
            () => controller.addGeoJsonSource('new-points', _onePoint),
        'setGeoJsonSource':
            () => controller.setGeoJsonSource(_sourceId, _onePoint),
        'setGeoJsonFeature':
            () => controller.setGeoJsonFeature(
              _sourceId,
              _point(1, _p1, {'n': 5}),
            ),
        'addSource':
            () => controller.addSource(
              'new-source',
              const GeojsonSourceProperties(data: _onePoint),
            ),
        'querySourceFeatures':
            () => controller.querySourceFeatures(_sourceId, null, null),
        'getClusterExpansionZoom':
            () => controller.getClusterExpansionZoom(_sourceId, 1),
        'addCircleLayer':
            () => controller.addCircleLayer(
              _sourceId,
              'new-circles',
              const CircleLayerProperties(),
            ),
        'addBackgroundLayer':
            () => controller.addBackgroundLayer(
              'new-background',
              const BackgroundLayerProperties(),
            ),
        'setLayerFilter':
            () => controller.setLayerFilter(backgroundLayerId, null),
        'getLayerFilter': () => controller.getLayerFilter(backgroundLayerId),
        'setLight':
            () => controller.setLight(const LightProperties(intensity: 0.5)),
        'addImageSource':
            () => controller.addImageSource('new-image', image, _quad),
        'updateImageSource':
            () => controller.updateImageSource('image', image, null),
        'getLayerProperties':
            () => controller.getLayerProperties(backgroundLayerId),
        'getSourceProperties': () => controller.getSourceProperties('image'),
        'removeSource': () => controller.removeSource('image'),
        'removeLayer': () => controller.removeLayer(backgroundLayerId),
        'setLayerProperties':
            () => controller.setLayerProperties(
              backgroundLayerId,
              const BackgroundLayerProperties(backgroundOpacity: 0.5),
            ),
        'setLayerVisibility':
            () => controller.setLayerVisibility(backgroundLayerId, false),
        'setLayersVisibility':
            () => controller.setLayersVisibility([backgroundLayerId], false),
        'addImageLayer': () => controller.addImageLayer('image-layer', 'image'),
        'addImageLayerBelow':
            () => controller.addImageLayerBelow(
              'image-below',
              'image',
              backgroundLayerId,
            ),
      };
      for (final call in calls.entries) {
        final error = await expectPlatformError(
          tester,
          call.value(),
          call.key,
          code: 'STYLE_NOT_READY',
        );
        expect(error.message, _styleNotReadyMessage, reason: call.key);
      }

      // An empty list changes nothing, so it needs no style.
      expect(
        await pumpUntil(
          tester,
          controller.setLayersVisibility([], false),
          'setLayersVisibility with no ids',
        ),
        isEmpty,
      );
    });
  });
}

/// Pumps a map from the offline style and returns its controller with the
/// platform behind it, for the calls of the platform that the controller does
/// not make.
Future<(MapLibreMapController, MapLibrePlatform)> _pumpMapWithPlatform(
  WidgetTester tester,
) async {
  final create = MapLibrePlatform.createInstance;
  MapLibrePlatform? platform;
  MapLibrePlatform.createInstance = () => platform = create();
  try {
    final controller = await pumpMap(tester);
    return (controller, platform!);
  } finally {
    MapLibrePlatform.createInstance = create;
  }
}

Future<bool> _setLayerFilter(
  WidgetTester tester,
  MapLibrePlatform platform,
  String layerId,
  String filter,
) {
  return pumpUntil(
    tester,
    // The controller sets filters through setFilter; this older call stays
    // on the platform, which still answers it.
    // ignore: deprecated_member_use
    platform.setLayerFilter(layerId, filter),
    'setLayerFilter $layerId $filter',
  );
}

/// A map with [_p1], [_p2] and [_p3] drawn as big circles in [_layerId].
Future<MapLibreMapController> _pumpMapWithPoints(WidgetTester tester) async {
  final controller = await pumpMap(tester);
  await _addPoints(tester, controller);
  await pumpUntil(
    tester,
    controller.addCircleLayer(
      _sourceId,
      _layerId,
      const CircleLayerProperties(circleRadius: 15),
    ),
    'addCircleLayer',
  );
  return controller;
}

/// Adds [_sourceId] with [_p1], [_p2] and [_p3].
Future<void> _addPoints(
  WidgetTester tester,
  MapLibreMapController controller,
) {
  return pumpUntil(
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
}

/// Expects [future] to fail with INVALID_EXPRESSION and the message every
/// rejected filter gets.
Future<void> _expectInvalidFilter(
  WidgetTester tester,
  Future<Object?> future,
  String label,
) async {
  final error = await expectPlatformError(
    tester,
    future,
    label,
    code: 'INVALID_EXPRESSION',
  );
  expect(error.message, startsWith('Invalid filter: '), reason: label);
}

/// Polls a point query until the layer is drawn there.
Future<List> _waitForRendered(
  WidgetTester tester,
  MapLibreMapController controller,
  Point<double> point,
) {
  return pumpUntilValue(
    tester,
    () => controller.queryRenderedFeatures(point, [_layerId], null),
    (features) => features.isNotEmpty,
    'queryRenderedFeatures on $_layerId',
  );
}

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

Future<Uint8List> _loadPng(WidgetTester tester, String asset) async {
  final data = await pumpUntil(tester, rootBundle.load(asset), 'load $asset');
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

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

/// The distinct feature ids in [features], whether they came back as numbers
/// or numeric strings.
Set<int> _ids(List features) => {
  for (final feature in features)
    if (num.tryParse('${(feature as Map)['id']}') case final id?) id.toInt(),
};
