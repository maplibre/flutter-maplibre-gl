import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('OfflineRegionDefinition', () {
    final bounds = LatLngBounds(
      southwest: const LatLng(10.0, 20.0),
      northeast: const LatLng(30.0, 40.0),
    );

    test('basic construction', () {
      final def = OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: 'https://example.com/style.json',
        minZoom: 5.0,
        maxZoom: 15.0,
      );
      expect(def.bounds, bounds);
      expect(def.mapStyleUrl, 'https://example.com/style.json');
      expect(def.minZoom, 5.0);
      expect(def.maxZoom, 15.0);
      expect(def.includeIdeographs, false); // default
    });

    test('with includeIdeographs', () {
      final def = OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: 'https://example.com/style.json',
        minZoom: 0.0,
        maxZoom: 20.0,
        includeIdeographs: true,
      );
      expect(def.includeIdeographs, true);
    });

    test('toMap produces correct structure', () {
      final def = OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: 'https://example.com/style.json',
        minZoom: 5.0,
        maxZoom: 15.0,
        includeIdeographs: true,
      );
      final map = def.toMap();
      expect(map['bounds'], bounds.toList());
      expect(map['mapStyleUrl'], 'https://example.com/style.json');
      expect(map['minZoom'], 5.0);
      expect(map['maxZoom'], 15.0);
      expect(map['includeIdeographs'], true);
    });

    test('fromMap roundtrip', () {
      final original = OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: 'https://example.com/style.json',
        minZoom: 5.0,
        maxZoom: 15.0,
        includeIdeographs: true,
      );
      final restored = OfflineRegionDefinition.fromMap(original.toMap());
      expect(restored.bounds, original.bounds);
      expect(restored.mapStyleUrl, original.mapStyleUrl);
      expect(restored.minZoom, original.minZoom);
      expect(restored.maxZoom, original.maxZoom);
      expect(restored.includeIdeographs, original.includeIdeographs);
    });

    test('fromMap handles integer zoom values', () {
      final map = <String, dynamic>{
        'bounds': [
          [10.0, 20.0],
          [30.0, 40.0],
        ],
        'mapStyleUrl': 'https://example.com/style.json',
        'minZoom': 5, // int, not double
        'maxZoom': 15, // int, not double
        'includeIdeographs': false,
      };
      final def = OfflineRegionDefinition.fromMap(map);
      expect(def.minZoom, 5.0);
      expect(def.maxZoom, 15.0);
    });

    test('toString', () {
      final def = OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: 'https://example.com/style.json',
        minZoom: 5.0,
        maxZoom: 15.0,
      );
      expect(def.toString(), contains('OfflineRegionDefinition'));
      expect(def.toString(), contains('5.0'));
    });
  });

  group('OfflineRegion', () {
    test('fromMap constructs correctly', () {
      final map = <String, dynamic>{
        'id': 42,
        'definition': {
          'bounds': [
            [10.0, 20.0],
            [30.0, 40.0],
          ],
          'mapStyleUrl': 'https://example.com/style.json',
          'minZoom': 5.0,
          'maxZoom': 15.0,
          'includeIdeographs': false,
        },
        'metadata': {'name': 'Test Region'},
      };
      final region = OfflineRegion.fromMap(map);
      expect(region.id, 42);
      expect(
        region.definition.mapStyleUrl,
        'https://example.com/style.json',
      );
      expect(region.metadata['name'], 'Test Region');
    });

    test('toString', () {
      final region = OfflineRegion(
        id: 1,
        definition: OfflineRegionDefinition(
          bounds: LatLngBounds(
            southwest: const LatLng(0.0, 0.0),
            northeast: const LatLng(1.0, 1.0),
          ),
          mapStyleUrl: 'https://example.com/style.json',
          minZoom: 0.0,
          maxZoom: 10.0,
        ),
        metadata: const {},
      );
      expect(region.toString(), contains('OfflineRegion'));
      expect(region.toString(), contains('1'));
    });
  });

  group('DownloadRegionStatus', () {
    test('Success is a DownloadRegionStatus', () {
      final status = Success();
      expect(status, isA<DownloadRegionStatus>());
    });

    test('InProgress stores progress', () {
      final status = InProgress(0.5);
      expect(status, isA<DownloadRegionStatus>());
      expect(status.progress, 0.5);
    });

    test('InProgress toString', () {
      final status = InProgress(0.75);
      expect(status.toString(), contains('0.75'));
    });

    test('Error stores cause', () {
      final cause = PlatformException(code: 'ERROR', message: 'fail');
      final status = Error(cause);
      expect(status, isA<DownloadRegionStatus>());
      expect(status.cause, cause);
    });

    test('Error toString', () {
      final cause = PlatformException(code: 'ERROR', message: 'fail');
      final status = Error(cause);
      expect(status.toString(), contains('Error'));
    });
  });
}
