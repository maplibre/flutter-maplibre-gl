// The checks the web layer and source calls make before maplibre-gl-js sees
// them, so they answer what Android and iOS answer.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/src/style_checks.dart';

void main() {
  group('canDraw', () {
    test('follows the tile each source makes, as MapLibre Native does', () {
      for (final layer in [
        'fill',
        'line',
        'symbol',
        'circle',
        'heatmap',
        'fill-extrusion',
      ]) {
        expect(canDraw(layer, 'geojson'), isTrue, reason: layer);
        expect(canDraw(layer, 'vector'), isTrue, reason: layer);
        expect(canDraw(layer, 'raster'), isFalse, reason: layer);
        expect(canDraw(layer, 'image'), isFalse, reason: layer);
        expect(canDraw(layer, 'raster-dem'), isFalse, reason: layer);
      }
      for (final source in ['raster', 'image', 'video', 'canvas']) {
        expect(canDraw('raster', source), isTrue, reason: source);
      }
      expect(canDraw('raster', 'geojson'), isFalse);
      expect(canDraw('raster', 'raster-dem'), isFalse);
      for (final layer in ['hillshade', 'color-relief']) {
        expect(canDraw(layer, 'raster-dem'), isTrue, reason: layer);
        expect(canDraw(layer, 'raster'), isFalse, reason: layer);
        expect(canDraw(layer, 'geojson'), isFalse, reason: layer);
      }
    });

    test('lets a type it does not know through', () {
      expect(canDraw('custom', 'geojson'), isTrue);
      expect(canDraw('fill', 'custom'), isFalse);
    });
  });

  test('incompatibleSource names both types', () {
    expect(
      incompatibleSource('l', 'raster', 's', 'geojson'),
      isA<PlatformException>()
          .having((e) => e.code, 'code', 'UNSUPPORTED_SOURCE_TYPE')
          .having(
            (e) => e.message,
            'message',
            "Layer 'l' of type 'raster' cannot use source 's' of type "
                "'geojson'.",
          ),
    );
  });

  group('invalidProperty', () {
    test('is INVALID_EXPRESSION for an expression', () {
      final error = invalidProperty('l', 'circle-radius', [
        'no-such-operator',
        1,
      ], 'Unknown expression.');
      expect(error.code, 'INVALID_EXPRESSION');
      expect(
        error.message,
        "Invalid expression for property 'circle-radius' of layer 'l': "
        'Unknown expression.',
      );
      expect(error.details, 'Unknown expression.');
    });

    test('is INVALID_ARGUMENT for any other value', () {
      for (final value in <Object?>[
        'big',
        5,
        true,
        <Object?>[],
        [1, 2],
      ]) {
        final error = invalidProperty('l', 'circle-radius', value, 'Why.');
        expect(error.code, 'INVALID_ARGUMENT', reason: '$value');
        expect(
          error.message,
          "Invalid value for property 'circle-radius' of layer 'l': Why.",
        );
      }
    });
  });

  test('isPropertyOf reads the layer type from the property name', () {
    expect(isPropertyOf('circle', 'circle-radius'), isTrue);
    expect(isPropertyOf('circle', 'visibility'), isTrue);
    expect(isPropertyOf('circle', 'fill-color'), isFalse);
    expect(isPropertyOf('fill', 'fill-color'), isTrue);
    expect(isPropertyOf('fill', 'fill-extrusion-height'), isFalse);
    expect(isPropertyOf('fill-extrusion', 'fill-extrusion-height'), isTrue);
    for (final property in ['icon-size', 'text-field', 'symbol-placement']) {
      expect(isPropertyOf('symbol', property), isTrue, reason: property);
    }
    expect(isPropertyOf('color-relief', 'color-relief-color'), isTrue);
  });

  group('propertyError', () {
    test('reads the property and the reason of a validation error', () {
      expect(
        propertyError(
          'layers.my.layer.paint.circle-radius: number expected, string found',
        ),
        (property: 'circle-radius', reason: 'number expected, string found'),
      );
      expect(
        propertyError(
          'layers.l.layout.line-cap: expected one of [butt, round, square], '
          '"pointy" found',
        ),
        (
          property: 'line-cap',
          reason: 'expected one of [butt, round, square], "pointy" found',
        ),
      );
      expect(
        propertyError(
          'layers.l.paint.circle-radius[0]: Unknown expression "x". If you '
          'wanted a literal array, use ["literal", [...]].',
        )?.property,
        'circle-radius',
      );
    });

    test('is null for an error about something else', () {
      expect(propertyError('layers.l.filter[0]: Unknown expression'), isNull);
      expect(propertyError('Source "s" not found'), isNull);
    });

    test('isUnknownProperty tells a property it does not know', () {
      expect(isUnknownProperty('unknown property "fill-color"'), isTrue);
      expect(isUnknownProperty('number expected, string found'), isFalse);
    });
  });

  group('canBuildSource', () {
    const corners = [
      [-2, 2],
      [2, 2],
      [2, -2],
      [-2, -2],
    ];

    test('needs a url or tiles for a tiled source', () {
      for (final type in ['vector', 'raster', 'raster-dem']) {
        expect(canBuildSource(type, {'url': 'u'}), isTrue, reason: type);
        expect(
          canBuildSource(type, {
            'tiles': ['t'],
          }),
          isTrue,
          reason: type,
        );
        expect(canBuildSource(type, {}), isFalse, reason: type);
      }
    });

    test('needs the data of a GeoJSON source', () {
      expect(canBuildSource('geojson', {'data': 'u'}), isTrue);
      expect(canBuildSource('geojson', {}), isFalse);
    });

    test('needs a url and four corners on the map for an image', () {
      expect(
        canBuildSource('image', {'url': 'u', 'coordinates': corners}),
        isTrue,
      );
      expect(canBuildSource('image', {'coordinates': corners}), isFalse);
      expect(
        canBuildSource('image', {'url': '', 'coordinates': corners}),
        isFalse,
      );
      expect(canBuildSource('image', {'url': 'u'}), isFalse);
      for (final wrong in [
        corners.take(3).toList(),
        [
          ...corners.take(3),
          [1],
        ],
        [
          ...corners.take(3),
          [1, 95],
        ],
        [
          ...corners.take(3),
          ['1', '2'],
        ],
        [
          ...corners.take(3),
          [double.infinity, 2],
        ],
      ]) {
        expect(
          canBuildSource('image', {'url': 'u', 'coordinates': wrong}),
          isFalse,
          reason: '$wrong',
        );
      }
    });

    test('needs urls and four corners for a video', () {
      expect(
        canBuildSource('video', {
          'urls': ['u'],
          'coordinates': corners,
        }),
        isTrue,
      );
      expect(canBuildSource('video', {'coordinates': corners}), isFalse);
      expect(
        canBuildSource('video', {'urls': <String>[], 'coordinates': corners}),
        isFalse,
      );
    });
  });

  group('layer adds', () {
    test('a layer on a vector source needs a source layer', () {
      expect(
        sourceLayerRequired('roads', 'tiles'),
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'SOURCE_LAYER_REQUIRED')
            .having(
              (e) => e.message,
              'message',
              "Source 'tiles' is a vector source, so layer 'roads' requires "
                  "a 'sourceLayer'.",
            ),
      );
    });

    test('a zoom is within 0 and 24', () {
      expect(isZoomInRange(null, null), isTrue);
      expect(isZoomInRange(0, 24), isTrue);
      expect(isZoomInRange(24, 0), isTrue, reason: 'each on its own');
      for (final (min, max) in <(double?, double?)>[
        (-1, null),
        (null, 25),
        (24.5, null),
        (double.nan, null),
        (null, double.infinity),
      ]) {
        expect(isZoomInRange(min, max), isFalse, reason: '[$min, $max]');
      }
      expect(
        zoomOutOfRange('roads'),
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'INVALID_ARGUMENT')
            .having(
              (e) => e.message,
              'message',
              "The minzoom and maxzoom of layer 'roads' must be within 0 "
                  'and 24.',
            ),
      );
    });

    test('a layer maplibre-gl-js did not add says why', () {
      expect(
        layerNotAdded('roads', 'Something is wrong.'),
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'INVALID_LAYER')
            .having(
              (e) => e.message,
              'message',
              "Layer 'roads' was not added: Something is wrong.",
            )
            .having((e) => e.details, 'details', 'Something is wrong.'),
      );
      expect(
        layerNotAdded('roads', null).message,
        "Layer 'roads' was not added.",
      );
    });
  });
}
