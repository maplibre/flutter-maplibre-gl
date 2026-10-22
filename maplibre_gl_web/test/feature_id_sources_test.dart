// Which GeoJSON sources the web controller makes keep the ids of their data,
// driven against a stand-in for maplibre-gl-js that holds its GeoJSON sources
// with the fields maplibre-gl-js 6 has. It needs a browser, but never the
// library itself: `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/feature_id_interop.dart';
import 'package:maplibre_gl_web/src/feature_ids.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';

/// Stands in for a maplibre-gl-js map with a loaded style: it keeps its
/// sources and layers, and the filters and properties set on the layers.
class _FakeMap {
  _FakeMap({this.sourceFields = true}) {
    void method(String name, JSFunction function) =>
        jsObject.setProperty(name.toJS, function);

    method('getSource', ((JSString id) => sources[id.toDart]).toJS);
    method(
      'addSource',
      ((JSString id, JSObject options) {
        sources[id.toDart] = geoJsonSource(options);
        return jsObject;
      }).toJS,
    );
    method('getLayer', ((JSString id) => _layer(id.toDart)).toJS);
    method(
      'getStyle',
      (() =>
              JSObject()
                ..setProperty('sources'.toJS, JSObject())
                ..setProperty('layers'.toJS, layers.toJS))
          .toJS,
    );
    method(
      'setFilter',
      ((JSString id, JSAny? filter) {
        _layer(id.toDart)!.setProperty('filter'.toJS, filter);
        changes.add('filter ${id.toDart}');
        return jsObject;
      }).toJS,
    );
    method(
      'getFilter',
      ((JSString id) => _layer(id.toDart)!.getProperty<JSAny?>('filter'.toJS))
          .toJS,
    );
    for (final (setter, group) in [
      ('setPaintProperty', 'paint'),
      ('setLayoutProperty', 'layout'),
    ]) {
      method(
        setter,
        ((JSString id, JSString name, JSAny? value) {
          final layer = _layer(id.toDart)!;
          var properties = layer.getProperty<JSObject?>(group.toJS);
          if (properties == null) {
            properties = JSObject();
            layer.setProperty(group.toJS, properties);
          }
          properties.setProperty(name, value);
          changes.add('$group ${id.toDart} ${name.toDart}');
          return jsObject;
        }).toJS,
      );
    }
  }

  /// Whether the GeoJSON sources have the fields maplibre-gl-js 6 has.
  final bool sourceFields;

  final jsObject = JSObject();

  final sources = <String, JSObject>{};

  /// The layers of the style, as getStyle() serializes them.
  final layers = <JSObject>[];

  /// The filters and properties set, as "filter layerId" or
  /// "paint layerId name".
  final changes = <String>[];

  JSObject? _layer(String id) {
    for (final layer in layers) {
      if (layer.getProperty<JSString>('id'.toJS).toDart == id) return layer;
    }
    return null;
  }

  /// A GeoJSON source made from [options], as maplibre-gl-js 6 holds it: it
  /// keeps the data it is given, the object itself.
  JSObject geoJsonSource(JSObject options) {
    final promoteId = options.getProperty<JSAny?>('promoteId'.toJS);
    final generateId = options.getProperty<JSAny?>('generateId'.toJS);
    final source = JSObject()..setProperty('type'.toJS, 'geojson'.toJS);
    source.setProperty('data'.toJS, options.getProperty('data'.toJS));
    if (sourceFields) {
      source.setProperty('promoteId'.toJS, promoteId);
      source.setProperty(
        'workerOptions'.toJS,
        JSObject()..setProperty(
          'geojsonVtOptions'.toJS,
          JSObject()
            ..setProperty('promoteId'.toJS, promoteId)
            ..setProperty('generateId'.toJS, generateId ?? false.toJS),
        ),
      );
    }
    // The options it was created with, and its data.
    source.setProperty(
      'serialize'.toJS,
      (() {
        final serialized = JSObject()..setProperty('type'.toJS, 'geojson'.toJS);
        if (promoteId != null) {
          serialized.setProperty('promoteId'.toJS, promoteId);
        }
        if (generateId != null) {
          serialized.setProperty('generateId'.toJS, generateId);
        }
        serialized.setProperty(
          'data'.toJS,
          source.getProperty<JSAny?>('data'.toJS),
        );
        return serialized;
      }).toJS,
    );
    source.setProperty(
      'setData'.toJS,
      ((JSAny data) {
        source.setProperty('data'.toJS, data);
        return Future<JSAny?>.value().toJS;
      }).toJS,
    );
    return source;
  }

  /// Adds the source [id] as a style declares it, with [options].
  void declareSource(String id, Map<String, Object?> options) {
    sources[id] = geoJsonSource(options.jsify()! as JSObject);
  }

  /// Adds the layer [id] on [source] as a style declares it.
  void declareLayer(
    String id,
    String source, {
    Object? filter,
    Map<String, Object?>? paint,
  }) {
    layers.add(
      {
            'id': id,
            'type': 'circle',
            'source': source,
            if (filter != null) 'filter': filter,
            if (paint != null) 'paint': paint,
          }.jsify()!
          as JSObject,
    );
  }

  /// The promoteId of the source [id] and the one its worker gets.
  List<Object?> promoteIds(String id) {
    final source = sources[id]!;
    return [
      source.getProperty<JSAny?>('promoteId'.toJS).dartify(),
      source
          .getProperty<JSObject?>('workerOptions'.toJS)
          ?.getProperty<JSObject>('geojsonVtOptions'.toJS)
          .getProperty<JSAny?>('promoteId'.toJS)
          .dartify(),
    ];
  }

  /// The [featureIdProperty] of each feature of the source [id], by its id.
  Map<Object?, Object?> keptIds(String id) {
    final data =
        sources[id]!.getProperty<JSAny?>('data'.toJS).dartify()! as Map;
    return {
      for (final feature in (data['features'] as List).cast<Map>())
        feature['id']: (feature['properties'] as Map?)?[featureIdProperty],
    };
  }
}

Map<String, Object?> _collection(List<Object?> ids) => {
  'type': 'FeatureCollection',
  'features': [
    for (final id in ids)
      {
        'type': 'Feature',
        if (id != null) 'id': id,
        'geometry': {
          'type': 'Point',
          'coordinates': [0, 0],
        },
        'properties': {'name': 'a'},
      },
  ],
};

void main() {
  late _FakeMap map;
  late MapLibreMapController controller;

  void useMap(_FakeMap fake) {
    map = fake;
    controller =
        MapLibreMapController()..debugSetMap(
          MapLibreMap.fromJsObject(map.jsObject as MapLibreMapJsImpl),
          styleReady: true,
        );
  }

  setUp(() {
    debugResetFeatureIdWarning();
    useMap(_FakeMap());
  });

  group('a GeoJSON source keeps the ids of the data the plugin sets', () {
    test('added with addGeoJsonSource or addSource', () async {
      await controller.addGeoJsonSource('a', _collection(['poi-12', 2, null]));
      await controller.addSource(
        'b',
        GeojsonSourceProperties(data: _collection([2.5])),
      );

      for (final id in ['a', 'b']) {
        expect(map.promoteIds(id), [featureIdProperty, featureIdProperty]);
      }
      expect(map.keptIds('a'), {'poi-12': 'poi-12', 2: 2, null: null});
      expect(map.keptIds('b'), {2.5: 2.5});
    });

    test('declared in the style, from setGeoJsonSource on', () async {
      map.declareSource('style', {'type': 'geojson', 'data': _collection([])});

      await controller.setGeoJsonSource('style', _collection(['poi-12']));

      expect(map.promoteIds('style'), [featureIdProperty, featureIdProperty]);
      expect(map.keptIds('style'), {'poi-12': 'poi-12'});
    });
  });

  group('a GeoJSON source keeps the ids maplibre-gl-js gives it', () {
    test('with generateId', () async {
      await controller.addSource(
        'generated',
        GeojsonSourceProperties(data: _collection([7, 8]), generateId: true),
      );
      map.declareSource('style', {
        'type': 'geojson',
        'generateId': true,
        'data': _collection([]),
      });

      await controller.setGeoJsonSource('generated', _collection([9]));
      await controller.setGeoJsonSource('style', _collection([9]));
      await controller.editGeoJsonSource(
        'style',
        '{"type":"Feature","id":9,"geometry":null,"properties":{}}',
      );

      for (final id in ['generated', 'style']) {
        expect(map.promoteIds(id), [null, null], reason: id);
      }
      expect(map.keptIds('generated'), {9: null});
    });

    test('with a promoteId of the app or the style', () async {
      await controller.addGeoJsonSource(
        'app',
        _collection(['poi-12']),
        promoteId: 'ref',
      );
      await controller.addSource(
        'props',
        GeojsonSourceProperties(data: _collection([2]), promoteId: 'ref'),
      );
      map.declareSource('style', {
        'type': 'geojson',
        'promoteId': 'ref',
        'data': _collection([]),
      });
      await controller.setGeoJsonSource('style', _collection([3]));

      for (final id in ['app', 'props', 'style']) {
        expect(map.promoteIds(id), ['ref', 'ref'], reason: id);
      }
      expect(map.keptIds('app'), {'poi-12': null});
      expect(map.keptIds('style'), {3: null});
    });

    test('in a maplibre-gl-js build without the fields, with one '
        'warning', () async {
      final warnings = <String>[];
      final console = globalContext.getProperty<JSObject>('console'.toJS);
      final warn = console.getProperty<JSFunction>('warn'.toJS);
      console.setProperty(
        'warn'.toJS,
        ((JSAny? message) {
          warnings.add('${message.dartify()}');
        }).toJS,
      );
      addTearDown(() => console.setProperty('warn'.toJS, warn));
      useMap(_FakeMap(sourceFields: false));

      await controller.addGeoJsonSource('a', _collection(['poi-12']));
      await controller.setGeoJsonSource('a', _collection(['poi-12']));
      await controller.addSource(
        'b',
        GeojsonSourceProperties(data: _collection([2])),
      );

      expect(map.keptIds('a'), {'poi-12': null});
      expect(map.keptIds('b'), {2: null});
      expect(warnings, [contains('integers only')]);
    });
  });
}
