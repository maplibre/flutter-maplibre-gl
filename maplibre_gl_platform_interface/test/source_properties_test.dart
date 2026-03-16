import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('VectorSourceProperties', () {
    test('toJson includes type "vector"', () {
      const props = VectorSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'vector');
    });

    test('default values are included in toJson', () {
      const props = VectorSourceProperties();
      final json = props.toJson();
      expect(json['bounds'], [-180, -85.051129, 180, 85.051129]);
      expect(json['scheme'], 'xyz');
      expect(json['minzoom'], 0);
      expect(json['maxzoom'], 22);
    });

    test('toJson omits null fields', () {
      const props = VectorSourceProperties();
      final json = props.toJson();
      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('tiles'), isFalse);
      expect(json.containsKey('attribution'), isFalse);
      expect(json.containsKey('promoteId'), isFalse);
    });

    test('toJson includes non-null fields', () {
      const props = VectorSourceProperties(
        url: 'https://example.com/tiles.json',
        tiles: ['https://example.com/{z}/{x}/{y}.pbf'],
        attribution: '(c) Test',
      );
      final json = props.toJson();
      expect(json['url'], 'https://example.com/tiles.json');
      expect(json['tiles'], ['https://example.com/{z}/{x}/{y}.pbf']);
      expect(json['attribution'], '(c) Test');
    });

    test('fromJson roundtrip', () {
      const original = VectorSourceProperties(
        url: 'https://example.com/tiles.json',
        minzoom: 2,
        maxzoom: 14,
      );
      final restored = VectorSourceProperties.fromJson(original.toJson());
      expect(restored.url, original.url);
      expect(restored.minzoom, original.minzoom);
      expect(restored.maxzoom, original.maxzoom);
    });

    test('copyWith replaces specified fields', () {
      const original = VectorSourceProperties(
        url: 'https://old.com',
      );
      final updated = original.copyWith(
        'https://new.com',
        null,
        null,
        null,
        5,
        null,
        null,
        null,
      );
      expect(updated.url, 'https://new.com');
      expect(updated.minzoom, 5);
      expect(updated.maxzoom, 22); // preserved default
    });
  });

  group('RasterSourceProperties', () {
    test('toJson includes type "raster"', () {
      const props = RasterSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'raster');
    });

    test('default values', () {
      const props = RasterSourceProperties();
      final json = props.toJson();
      expect(json['minzoom'], 0);
      expect(json['maxzoom'], 22);
      expect(json['tileSize'], 512);
      expect(json['scheme'], 'xyz');
    });

    test('fromJson roundtrip', () {
      const original = RasterSourceProperties(
        url: 'https://example.com/raster',
        tileSize: 256,
      );
      final restored = RasterSourceProperties.fromJson(original.toJson());
      expect(restored.url, original.url);
      expect(restored.tileSize, original.tileSize);
    });

    test('copyWith replaces specified fields', () {
      const original = RasterSourceProperties();
      final updated = original.copyWith(
        null,
        null,
        null,
        null,
        null,
        256,
        null,
        null,
      );
      expect(updated.tileSize, 256);
      expect(updated.scheme, 'xyz'); // preserved
    });
  });

  group('RasterDemSourceProperties', () {
    test('toJson includes type "raster-dem"', () {
      const props = RasterDemSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'raster-dem');
    });

    test('default encoding is "mapbox"', () {
      const props = RasterDemSourceProperties();
      final json = props.toJson();
      expect(json['encoding'], 'mapbox');
    });

    test('fromJson roundtrip', () {
      const original = RasterDemSourceProperties(
        encoding: 'terrarium',
        tileSize: 256,
      );
      final restored = RasterDemSourceProperties.fromJson(original.toJson());
      expect(restored.encoding, 'terrarium');
      expect(restored.tileSize, 256);
    });

    test('copyWith replaces specified fields', () {
      const original = RasterDemSourceProperties();
      final updated = original.copyWith(
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        'terrarium',
      );
      expect(updated.encoding, 'terrarium');
    });
  });

  group('GeojsonSourceProperties', () {
    test('toJson includes type "geojson"', () {
      const props = GeojsonSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'geojson');
    });

    test('default values', () {
      const props = GeojsonSourceProperties();
      final json = props.toJson();
      expect(json['maxzoom'], 18);
      expect(json['buffer'], 128);
      expect(json['tolerance'], 0.375);
      expect(json['cluster'], false);
      expect(json['clusterRadius'], 50);
      expect(json['lineMetrics'], false);
      expect(json['generateId'], false);
    });

    test('toJson omits null fields', () {
      const props = GeojsonSourceProperties();
      final json = props.toJson();
      expect(json.containsKey('data'), isFalse);
      expect(json.containsKey('attribution'), isFalse);
      expect(json.containsKey('clusterMaxZoom'), isFalse);
    });

    test('toJson with data', () {
      const props = GeojsonSourceProperties(
        data: 'https://example.com/data.geojson',
        cluster: true,
        clusterRadius: 75,
      );
      final json = props.toJson();
      expect(json['data'], 'https://example.com/data.geojson');
      expect(json['cluster'], true);
      expect(json['clusterRadius'], 75);
    });

    test('fromJson roundtrip', () {
      const original = GeojsonSourceProperties(
        data: 'https://example.com/data.geojson',
        cluster: true,
        clusterMaxZoom: 14,
      );
      final restored = GeojsonSourceProperties.fromJson(original.toJson());
      expect(restored.data, original.data);
      expect(restored.cluster, original.cluster);
      expect(restored.clusterMaxZoom, original.clusterMaxZoom);
    });

    test('copyWith replaces specified fields', () {
      const original = GeojsonSourceProperties();
      final updated = original.copyWith(
        null,
        null,
        null,
        null,
        null,
        true,
        null,
        null,
        null,
        null,
        null,
        null,
      );
      expect(updated.cluster, true);
      expect(updated.buffer, 128); // preserved
    });
  });

  group('VideoSourceProperties', () {
    test('toJson includes type "video"', () {
      const props = VideoSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'video');
    });

    test('toJson omits null fields', () {
      const props = VideoSourceProperties();
      final json = props.toJson();
      expect(json.containsKey('urls'), isFalse);
      expect(json.containsKey('coordinates'), isFalse);
    });

    test('toJson with values', () {
      const props = VideoSourceProperties(
        urls: ['https://example.com/video.mp4'],
        coordinates: [
          [-122.51596391201019, 37.56238816766053],
          [-122.51467645168304, 37.56410183312965],
        ],
      );
      final json = props.toJson();
      expect(json['urls'], ['https://example.com/video.mp4']);
      expect(json['coordinates'], isA<List>());
    });

    test('fromJson roundtrip', () {
      const original = VideoSourceProperties(
        urls: ['https://example.com/video.mp4'],
      );
      final restored = VideoSourceProperties.fromJson(original.toJson());
      expect(restored.urls, original.urls);
    });

    test('copyWith replaces specified fields', () {
      const original = VideoSourceProperties(
        urls: ['https://old.com/video.mp4'],
      );
      final updated = original.copyWith(['https://new.com/video.mp4'], null);
      expect(updated.urls, ['https://new.com/video.mp4']);
    });
  });

  group('ImageSourceProperties', () {
    test('toJson includes type "image"', () {
      const props = ImageSourceProperties();
      final json = props.toJson();
      expect(json['type'], 'image');
    });

    test('toJson omits null fields', () {
      const props = ImageSourceProperties();
      final json = props.toJson();
      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('coordinates'), isFalse);
    });

    test('toJson with values', () {
      const props = ImageSourceProperties(
        url: 'https://example.com/image.png',
      );
      final json = props.toJson();
      expect(json['url'], 'https://example.com/image.png');
    });

    test('fromJson roundtrip', () {
      const original = ImageSourceProperties(
        url: 'https://example.com/image.png',
      );
      final restored = ImageSourceProperties.fromJson(original.toJson());
      expect(restored.url, original.url);
    });

    test('copyWith replaces specified fields', () {
      const original = ImageSourceProperties(
        url: 'https://old.com/image.png',
      );
      final updated = original.copyWith('https://new.com/image.png', null);
      expect(updated.url, 'https://new.com/image.png');
    });
  });
}
