import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_native/src/presentation/ornaments/attribution_ornament.dart';

void main() {
  group('parseAttributionHtml', () {
    test('decodes named entities in plain text runs', () {
      final runs = parseAttributionHtml(
        '<a href="https://openfreemap.org">OpenFreeMap</a> '
        '&copy; <a href="https://openmaptiles.org">OpenMapTiles</a>',
      );
      expect(runs, hasLength(3));
      expect(runs[0].text, 'OpenFreeMap');
      expect(runs[0].href, 'https://openfreemap.org');
      expect(runs[1].text.trim(), '©');
      expect(runs[1].isLink, isFalse);
      expect(runs[2].text, 'OpenMapTiles');
    });

    test('decodes entities inside link labels', () {
      final runs = parseAttributionHtml(
        '<a href="https://example.com">Tiles &amp; Data</a>',
      );
      expect(runs.single.text, 'Tiles & Data');
      expect(runs.single.href, 'https://example.com');
    });

    test('decodes decimal and hex numeric entities', () {
      final runs = parseAttributionHtml('&#169; 2026 &#xA9; Example');
      expect(runs.single.text.trim(), '© 2026 © Example');
    });

    test('leaves unknown and malformed entities literal', () {
      final runs = parseAttributionHtml('a &unknown; b &#xFFFFFFFF; c &copy');
      expect(runs.single.text, 'a &unknown; b &#xFFFFFFFF; c &copy');
    });

    test('does not double-decode: &amp;copy; stays literal', () {
      final runs = parseAttributionHtml('&amp;copy; is written &amp;copy;');
      expect(runs.single.text, '&copy; is written &copy;');
    });

    test('strips non-anchor tags and keeps their text', () {
      final runs = parseAttributionHtml(
        '<span>Data from</span> <a href="https://osm.org">OpenStreetMap</a>',
      );
      expect(runs, hasLength(2));
      expect(runs[0].text.trim(), 'Data from');
      expect(runs[1].text, 'OpenStreetMap');
    });
  });

  group('attributionFragments', () {
    test('prepends the MapLibre credit when no source claims it', () {
      final fragments = attributionFragments(['© Example']);
      expect(fragments, hasLength(2));
      expect(fragments.first, contains('maplibre.org'));
    });

    test('does not duplicate an existing MapLibre credit', () {
      final fragments = attributionFragments([
        '<a href="https://maplibre.org/">MapLibre</a>',
      ]);
      expect(fragments, hasLength(1));
    });
  });
}
