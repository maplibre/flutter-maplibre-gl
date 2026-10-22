// The url and the bounds of a source as every platform hands them to
// MapLibre, so the same properties load the same data on Android, iOS and
// web.
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('encodeUrl', () {
    test('leaves a url that holds only url characters as it is', () {
      for (final url in [
        'https://example.com/a.json?x=1&y=%20#top',
        'data/points.geojson',
        'file:///var/mobile/Library/Application%20Support/a.json',
        'asset://points.geojson',
        'http://[::1]:8080/a.json',
        r"https://example.com/a-b_c.d~e/!$&'()*+,;=:@?/",
      ]) {
        expect(encodeUrl(url), url, reason: url);
      }
    });

    test('percent-encodes the characters a url cannot hold', () {
      final encoded = {
        'file:///var/mobile/Library/Application Support/a b.json':
            'file:///var/mobile/Library/Application%20Support/a%20b.json',
        'https://example.com/a|b': 'https://example.com/a%7Cb',
        'https://example.com/{z}': 'https://example.com/%7Bz%7D',
        'https://example.com/"a"': 'https://example.com/%22a%22',
        'https://example.com/a\tb': 'https://example.com/a%09b',
        r'https://example.com/a\b': 'https://example.com/a%5Cb',
        'https://example.com/<a>^`': 'https://example.com/%3Ca%3E%5E%60',
        'not a url': 'not%20a%20url',
      };
      for (final MapEntry(key: text, value: url) in encoded.entries) {
        expect(encodeUrl(text), url, reason: text);
      }
    });

    test('encodes a percent sign not followed by two hex digits', () {
      expect(encodeUrl('https://example.com/%zz'), 'https://example.com/%25zz');
      expect(encodeUrl('https://example.com/a%2'), 'https://example.com/a%252');
      expect(encodeUrl('100%'), '100%25');
      expect(encodeUrl('a%2fb%C3%A9'), 'a%2fb%C3%A9');
    });

    test('encodes a character beyond ASCII as UTF-8', () {
      expect(
        encodeUrl('https://example.com/café'),
        'https://example.com/caf%C3%A9',
      );
      expect(encodeUrl('a😀b'), 'a%F0%9F%98%80b');
    });

    test('keeps the first # and brackets in the host only', () {
      expect(
        encodeUrl('https://example.com/a#b#c'),
        'https://example.com/a#b%23c',
      );
      expect(
        encodeUrl('https://example.com/a?bbox[]=1'),
        'https://example.com/a?bbox%5B%5D=1',
      );
      expect(encodeUrl('http://[::1]/[a]'), 'http://[::1]/%5Ba%5D');
    });

    test('is null for an empty url and one that cannot be a url', () {
      for (final text in ['', 'https://example.com:port/a.json', 'http://[']) {
        expect(encodeUrl(text), isNull, reason: text);
      }
    });
  });

  group('normalizeSource', () {
    test('encodes the data url of a GeoJSON source', () {
      expect(normalizeSource({'type': 'geojson', 'data': 'a b.json'}), {
        'type': 'geojson',
        'data': 'a%20b.json',
      });
    });

    test('encodes the url of an image and a raster-dem source', () {
      for (final type in ['image', 'raster-dem']) {
        expect(
          normalizeSource({'type': type, 'url': 'a b', 'tiles': []}),
          {'type': type, 'url': 'a%20b', 'tiles': []},
          reason: type,
        );
      }
    });

    test('leaves out a url that cannot be one, so the source has none', () {
      expect(normalizeSource({'type': 'geojson', 'data': ''}), {
        'type': 'geojson',
      });
      expect(normalizeSource({'type': 'image', 'url': 'http://['}), {
        'type': 'image',
      });
    });

    test('gives bounds that cross the antimeridian every longitude', () {
      expect(
        normalizeSource({
          'type': 'vector',
          'tiles': ['https://example.com/{z}/{x}/{y}.pbf'],
          'bounds': [170, -10, -170.5, 10],
        }),
        {
          'type': 'vector',
          'tiles': ['https://example.com/{z}/{x}/{y}.pbf'],
          'bounds': [-180, -10, 180, 10],
        },
      );
    });

    test('leaves the rest as it is', () {
      final sources = [
        {'type': 'vector', 'url': 'a b'},
        {'type': 'raster', 'url': 'a b'},
        {
          'type': 'raster-dem',
          'tiles': ['https://example.com/{z}/{x}/{y}.png'],
        },
        {
          'type': 'geojson',
          'data': {'type': 'FeatureCollection', 'features': <Object>[]},
        },
        {'type': 'geojson', 'data': 'https://example.com/a.json'},
        {
          'type': 'raster',
          'bounds': [-10, -10, 10, 10],
        },
        // The platform rejects what are not bounds.
        {
          'type': 'raster',
          'bounds': [10, -10, double.nan, 10],
        },
        {
          'type': 'raster',
          'bounds': [10, -10, -10],
        },
      ];
      for (final source in sources) {
        expect(normalizeSource(source), same(source), reason: '$source');
      }
    });
  });
}
