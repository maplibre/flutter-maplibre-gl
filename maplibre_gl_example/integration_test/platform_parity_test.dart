// Integration tests for the calls Android, iOS and web used to answer
// differently.
//
// Covered: the feature queries and the platform's setLayerFilter with a
// filter MapLibre rejects, the rect query with a filter that is not an
// expression array, query filters with large numbers, image sources with an
// id in use or bytes that are not an image, layer adds with a missing source,
// a missing belowLayerId or an invalid filter, the GeoJSON source updates with
// a missing source or something that is not a Feature, sources Android and
// iOS cannot build, and the calls made while no style is loaded.
//
// Each case now answers the same everywhere: an invalid query filter is
// INVALID_EXPRESSION, setLayerFilter answers false for anything it cannot
// set, a missing source is SOURCE_NOT_FOUND, a layer below a missing one goes
// on top, and a call that needs a style answers STYLE_NOT_READY, with the
// same message, while none is loaded. Before, iOS crashed on an invalid
// filter and answered with codes of its own, Android ignored some of these
// calls, and web threw raw maplibre-gl-js errors or did nothing.
//
// The calls without a style run on Android and iOS only: web cannot load a
// style that fails to parse, so there is no way to drop the style there.
// Web also adds the video sources and the empty image sources Android and iOS
// cannot build.
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
import 'package:flutter/services.dart' show rootBundle;
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

      // iOS raised an Objective-C exception for these, which ended the app.
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
      // iOS filtered with it, so `false` found nothing and an object crashed.
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

      // Text that is not JSON cannot be a filter. iOS ignored it and Android
      // failed with a bare "error"; both now answer the same error.
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
      // Android took only line, fill and symbol layers.
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

      // A filter MapLibre rejects crashed iOS, and Android reported it as set.
      // Now it is false and the layer keeps its filter.
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

      // Android moved the corners before it read the bytes, so a failed call
      // still moved the image. No call reads the corners back, so this pins
      // the error and that the source is still there and still updates.
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

      // Android added these layers, which then drew nothing, and iOS said
      // sourceNotFound or noSuchSource. Web added nothing and said nothing.
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

      // iOS failed the image layer with noSuchLayer and the background layer
      // with LAYER_NOT_FOUND_ERROR. Web added none of them.
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

      // Android added the layer without the filter, or failed with a bare
      // "error" for one that is not an expression. Web added nothing and
      // said nothing.
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
      final image = await _loadPng(tester, 'assets/sydney0.png');
      await pumpUntil(
        tester,
        controller.addImageSource('image', image, _quad),
        'addImageSource',
      );

      // Android and web ignored these, iOS said sourceNotFound. A source
      // that is not GeoJSON counts as missing, as for updateImageSource.
      for (final sourceId in ['no-such-source', 'image']) {
        await expectPlatformError(
          tester,
          controller.setGeoJsonSource(sourceId, _onePoint),
          'setGeoJsonSource on $sourceId',
          code: 'SOURCE_NOT_FOUND',
        );
        await expectPlatformError(
          tester,
          controller.setGeoJsonFeature(sourceId, _point(1, _p1, {'n': 5})),
          'setGeoJsonFeature on $sourceId',
          code: 'SOURCE_NOT_FOUND',
        );
      }
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

      // iOS failed a geometry with genericError and ignored a collection,
      // Android ignored both, and web failed with a TypeError.
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

      // iOS failed this with genericError: its data was not a collection.
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

      // iOS failed with genericError, Android and web did nothing.
      await pumpUntil(
        tester,
        controller.setGeoJsonFeature(_sourceId, _point(1, _p1, {'n': 5})),
        'setGeoJsonFeature',
      );
    });
  });

  group('sources Android and iOS cannot build', () {
    testWidgets('a video source is UNSUPPORTED_SOURCE_TYPE and a tiled source '
        'without tiles INVALID_ARGUMENT', (tester) async {
      // maplibre-gl-js adds both.
      if (kIsWeb) return;
      final controller = await pumpMap(tester);

      // iOS said invalidSourceType for both, Android added nothing and
      // answered a success.
      await expectPlatformError(
        tester,
        controller.addSource(
          'video',
          const VideoSourceProperties(
            urls: ['https://example.com/video.mp4'],
            coordinates: [
              [-2, 2],
              [2, 2],
              [2, -2],
              [-2, -2],
            ],
          ),
        ),
        'addSource video',
        code: 'UNSUPPORTED_SOURCE_TYPE',
      );
      await expectPlatformError(
        tester,
        controller.addSource('vector', const VectorSourceProperties()),
        'addSource vector without url or tiles',
        code: 'INVALID_ARGUMENT',
      );
      expect(
        await pumpUntil(tester, controller.getSourceIds(), 'getSourceIds'),
        isNot(anyOf(contains('video'), contains('vector'))),
      );
    });
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

      // What iOS answered before, where Android said STYLE_NOT_READY:
      // nothing for the properties, a success for addImageSource and
      // removeSource, SOURCE_NOT_FOUND for updateImageSource,
      // LAYER_NOT_FOUND_ERROR for the layer calls, noSuchSource for the
      // image layers, every id as unknown for setLayersVisibility, and
      // styleNotFound for the rest. Android answered a success for the
      // GeoJSON source calls and a bare "error" for addSource.
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
