import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/presentation/platform/style_layers.dart';

/// The paint/layout split of the flat maplibre_gl property maps, driven by
/// the hand-maintained layout-key table: a property filed on the wrong side
/// is silently ignored by the style parser, so this is what would catch a
/// missing table entry for the common properties of each layer family.
void main() {
  group('styleLayerJson', () {
    Map<String, dynamic> build(
      StyleLayerType type,
      Map<String, dynamic> properties,
    ) => styleLayerJson(
      type: type,
      sourceId: 'src',
      layerId: 'lyr',
      properties: properties,
    );

    test('splits the common symbol properties into layout and paint', () {
      final json = build(StyleLayerType.symbol, <String, dynamic>{
        'icon-image': 'marker',
        'text-field': '{name}',
        'text-size': 12,
        'icon-allow-overlap': true,
        'icon-color': '#ff0000',
        'text-halo-width': 2,
      });
      expect(json['layout'], {
        'icon-image': 'marker',
        'text-field': '{name}',
        'text-size': 12,
        'icon-allow-overlap': true,
      });
      expect(json['paint'], {
        'icon-color': '#ff0000',
        'text-halo-width': 2,
      });
    });

    test('splits the common line properties', () {
      final json = build(StyleLayerType.line, <String, dynamic>{
        'line-cap': 'round',
        'line-join': 'bevel',
        'line-color': '#00ff00',
        'line-width': 3,
        'line-dasharray': [2, 1],
      });
      expect(json['layout'], {'line-cap': 'round', 'line-join': 'bevel'});
      expect(json['paint'], {
        'line-color': '#00ff00',
        'line-width': 3,
        'line-dasharray': [2, 1],
      });
    });

    test('fill and circle have only their sort key (and visibility) in '
        'layout', () {
      final fill = build(StyleLayerType.fill, <String, dynamic>{
        'fill-sort-key': 1,
        'visibility': 'none',
        'fill-color': '#0000ff',
        'fill-outline-color': '#000000',
      });
      expect(fill['layout'], {'fill-sort-key': 1, 'visibility': 'none'});
      expect(fill['paint'], {
        'fill-color': '#0000ff',
        'fill-outline-color': '#000000',
      });

      final circle = build(StyleLayerType.circle, <String, dynamic>{
        'circle-sort-key': 2,
        'circle-radius': 6,
        'circle-color': '#123456',
      });
      expect(circle['layout'], {'circle-sort-key': 2});
      expect(circle['paint'], {
        'circle-radius': 6,
        'circle-color': '#123456',
      });
    });

    test('an unknown property lands in paint (the documented fallback)', () {
      final json = build(StyleLayerType.fill, <String, dynamic>{
        'made-up-property': 42,
      });
      expect(json['paint'], {'made-up-property': 42});
      expect(json.containsKey('layout'), isFalse);
    });

    test('empty properties produce neither a layout nor a paint object', () {
      final json = build(StyleLayerType.raster, <String, dynamic>{});
      expect(json.containsKey('layout'), isFalse);
      expect(json.containsKey('paint'), isFalse);
    });

    test('optional fields are included only when given', () {
      final bare = build(StyleLayerType.fill, <String, dynamic>{});
      expect(bare, {'id': 'lyr', 'type': 'fill', 'source': 'src'});

      final full = styleLayerJson(
        type: StyleLayerType.line,
        sourceId: 'src',
        layerId: 'lyr',
        properties: <String, dynamic>{},
        sourceLayer: 'roads',
        minzoom: 4,
        maxzoom: 16,
        filter: ['==', 'class', 'motorway'],
      );
      expect(full['source-layer'], 'roads');
      expect(full['minzoom'], 4);
      expect(full['maxzoom'], 16);
      expect(full['filter'], ['==', 'class', 'motorway']);
    });

    test('fill-extrusion spells its style-spec type with the hyphen', () {
      final json = build(StyleLayerType.fillExtrusion, <String, dynamic>{});
      expect(json['type'], 'fill-extrusion');
    });
  });
}
