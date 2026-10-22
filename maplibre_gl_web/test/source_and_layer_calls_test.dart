// Drives the source and layer calls of the web controller against a stand-in
// for maplibre-gl-js with a loaded style, which keeps what it is handed and
// reports errors the way the library does, so it needs a browser, but never
// the library itself: `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/utils.dart';

/// Stands in for a maplibre-gl-js map whose style has loaded: it keeps the
/// sources and layers it is given, refuses to remove a source a layer uses,
/// and reports that, or a layer it is told to reject, in an error event, as
/// the library does.
class _FakeMap {
  _FakeMap() {
    void method(String name, JSFunction function) =>
        jsObject.setProperty(name.toJS, function);

    method('getSource', ((JSString id) => sources[id.toDart]).toJS);
    method(
      'addSource',
      ((JSString id, JSObject spec) {
        sources[id.toDart] = _source(spec);
        return jsObject;
      }).toJS,
    );
    method(
      'removeSource',
      ((JSString id) {
        for (final MapEntry(key: layerId, value: layer) in layers.entries) {
          if (layer.getProperty<JSString?>('source'.toJS)?.toDart ==
              id.toDart) {
            fire(
              'Source "${id.toDart}" cannot be removed while layer '
              '"$layerId" is using it.',
            );
            return;
          }
        }
        sources.remove(id.toDart);
      }).toJS,
    );
    method('getLayer', ((JSString id) => layers[id.toDart]).toJS);
    method(
      'addLayer',
      ((JSObject layer, JSString? before) {
        final error = rejectLayer;
        if (error != null) {
          fire(error);
        } else {
          layers[layer.getProperty<JSString>('id'.toJS).toDart] = layer;
        }
        return jsObject;
      }).toJS,
    );
    method(
      'removeLayer',
      ((JSString id) {
        layers.remove(id.toDart);
      }).toJS,
    );
    method(
      'on',
      ((JSString type, JSAny? layerIdOrListener, [JSAny? listener]) {
        if (type.toDart == 'error') {
          errorListeners.add(layerIdOrListener! as JSFunction);
        } else {
          layerListeners.add(
            '${type.toDart} ${(layerIdOrListener! as JSString).toDart}',
          );
        }
        return JSObject()..setProperty('unsubscribe'.toJS, (() {}).toJS);
      }).toJS,
    );
    method(
      'off',
      ((JSString type, JSAny? layerIdOrListener, [JSAny? listener]) {
        if (type.toDart == 'error') {
          errorListeners.removeWhere(
            (known) => known.strictEquals(layerIdOrListener).toDart,
          );
        }
        return jsObject;
      }).toJS,
    );
    method(
      'getStyle',
      (() {
        final style = JSObject();
        final sourceSpecs = JSObject();
        for (final MapEntry(:key, :value) in sources.entries) {
          final spec = JSObject();
          for (final name in ['type', 'url', 'coordinates']) {
            final property = value.getProperty<JSAny?>(name.toJS);
            if (property != null) spec.setProperty(name.toJS, property);
          }
          sourceSpecs.setProperty(key.toJS, spec);
        }
        style.setProperty('sources'.toJS, sourceSpecs);
        style.setProperty('layers'.toJS, <JSAny?>[].toJS);
        return style;
      }).toJS,
    );
    method('setStyle', ((JSAny? style, JSAny? options) => jsObject).toJS);
  }

  final jsObject = JSObject();

  /// The sources by id, as the map holds them.
  final sources = <String, JSObject>{};

  /// The layers by id, as the map was handed them.
  final layers = <String, JSObject>{};

  final errorListeners = <JSFunction>[];

  /// The layer listeners attached, as "type layerId".
  final layerListeners = <String>[];

  /// The error the next layer adds report in place of adding the layer.
  String? rejectLayer;

  /// A source built from [spec]: it keeps its data or url, and setData
  /// settles a moment later, as the worker of maplibre-gl-js does.
  JSObject _source(JSObject spec) {
    final source = JSObject();
    for (final name in ['type', 'data', 'url', 'coordinates']) {
      source.setProperty(name.toJS, spec.getProperty<JSAny?>(name.toJS));
    }
    source.setProperty(
      'setData'.toJS,
      ((JSAny data) {
        source.setProperty('data'.toJS, data);
        return Future<JSAny?>.delayed(Duration.zero).toJS;
      }).toJS,
    );
    source.setProperty(
      'updateImage'.toJS,
      ((JSObject options) {
        source.setProperty('url'.toJS, options.getProperty('url'.toJS));
        return source;
      }).toJS,
    );
    source.setProperty(
      'setCoordinates'.toJS,
      ((JSAny coordinates) {
        source.setProperty('coordinates'.toJS, coordinates);
        return source;
      }).toJS,
    );
    return source;
  }

  /// Reports [message] in an error event, as maplibre-gl-js does.
  void fire(String message) {
    final event =
        JSObject()..setProperty(
          'error'.toJS,
          JSObject()..setProperty('message'.toJS, message.toJS),
        );
    for (final listener in List.of(errorListeners)) {
      listener.callAsFunction(null, event);
    }
  }

  /// The data of the source [sourceId], back in Dart.
  Object? data(String sourceId) =>
      dartify(sources[sourceId]!.getProperty<JSAny?>('data'.toJS));

  /// The url of the source [sourceId].
  String? url(String sourceId) =>
      sources[sourceId]!.getProperty<JSString?>('url'.toJS)?.toDart;
}

Map<String, dynamic> _point(int id, num n) => {
  'type': 'Feature',
  'id': id,
  'geometry': {
    'type': 'Point',
    'coordinates': [n, 0],
  },
  'properties': {'n': n},
};

Map<String, dynamic> _collection(List<Map<String, dynamic>> features) => {
  'type': 'FeatureCollection',
  'features': features,
};

void main() {
  late _FakeMap map;
  late MapLibreMapController controller;

  setUp(() {
    map = _FakeMap();
    controller =
        MapLibreMapController()..debugSetMap(
          MapLibreMap.fromJsObject(map.jsObject as MapLibreMapJsImpl),
          styleReady: true,
        );
  });

  group('GeoJSON sources', () {
    // A JS string is a Dart String when compiling to JavaScript, so the url
    // must not be cast to an object on its way to setData.
    test('editGeoJsonUrl hands the url to maplibre-gl-js, and '
        'setGeoJsonFeature then changes nothing', () async {
      await controller.addGeoJsonSource('points', _collection([_point(1, 1)]));

      expect(
        await controller.editGeoJsonUrl('points', 'https://example.com/a.json'),
        isTrue,
      );
      expect(map.data('points'), 'https://example.com/a.json');

      await controller.setFeatureForGeoJsonSource('points', _point(1, 5));
      expect(map.data('points'), 'https://example.com/a.json');
    });

    test('data set while editGeoJsonUrl runs stays editable', () async {
      await controller.addGeoJsonSource('points', _collection([_point(1, 1)]));

      final edit = controller.editGeoJsonUrl('points', 'https://example.com');
      await controller.setGeoJsonSource('points', _collection([_point(2, 2)]));
      await edit;
      await controller.setFeatureForGeoJsonSource('points', _point(2, 5));

      expect(map.data('points'), _collection([_point(2, 5)]));
    });
  });
}
