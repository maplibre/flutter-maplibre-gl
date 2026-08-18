import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('CircleLayerProperties', () {
    test('toJson with skipNulls omits null fields', () {
      const props = CircleLayerProperties(circleRadius: 10);
      final json = props.toJson();
      expect(json['circle-radius'], 10);
      expect(json.containsKey('circle-color'), isFalse);
    });

    test('toJson without skipNulls includes null fields', () {
      const props = CircleLayerProperties(circleRadius: 10);
      final json = props.toJson(skipNulls: false);
      expect(json['circle-radius'], 10);
      expect(json.containsKey('circle-color'), isTrue);
      expect(json['circle-color'], isNull);
    });

    test('uses hyphenated key names', () {
      const props = CircleLayerProperties(
        circleStrokeWidth: 2,
        circleStrokeColor: '#FF0000',
      );
      final json = props.toJson();
      expect(json.containsKey('circle-stroke-width'), isTrue);
      expect(json.containsKey('circle-stroke-color'), isTrue);
    });

    test('fromJson roundtrip', () {
      const original = CircleLayerProperties(
        circleRadius: 10,
        circleColor: '#FF0000',
        circleOpacity: 0.8,
        visibility: 'visible',
      );
      final restored = CircleLayerProperties.fromJson(original.toJson());
      expect(restored.circleRadius, 10);
      expect(restored.circleColor, '#FF0000');
      expect(restored.circleOpacity, 0.8);
      expect(restored.visibility, 'visible');
    });
  });

  group('LineLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = LineLayerProperties(
        lineColor: '#0000FF',
        lineWidth: 3,
      );
      final json = props.toJson();
      expect(json['line-color'], '#0000FF');
      expect(json['line-width'], 3);
      expect(json.containsKey('line-opacity'), isFalse);
    });

    test('toJson without skipNulls', () {
      const props = LineLayerProperties(lineColor: '#0000FF');
      final json = props.toJson(skipNulls: false);
      expect(json.containsKey('line-opacity'), isTrue);
    });

    test('fromJson roundtrip', () {
      const original = LineLayerProperties(
        lineColor: '#0000FF',
        lineWidth: 3,
        lineDasharray: [2, 4],
      );
      final restored = LineLayerProperties.fromJson(original.toJson());
      expect(restored.lineColor, '#0000FF');
      expect(restored.lineWidth, 3);
      expect(restored.lineDasharray, [2, 4]);
    });
  });

  group('FillLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = FillLayerProperties(
        fillColor: '#00FF00',
        fillOpacity: 0.5,
      );
      final json = props.toJson();
      expect(json['fill-color'], '#00FF00');
      expect(json['fill-opacity'], 0.5);
      expect(json.containsKey('fill-outline-color'), isFalse);
    });

    test('fromJson roundtrip', () {
      const original = FillLayerProperties(
        fillColor: '#00FF00',
        fillOpacity: 0.5,
        fillOutlineColor: '#000000',
        visibility: 'none',
      );
      final restored = FillLayerProperties.fromJson(original.toJson());
      expect(restored.fillColor, '#00FF00');
      expect(restored.fillOpacity, 0.5);
      expect(restored.fillOutlineColor, '#000000');
      expect(restored.visibility, 'none');
    });

    test('copyWith keeps fill-layer-opacity distinct from fill-opacity', () {
      const original = FillLayerProperties(
        fillColor: '#00FF00',
        fillOpacity: 0.5,
        fillLayerOpacity: 1,
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const FillLayerProperties(fillLayerOpacity: 0.25),
      );
      expect(updated.fillColor, '#00FF00');
      expect(updated.fillOpacity, 0.5);
      expect(updated.visibility, 'visible');

      final json = updated.toJson();
      expect(json['fill-layer-opacity'], 0.25);
      expect(json['fill-opacity'], 0.5);
    });
  });

  group('SymbolLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = SymbolLayerProperties(
        iconImage: 'marker',
        iconSize: 1.5,
        textField: 'Hello',
      );
      final json = props.toJson();
      expect(json['icon-image'], 'marker');
      expect(json['icon-size'], 1.5);
      expect(json['text-field'], 'Hello');
      expect(json.containsKey('icon-opacity'), isFalse);
    });

    test('fromJson roundtrip', () {
      const original = SymbolLayerProperties(
        iconImage: 'marker',
        iconSize: 1.5,
        textField: 'Hello',
        textColor: '#FF0000',
      );
      final restored = SymbolLayerProperties.fromJson(original.toJson());
      expect(restored.iconImage, 'marker');
      expect(restored.iconSize, 1.5);
      expect(restored.textField, 'Hello');
      expect(restored.textColor, '#FF0000');
    });

    test('copyWith overrides the overlap and variable anchor offset', () {
      const original = SymbolLayerProperties(
        iconImage: 'marker',
        iconOverlap: 'never',
        textOverlap: 'never',
        textVariableAnchorOffset: [
          'top',
          [0, 4],
        ],
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const SymbolLayerProperties(
          iconOverlap: 'always',
          textOverlap: 'cooperative',
          textVariableAnchorOffset: [
            'bottom',
            [0, -4],
          ],
        ),
      );
      expect(updated.iconImage, 'marker');
      expect(updated.visibility, 'visible');

      final json = updated.toJson();
      expect(json['icon-overlap'], 'always');
      expect(json['text-overlap'], 'cooperative');
      expect(json['text-variable-anchor-offset'], [
        'bottom',
        [0, -4],
      ]);
    });
  });

  group('FillExtrusionLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = FillExtrusionLayerProperties(
        fillExtrusionColor: '#333333',
        fillExtrusionHeight: 100,
      );
      final json = props.toJson();
      expect(json['fill-extrusion-color'], '#333333');
      expect(json['fill-extrusion-height'], 100);
    });

    test('fromJson roundtrip', () {
      const original = FillExtrusionLayerProperties(
        fillExtrusionColor: '#333333',
        fillExtrusionHeight: 100,
        fillExtrusionOpacity: 0.9,
      );
      final restored = FillExtrusionLayerProperties.fromJson(original.toJson());
      expect(restored.fillExtrusionColor, '#333333');
      expect(restored.fillExtrusionHeight, 100);
      expect(restored.fillExtrusionOpacity, 0.9);
    });

    test('copyWith overrides specified fields', () {
      const original = FillExtrusionLayerProperties(
        fillExtrusionColor: '#333333',
        fillExtrusionHeight: 100,
        fillExtrusionVerticalGradient: true,
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const FillExtrusionLayerProperties(
          fillExtrusionHeight: 200,
          fillExtrusionVerticalGradient: false,
        ),
      );
      expect(updated.fillExtrusionColor, '#333333');
      expect(updated.fillExtrusionHeight, 200);
      expect(updated.fillExtrusionVerticalGradient, false);
      expect(updated.visibility, 'visible');
    });
  });

  group('RasterLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = RasterLayerProperties(
        rasterOpacity: 0.8,
        rasterBrightnessMax: 1.0,
      );
      final json = props.toJson();
      expect(json['raster-opacity'], 0.8);
      expect(json['raster-brightness-max'], 1.0);
    });

    test('fromJson roundtrip', () {
      const original = RasterLayerProperties(
        rasterOpacity: 0.8,
        rasterSaturation: -0.5,
      );
      final restored = RasterLayerProperties.fromJson(original.toJson());
      expect(restored.rasterOpacity, 0.8);
      expect(restored.rasterSaturation, -0.5);
    });

    test('copyWith keeps resampling distinct from raster-resampling', () {
      const original = RasterLayerProperties(
        rasterOpacity: 0.8,
        resampling: 'linear',
        rasterResampling: 'linear',
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const RasterLayerProperties(resampling: 'nearest'),
      );
      expect(updated.rasterOpacity, 0.8);
      expect(updated.visibility, 'visible');

      final json = updated.toJson();
      expect(json['resampling'], 'nearest');
      expect(json['raster-resampling'], 'linear');
    });
  });

  group('HillshadeLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = HillshadeLayerProperties(
        hillshadeExaggeration: 0.5,
        hillshadeIlluminationDirection: 335,
      );
      final json = props.toJson();
      expect(json['hillshade-exaggeration'], 0.5);
      expect(json['hillshade-illumination-direction'], 335);
    });

    test('fromJson roundtrip', () {
      const original = HillshadeLayerProperties(
        hillshadeExaggeration: 0.5,
        hillshadeShadowColor: '#000000',
      );
      final restored = HillshadeLayerProperties.fromJson(original.toJson());
      expect(restored.hillshadeExaggeration, 0.5);
      expect(restored.hillshadeShadowColor, '#000000');
    });

    test('copyWith overrides specified fields', () {
      const original = HillshadeLayerProperties(
        hillshadeIlluminationDirection: 335,
        hillshadeExaggeration: 0.5,
        hillshadeShadowColor: '#000000',
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const HillshadeLayerProperties(
          hillshadeIlluminationDirection: 180,
          hillshadeExaggeration: 0.8,
        ),
      );
      expect(updated.hillshadeIlluminationDirection, 180);
      expect(updated.hillshadeExaggeration, 0.8);
      expect(updated.hillshadeShadowColor, '#000000');
      expect(updated.visibility, 'visible');
    });
  });

  group('HeatmapLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = HeatmapLayerProperties(
        heatmapRadius: 30,
        heatmapIntensity: 0.5,
      );
      final json = props.toJson();
      expect(json['heatmap-radius'], 30);
      expect(json['heatmap-intensity'], 0.5);
    });

    test('fromJson roundtrip', () {
      const original = HeatmapLayerProperties(
        heatmapRadius: 30,
        heatmapOpacity: 0.7,
      );
      final restored = HeatmapLayerProperties.fromJson(original.toJson());
      expect(restored.heatmapRadius, 30);
      expect(restored.heatmapOpacity, 0.7);
    });
  });

  group('ColorReliefLayerProperties', () {
    // A color ramp keyed on ["elevation"], the shape the style spec expects
    // for color-relief-color.
    const colorRamp = [
      'interpolate',
      ['linear'],
      ['elevation'],
      0,
      '#000000',
      1000,
      '#FFFFFF',
    ];

    test('toJson with skipNulls', () {
      const props = ColorReliefLayerProperties(
        colorReliefOpacity: 0.7,
        colorReliefColor: colorRamp,
      );
      final json = props.toJson();
      expect(json['color-relief-opacity'], 0.7);
      expect(json['color-relief-color'], colorRamp);
      expect(json.containsKey('resampling'), isFalse);
    });

    test('fromJson roundtrip', () {
      const original = ColorReliefLayerProperties(
        colorReliefOpacity: 0.7,
        colorReliefColor: colorRamp,
        resampling: 'nearest',
        visibility: 'visible',
      );
      final restored = ColorReliefLayerProperties.fromJson(original.toJson());
      expect(restored.colorReliefOpacity, 0.7);
      expect(restored.colorReliefColor, colorRamp);
      expect(restored.resampling, 'nearest');
      expect(restored.visibility, 'visible');
    });

    test('copyWith overrides specified fields', () {
      const original = ColorReliefLayerProperties(
        colorReliefOpacity: 0.7,
        colorReliefColor: colorRamp,
        resampling: 'linear',
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const ColorReliefLayerProperties(
          colorReliefOpacity: 0.4,
          resampling: 'nearest',
        ),
      );
      expect(updated.colorReliefOpacity, 0.4);
      expect(updated.resampling, 'nearest');
      expect(updated.colorReliefColor, colorRamp);
      expect(updated.visibility, 'visible');
    });
  });

  group('BackgroundLayerProperties', () {
    test('toJson with skipNulls', () {
      const props = BackgroundLayerProperties(
        backgroundColor: '#FF0000',
        backgroundOpacity: 0.5,
      );
      final json = props.toJson();
      expect(json['background-color'], '#FF0000');
      expect(json['background-opacity'], 0.5);
      expect(json.containsKey('background-pattern'), isFalse);
      expect(json.containsKey('visibility'), isFalse);
    });

    test('fromJson roundtrip', () {
      const original = BackgroundLayerProperties(
        backgroundColor: '#FF0000',
        backgroundPattern: 'grid',
        backgroundOpacity: 0.5,
        visibility: 'visible',
      );
      final restored = BackgroundLayerProperties.fromJson(original.toJson());
      expect(restored.backgroundColor, '#FF0000');
      expect(restored.backgroundPattern, 'grid');
      expect(restored.backgroundOpacity, 0.5);
      expect(restored.visibility, 'visible');
    });

    test('copyWith overrides specified fields', () {
      const original = BackgroundLayerProperties(
        backgroundColor: '#FF0000',
        backgroundPattern: 'grid',
        visibility: 'visible',
      );
      final updated = original.copyWith(
        const BackgroundLayerProperties(
          backgroundColor: '#00FF00',
          backgroundOpacity: 0.5,
        ),
      );
      expect(updated.backgroundColor, '#00FF00');
      expect(updated.backgroundOpacity, 0.5);
      expect(updated.backgroundPattern, 'grid');
      expect(updated.visibility, 'visible');
    });
  });

  group('LayerProperties visibility', () {
    test('all layer types support visibility', () {
      final layers = <LayerProperties>[
        const CircleLayerProperties(visibility: 'visible'),
        const LineLayerProperties(visibility: 'none'),
        const FillLayerProperties(visibility: 'visible'),
        const SymbolLayerProperties(visibility: 'none'),
        const FillExtrusionLayerProperties(visibility: 'visible'),
        const RasterLayerProperties(visibility: 'none'),
        const HillshadeLayerProperties(visibility: 'visible'),
        const HeatmapLayerProperties(visibility: 'none'),
        const ColorReliefLayerProperties(visibility: 'visible'),
        const BackgroundLayerProperties(visibility: 'visible'),
      ];
      for (final layer in layers) {
        final json = layer.toJson();
        expect(json.containsKey('visibility'), isTrue);
      }
    });
  });
}
