import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('SymbolOptions', () {
    test('default options produce empty json', () {
      final json = SymbolOptions.defaultOptions.toJson() as Map<String, dynamic>;
      expect(json, isEmpty);
    });

    test('toJson includes non-null fields', () {
      const options = SymbolOptions(
        iconSize: 1.5,
        iconImage: 'marker',
        iconRotate: 45.0,
        textField: 'Hello',
        textSize: 14.0,
        geometry: LatLng(10.0, 20.0),
        draggable: true,
      );
      final json = options.toJson() as Map<String, dynamic>;
      expect(json['iconSize'], 1.5);
      expect(json['iconImage'], 'marker');
      expect(json['iconRotate'], 45.0);
      expect(json['textField'], 'Hello');
      expect(json['textSize'], 14.0);
      expect(json['geometry'], [10.0, 20.0]);
      expect(json['draggable'], true);
    });

    test('toJson with addGeometry=false excludes geometry', () {
      const options = SymbolOptions(
        iconSize: 1.5,
        geometry: LatLng(10.0, 20.0),
      );
      final json = options.toJson(false) as Map<String, dynamic>;
      expect(json.containsKey('geometry'), isFalse);
      expect(json['iconSize'], 1.5);
    });

    test('toJson serializes iconOffset and textOffset', () {
      const options = SymbolOptions(
        iconOffset: Offset(5.0, 10.0),
        textOffset: Offset(3.0, 7.0),
      );
      final json = options.toJson() as Map<String, dynamic>;
      expect(json['iconOffset'], [5.0, 10.0]);
      expect(json['textOffset'], [3.0, 7.0]);
    });

    test('copyWith merges changes', () {
      const original = SymbolOptions(iconSize: 1.0, textField: 'A');
      final merged = original.copyWith(const SymbolOptions(iconSize: 2.0));
      expect(merged.iconSize, 2.0);
      expect(merged.textField, 'A'); // preserved
    });

    test('toGeoJson produces valid GeoJSON Feature with Point', () {
      const options = SymbolOptions(
        iconSize: 1.5,
        geometry: LatLng(10.0, 20.0),
      );
      final geojson = options.toGeoJson();
      expect(geojson['type'], 'Feature');
      expect(geojson['geometry']['type'], 'Point');
      // GeoJSON coordinates are [lng, lat]
      expect(geojson['geometry']['coordinates'], [20.0, 10.0]);
      // properties should not contain geometry
      expect(
        (geojson['properties'] as Map).containsKey('geometry'),
        isFalse,
      );
    });
  });

  group('Symbol', () {
    test('toGeoJson includes id', () {
      final symbol = Symbol(
        'sym-1',
        const SymbolOptions(geometry: LatLng(10.0, 20.0)),
      );
      final geojson = symbol.toGeoJson();
      expect(geojson['id'], 'sym-1');
      expect(geojson['properties']['id'], 'sym-1');
    });

    test('translate moves geometry', () {
      final symbol = Symbol(
        'sym-1',
        const SymbolOptions(geometry: LatLng(10.0, 20.0)),
      );
      symbol.translate(const LatLng(1.0, 2.0));
      expect(symbol.options.geometry!.latitude, 11.0);
      expect(symbol.options.geometry!.longitude, 22.0);
    });

    test('data property', () {
      final symbol = Symbol(
        'sym-1',
        SymbolOptions.defaultOptions,
        {'key': 'value'},
      );
      expect(symbol.data, {'key': 'value'});
    });
  });

  group('CircleOptions', () {
    test('default options produce empty json', () {
      final json = CircleOptions.defaultOptions.toJson() as Map<String, dynamic>;
      expect(json, isEmpty);
    });

    test('toJson includes non-null fields', () {
      const options = CircleOptions(
        circleRadius: 10.0,
        circleColor: '#FF0000',
        circleOpacity: 0.8,
        geometry: LatLng(10.0, 20.0),
        draggable: false,
      );
      final json = options.toJson() as Map<String, dynamic>;
      expect(json['circleRadius'], 10.0);
      expect(json['circleColor'], '#FF0000');
      expect(json['circleOpacity'], 0.8);
      expect(json['geometry'], [10.0, 20.0]);
      expect(json['draggable'], false);
    });

    test('toJson with addGeometry=false excludes geometry', () {
      const options = CircleOptions(
        circleRadius: 10.0,
        geometry: LatLng(10.0, 20.0),
      );
      final json = options.toJson(false) as Map<String, dynamic>;
      expect(json.containsKey('geometry'), isFalse);
    });

    test('copyWith merges changes', () {
      const original = CircleOptions(circleRadius: 10.0, circleColor: '#000');
      final merged =
          original.copyWith(const CircleOptions(circleRadius: 20.0));
      expect(merged.circleRadius, 20.0);
      expect(merged.circleColor, '#000');
    });

    test('toGeoJson produces valid GeoJSON Feature with Point', () {
      const options = CircleOptions(geometry: LatLng(10.0, 20.0));
      final geojson = options.toGeoJson();
      expect(geojson['type'], 'Feature');
      expect(geojson['geometry']['type'], 'Point');
      expect(geojson['geometry']['coordinates'], [20.0, 10.0]);
    });
  });

  group('Circle', () {
    test('toGeoJson includes id', () {
      final circle = Circle(
        'circle-1',
        const CircleOptions(geometry: LatLng(10.0, 20.0)),
      );
      final geojson = circle.toGeoJson();
      expect(geojson['id'], 'circle-1');
      expect(geojson['properties']['id'], 'circle-1');
    });

    test('translate moves geometry', () {
      final circle = Circle(
        'circle-1',
        const CircleOptions(geometry: LatLng(10.0, 20.0)),
      );
      circle.translate(const LatLng(5.0, 5.0));
      expect(circle.options.geometry!.latitude, 15.0);
      expect(circle.options.geometry!.longitude, 25.0);
    });
  });

  group('LineOptions', () {
    test('default options produce empty json', () {
      final json = LineOptions.defaultOptions.toJson() as Map<String, dynamic>;
      expect(json, isEmpty);
    });

    test('toJson includes non-null fields', () {
      const options = LineOptions(
        lineColor: '#0000FF',
        lineWidth: 3.0,
        lineJoin: 'round',
        geometry: [LatLng(10.0, 20.0), LatLng(30.0, 40.0)],
      );
      final json = options.toJson() as Map<String, dynamic>;
      expect(json['lineColor'], '#0000FF');
      expect(json['lineWidth'], 3.0);
      expect(json['lineJoin'], 'round');
      expect(json['geometry'], isA<List>());
    });

    test('toJson serializes geometry as list of [lat, lng] pairs', () {
      const options = LineOptions(
        geometry: [LatLng(10.0, 20.0), LatLng(30.0, 40.0)],
      );
      final json = options.toJson() as Map<String, dynamic>;
      final geometry = json['geometry'] as List;
      expect(geometry[0], [10.0, 20.0]);
      expect(geometry[1], [30.0, 40.0]);
    });

    test('toJson with addGeometry=false excludes geometry', () {
      const options = LineOptions(
        lineWidth: 2.0,
        geometry: [LatLng(10.0, 20.0)],
      );
      final json = options.toJson(false) as Map<String, dynamic>;
      expect(json.containsKey('geometry'), isFalse);
    });

    test('copyWith merges changes', () {
      const original = LineOptions(lineWidth: 2.0, lineColor: '#000');
      final merged = original.copyWith(const LineOptions(lineWidth: 5.0));
      expect(merged.lineWidth, 5.0);
      expect(merged.lineColor, '#000');
    });

    test('toGeoJson produces valid GeoJSON Feature with LineString', () {
      const options = LineOptions(
        geometry: [LatLng(10.0, 20.0), LatLng(30.0, 40.0)],
      );
      final geojson = options.toGeoJson();
      expect(geojson['type'], 'Feature');
      expect(geojson['geometry']['type'], 'LineString');
      // GeoJSON coordinates are [lng, lat]
      final coords = geojson['geometry']['coordinates'] as List;
      expect(coords[0], [20.0, 10.0]);
      expect(coords[1], [40.0, 30.0]);
    });
  });

  group('Line', () {
    test('toGeoJson includes id', () {
      final line = Line(
        'line-1',
        const LineOptions(
          geometry: [LatLng(10.0, 20.0), LatLng(30.0, 40.0)],
        ),
      );
      final geojson = line.toGeoJson();
      expect(geojson['id'], 'line-1');
      expect(geojson['properties']['id'], 'line-1');
    });

    test('translate moves all geometry points', () {
      final line = Line(
        'line-1',
        const LineOptions(
          geometry: [LatLng(10.0, 20.0), LatLng(30.0, 40.0)],
        ),
      );
      line.translate(const LatLng(1.0, 2.0));
      expect(line.options.geometry![0], const LatLng(11.0, 22.0));
      expect(line.options.geometry![1], const LatLng(31.0, 42.0));
    });
  });

  group('FillOptions', () {
    test('default options produce empty json', () {
      final json = FillOptions.defaultOptions.toJson() as Map<String, dynamic>;
      expect(json, isEmpty);
    });

    test('toJson includes non-null fields', () {
      const options = FillOptions(
        fillOpacity: 0.5,
        fillColor: '#00FF00',
        fillOutlineColor: '#000000',
        draggable: true,
      );
      final json = options.toJson() as Map<String, dynamic>;
      expect(json['fillOpacity'], 0.5);
      expect(json['fillColor'], '#00FF00');
      expect(json['fillOutlineColor'], '#000000');
      expect(json['draggable'], true);
    });

    test('toJson serializes nested geometry correctly', () {
      const options = FillOptions(
        geometry: [
          [LatLng(0.0, 0.0), LatLng(10.0, 0.0), LatLng(10.0, 10.0)],
        ],
      );
      final json = options.toJson() as Map<String, dynamic>;
      final geometry = json['geometry'] as List;
      expect(geometry.length, 1);
      final ring = geometry[0] as List;
      expect(ring[0], [0.0, 0.0]);
      expect(ring[1], [10.0, 0.0]);
    });

    test('toJson with addGeometry=false excludes geometry', () {
      const options = FillOptions(
        fillOpacity: 0.5,
        geometry: [
          [LatLng(0.0, 0.0)],
        ],
      );
      final json = options.toJson(false) as Map<String, dynamic>;
      expect(json.containsKey('geometry'), isFalse);
    });

    test('copyWith merges changes', () {
      const original = FillOptions(fillOpacity: 0.5, fillColor: '#000');
      final merged = original.copyWith(const FillOptions(fillOpacity: 0.8));
      expect(merged.fillOpacity, 0.8);
      expect(merged.fillColor, '#000');
    });

    test('toGeoJson produces valid GeoJSON Feature with Polygon', () {
      const options = FillOptions(
        geometry: [
          [LatLng(0.0, 0.0), LatLng(10.0, 0.0), LatLng(10.0, 10.0)],
        ],
      );
      final geojson = options.toGeoJson();
      expect(geojson['type'], 'Feature');
      expect(geojson['geometry']['type'], 'Polygon');
      // GeoJSON coordinates are [lng, lat]
      final coords = geojson['geometry']['coordinates'] as List;
      final ring = coords[0] as List;
      expect(ring[0], [0.0, 0.0]);
      expect(ring[1], [0.0, 10.0]); // [lng=0, lat=10]
    });
  });

  group('Fill', () {
    test('toGeoJson includes id', () {
      final fill = Fill(
        'fill-1',
        const FillOptions(
          geometry: [
            [LatLng(0.0, 0.0), LatLng(10.0, 0.0), LatLng(10.0, 10.0)],
          ],
        ),
      );
      final geojson = fill.toGeoJson();
      expect(geojson['id'], 'fill-1');
      expect(geojson['properties']['id'], 'fill-1');
    });

    test('translate moves all geometry points in all rings', () {
      final fill = Fill(
        'fill-1',
        const FillOptions(
          geometry: [
            [LatLng(0.0, 0.0), LatLng(10.0, 0.0), LatLng(10.0, 10.0)],
          ],
        ),
      );
      fill.translate(const LatLng(1.0, 2.0));
      expect(fill.options.geometry![0][0], const LatLng(1.0, 2.0));
      expect(fill.options.geometry![0][1], const LatLng(11.0, 2.0));
      expect(fill.options.geometry![0][2], const LatLng(11.0, 12.0));
    });

    test('translate with null geometry returns same options', () {
      final fill = Fill('fill-1', const FillOptions(fillOpacity: 0.5));
      fill.translate(const LatLng(1.0, 2.0));
      expect(fill.options.fillOpacity, 0.5);
      expect(fill.options.geometry, isNull);
    });
  });

  group('translateFillOptions', () {
    test('translates all rings', () {
      const options = FillOptions(
        geometry: [
          [LatLng(0.0, 0.0), LatLng(10.0, 0.0)],
          [LatLng(2.0, 2.0), LatLng(5.0, 5.0)],
        ],
      );
      final translated =
          translateFillOptions(options, const LatLng(1.0, 1.0));
      expect(translated.geometry![0][0], const LatLng(1.0, 1.0));
      expect(translated.geometry![0][1], const LatLng(11.0, 1.0));
      expect(translated.geometry![1][0], const LatLng(3.0, 3.0));
      expect(translated.geometry![1][1], const LatLng(6.0, 6.0));
    });

    test('returns same options when geometry is null', () {
      const options = FillOptions(fillOpacity: 0.5);
      final result = translateFillOptions(options, const LatLng(1.0, 1.0));
      expect(identical(result, options), isTrue);
    });
  });
}
