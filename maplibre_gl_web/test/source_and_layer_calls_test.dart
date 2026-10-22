// Drives the source and layer calls of the web controller against a stand-in
// for maplibre-gl-js with a loaded style, which keeps what it is handed and
// reports errors the way the library does, so it needs a browser, but never
// the library itself: `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/feature_ids.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/utils.dart';
import 'package:web/web.dart' as web;

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
    for (final kind in ['Paint', 'Layout']) {
      method(
        'get${kind}Property',
        ((JSString layerId, JSString name) =>
                _properties(layerId.toDart, kind)[name.toDart])
            .toJS,
      );
      method(
        'set${kind}Property',
        ((JSString layerId, JSString name, [JSAny? value, JSAny? options]) {
          _properties(layerId.toDart, kind)[name.toDart] = value;
          return jsObject;
        }).toJS,
      );
    }
    method(
      'once',
      ((JSString type, JSFunction listener) {
        once.add((type: type.toDart, listener: listener));
        return JSObject()..setProperty('unsubscribe'.toJS, (() {}).toJS);
      }).toJS,
    );
    method('triggerRepaint', (() {}).toJS);
    method('getCanvas', (() => canvas).toJS);
  }

  /// The paint or layout properties set on the layer [layerId], by [kind].
  Map<String, JSAny?> _properties(String layerId, String kind) =>
      properties.putIfAbsent('$layerId $kind', () => {});

  /// The paint and layout properties set on each layer, by "layerId Paint" or
  /// "layerId Layout".
  final properties = <String, Map<String, JSAny?>>{};

  /// The listeners waiting for one event.
  final once = <({String type, JSFunction listener})>[];

  final canvas = web.HTMLCanvasElement();

  /// Fires the event [type] to the listeners waiting for one.
  void fireOnce(String type) {
    final waiting = once.where((entry) => entry.type == type).toList();
    once.removeWhere((entry) => entry.type == type);
    for (final entry in waiting) {
      entry.listener.callAsFunction(null, JSObject());
    }
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

/// A position class of a GeoJSON library: `jsonEncode` writes it as the list
/// its `toJson()` returns.
class _Position {
  const _Position(this.longitude, this.latitude);

  final num longitude;
  final num latitude;

  List<num> toJson() => [longitude, latitude];
}

/// A geometry class of an app model, written as the map its `toJson()`
/// returns.
class _Geometry {
  const _Geometry(this.type, this.coordinates);

  final String type;
  final Object? coordinates;

  Map<String, Object?> toJson() => {'type': type, 'coordinates': coordinates};
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

const _quad = LatLngQuad(
  topLeft: LatLng(2, -2),
  topRight: LatLng(2, 2),
  bottomRight: LatLng(-2, 2),
  bottomLeft: LatLng(-2, -2),
);

/// A PNG of [width] pixels by one.
Uint8List _png(int width) => img.encodePng(img.Image(width: width, height: 1));

/// Whether the object URL [url] still gives its blob.
Future<bool> _isLive(String url) async {
  try {
    await web.window.fetch(url.toJS).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

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

  TypeMatcher<PlatformException> platformError(String code) =>
      isA<PlatformException>().having((e) => e.code, 'code', code);

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

    test('editGeoJsonSource reads the text once and keeps the data for '
        'setGeoJsonFeature', () async {
      await controller.addGeoJsonSource('points', _collection([]));

      expect(
        await controller.editGeoJsonSource(
          'points',
          jsonEncode(_collection([_point(1, 1)])),
        ),
        isTrue,
      );
      await controller.setFeatureForGeoJsonSource('points', _point(1, 5));

      expect(map.data('points'), _collection([_point(1, 5)]));
      await expectLater(
        controller.editGeoJsonSource('points', 'not json'),
        throwsA(
          platformError('INVALID_GEOJSON').having(
            (e) => e.message,
            'message',
            "The data for source 'points' is not GeoJSON: Not valid JSON.",
          ),
        ),
      );
    });

    // Android and iOS send what jsonEncode writes, and it writes an object
    // through its toJson().
    test('objects with toJson() go in as what toJson() returns', () async {
      final line = {
        'type': 'Feature',
        'id': 1,
        'geometry': const _Geometry('LineString', [
          _Position(1, 2),
          _Position(3, 4),
        ]),
        'properties': {'n': 1},
      };
      final plain = jsonDecode(jsonEncode(line)) as Map<String, dynamic>;

      await controller.addGeoJsonSource('line', _collection([line]));
      expect(_withoutKeptIds(map.data('line')), _collection([plain]));

      await controller.setGeoJsonSource('line', _collection([line]));
      await controller.setFeatureForGeoJsonSource('line', {
        ...line,
        'properties': {'n': 2},
      });
      expect(
        _withoutKeptIds(map.data('line')),
        _collection([
          {
            ...plain,
            'properties': {'n': 2},
          },
        ]),
      );

      await controller.addSource(
        'other',
        GeojsonSourceProperties(data: _collection([line])),
      );
      expect(_withoutKeptIds(map.data('other')), _collection([plain]));
    });

    test('a value jsonEncode cannot write fails as on Android and '
        'iOS', () async {
      for (final value in [DateTime(2020), double.nan]) {
        final feature = {
          'type': 'Feature',
          'geometry': null,
          'properties': {'value': value},
        };
        await expectLater(
          controller.addGeoJsonSource('points', feature),
          throwsA(isA<JsonUnsupportedObjectError>()),
          reason: '$value',
        );
        await expectLater(
          controller.addSource(
            'points',
            GeojsonSourceProperties(data: feature),
          ),
          throwsA(isA<JsonUnsupportedObjectError>()),
          reason: '$value',
        );
      }
      expect(map.sources, isEmpty);
    });
  });

  group('removeSource', () {
    test('keeps a source a layer still uses, with the data '
        'setGeoJsonFeature changes', () async {
      await controller.addGeoJsonSource('points', _collection([_point(1, 1)]));
      await controller.addCircleLayer(
        'points',
        'circles',
        const {},
        enableInteraction: false,
      );

      await controller.removeSource('points');

      expect(map.sources, contains('points'));
      await controller.setFeatureForGeoJsonSource('points', _point(1, 5));
      expect(map.data('points'), _collection([_point(1, 5)]));

      await controller.removeLayer('circles');
      await controller.removeSource('points');
      expect(map.sources, isNot(contains('points')));
    });
  });

  group('image sources from bytes', () {
    test('load from an object URL that is revoked once the source no longer '
        'shows it', () async {
      await controller.addImageSource('image', _png(1), _quad);
      final first = map.url('image')!;
      expect(first, startsWith('blob:'));
      expect(await _isLive(first), isTrue);
      expect(await controller.getSourceProperties('image'), {
        'type': 'image',
        'coordinates': [
          [-2, 2],
          [2, 2],
          [2, -2],
          [-2, -2],
        ],
      });

      await controller.updateImageSource('image', _png(2), null);
      final second = map.url('image')!;
      expect(second, isNot(first));
      expect(await _isLive(first), isFalse);
      expect(await _isLive(second), isTrue);

      await controller.removeSource('image');
      expect(await _isLive(second), isFalse);

      // The id can show bytes again.
      await controller.addImageSource('image', _png(1), _quad);
      final third = map.url('image')!;
      expect(await _isLive(third), isTrue);

      await controller.setStyle('{"version": 8, "sources": {}, "layers": []}');
      expect(await _isLive(third), isFalse);
    });

    test('bytes that are not an image fail with INVALID_IMAGE', () async {
      await expectLater(
        controller.addImageSource('image', Uint8List(4), _quad),
        throwsA(platformError('INVALID_IMAGE')),
      );
      expect(map.sources, isEmpty);
    });
  });

  group('layer adds', () {
    setUp(() async {
      await controller.addSource(
        'tiles',
        const VectorSourceProperties(tiles: ['https://example.com/{z}']),
      );
      await controller.addGeoJsonSource('points', _collection([]));
    });

    test('a layer on a vector source needs a source layer', () async {
      for (final sourceLayer in [null, '']) {
        await expectLater(
          controller.addFillLayer(
            'tiles',
            'fills',
            const {},
            sourceLayer: sourceLayer,
            enableInteraction: true,
          ),
          throwsA(
            platformError('SOURCE_LAYER_REQUIRED').having(
              (e) => e.message,
              'message',
              "Source 'tiles' is a vector source, so layer 'fills' requires "
                  "a 'sourceLayer'.",
            ),
          ),
          reason: '$sourceLayer',
        );
      }
      expect(map.layers, isEmpty);
      expect(map.layerListeners, isEmpty);

      await controller.addFillLayer(
        'tiles',
        'fills',
        const {},
        sourceLayer: 'water',
        enableInteraction: false,
      );
      expect(map.layers.keys, ['fills']);
    });

    test('a zoom outside 0 to 24 fails with INVALID_ARGUMENT', () async {
      final calls = <String, Future<void> Function()>{
        'circles':
            () => controller.addCircleLayer(
              'points',
              'circles',
              const {},
              minzoom: 25,
              enableInteraction: true,
            ),
        'lines':
            () => controller.addLineLayer(
              'points',
              'lines',
              const {},
              maxzoom: -1,
              enableInteraction: false,
            ),
        'background':
            () => controller.addBackgroundLayer(
              'background',
              const {},
              minzoom: double.nan,
            ),
      };
      for (final MapEntry(key: layerId, value: call) in calls.entries) {
        await expectLater(
          call(),
          throwsA(
            platformError('INVALID_ARGUMENT').having(
              (e) => e.message,
              'message',
              "The minzoom and maxzoom of layer '$layerId' must be within 0 "
                  'and 24.',
            ),
          ),
          reason: layerId,
        );
      }
      expect(map.layers, isEmpty);
      expect(map.layerListeners, isEmpty);
    });

    test('a layer maplibre-gl-js does not add fails with INVALID_LAYER and '
        'gets no listeners', () async {
      map.rejectLayer = 'layers.circles: Something is wrong.';

      await expectLater(
        controller.addCircleLayer(
          'points',
          'circles',
          const {},
          enableInteraction: true,
        ),
        throwsA(
          platformError('INVALID_LAYER').having(
            (e) => e.message,
            'message',
            "Layer 'circles' was not added: layers.circles: Something is "
                'wrong.',
          ),
        ),
      );
      expect(map.layerListeners, isEmpty);

      map.rejectLayer = null;
      await controller.addCircleLayer(
        'points',
        'circles',
        const {},
        enableInteraction: true,
      );
      expect(map.layerListeners, contains('mouseenter circles'));
    });
  });

  group('GeoJSON source calls on a source of another type', () {
    test('fail with UNSUPPORTED_SOURCE_TYPE, and a missing source with '
        'SOURCE_NOT_FOUND', () async {
      await controller.addSource(
        'tiles',
        const VectorSourceProperties(tiles: ['https://example.com/{z}']),
      );
      final calls = <String, Future<void> Function(String)>{
        'setGeoJsonSource':
            (id) => controller.setGeoJsonSource(id, _collection([])),
        'setGeoJsonFeature':
            (id) => controller.setFeatureForGeoJsonSource(id, _point(1, 1)),
      };
      for (final MapEntry(key: method, value: call) in calls.entries) {
        await expectLater(
          call('tiles'),
          throwsA(
            platformError('UNSUPPORTED_SOURCE_TYPE').having(
              (e) => e.message,
              'message',
              "Source 'tiles' is not a GeoJSON source. $method only applies "
                  'to GeoJSON sources.',
            ),
          ),
        );
        await expectLater(
          call('missing'),
          throwsA(platformError('SOURCE_NOT_FOUND')),
        );
      }
    });
  });

  group('addSource', () {
    test('fails with INVALID_ARGUMENT for a source MapLibre Native cannot '
        'build', () async {
      const tiles = ['https://example.com/{z}/{x}/{y}.pbf'];
      final sources = <String, SourceProperties>{
        'inverted bounds': const VectorSourceProperties(
          tiles: tiles,
          bounds: [-10, 20, 10, 10],
        ),
        'minzoom above maxzoom': const RasterSourceProperties(
          tiles: tiles,
          minzoom: 10,
          maxzoom: 5,
        ),
        'an empty url and no tiles': const VectorSourceProperties(url: ''),
        'a data url with spaces': const GeojsonSourceProperties(
          data: 'not a url',
        ),
      };
      for (final MapEntry(key: label, value: source) in sources.entries) {
        await expectLater(
          controller.addSource('broken', source),
          throwsA(
            platformError('INVALID_ARGUMENT').having(
              (e) => e.message,
              'message',
              "Source 'broken' cannot be built from its properties as a "
                  "'${source.toJson()['type']}' source.",
            ),
          ),
          reason: label,
        );
      }
      expect(map.sources, isEmpty);

      await controller.addSource(
        'clamped',
        const VectorSourceProperties(
          tiles: tiles,
          bounds: [-180, -95, 180, 95],
        ),
      );
      expect(map.sources.keys, ['clamped']);
    });
  });

  group('hex colors', () {
    setUp(() async {
      await controller.addGeoJsonSource('points', _collection([]));
    });

    test('with digits that are not hex fail a layer add and change '
        'nothing', () async {
      await expectLater(
        controller.addCircleLayer(
          'points',
          'circles',
          const {'circle-color': '#ggg', 'circle-radius': 4},
          enableInteraction: true,
        ),
        throwsA(
          platformError('INVALID_ARGUMENT').having(
            (e) => e.message,
            'message',
            "Invalid value for property 'circle-color' of layer 'circles': "
                "Could not parse color from value '#ggg'.",
          ),
        ),
      );
      expect(map.layers, isEmpty);
      expect(map.layerListeners, isEmpty);
    });

    test('with digits that are not hex fail setLayerProperties and change '
        'nothing', () async {
      await controller.addCircleLayer(
        'points',
        'circles',
        const {'circle-color': '#f008'},
        enableInteraction: false,
      );
      await controller
          .setLayerProperties('circles', const {
            'circle-blur': 1,
            'circle-color': '#ff00zz',
          })
          .then<void>(
            (_) => fail('setLayerProperties succeeded'),
            onError: (Object error) {
              expect(
                error,
                platformError('INVALID_ARGUMENT').having(
                  (e) => e.message,
                  'message',
                  "Invalid value for property 'circle-color' of layer "
                      "'circles': Could not parse color from value '#ff00zz'.",
                ),
              );
            },
          );
      expect(
        dartify(map.properties['circles Paint']!['circle-blur']),
        isNull,
        reason: 'the property set before it is put back',
      );
    });
  });

  group('values that are not finite', () {
    const nan = double.nan;

    test('fail the camera calls with INVALID_ARGUMENT', () async {
      final calls = <String, (String, Future<Object?> Function())>{
        'moveCamera newLatLng': (
          'Latitude and longitude must be finite numbers.',
          () => controller.moveCamera(
            CameraUpdate.newLatLng(const LatLng(nan, 0)),
          ),
        ),
        'animateCamera zoomTo': (
          'Zoom, bearing, tilt, offsets and padding must be finite numbers.',
          () => controller.animateCamera(CameraUpdate.zoomTo(nan)),
        ),
        'easeCamera zoomBy focus': (
          'Zoom, bearing, tilt, offsets and padding must be finite numbers.',
          () => controller.easeCamera(
            CameraUpdate.zoomBy(1, const Offset(nan, 0)),
          ),
        ),
        'toScreenLocation': (
          'Latitude and longitude must be finite numbers.',
          () => controller.toScreenLocation(const LatLng(0, double.infinity)),
        ),
        'toScreenLocationBatch': (
          'Latitude and longitude must be finite numbers.',
          () => controller.toScreenLocationBatch(const [
            LatLng(1, 1),
            LatLng(nan, 0),
          ]),
        ),
        'toLatLng': (
          'Screen coordinates must be finite numbers.',
          () => controller.toLatLng(const Point(nan, 10)),
        ),
        'setCameraBounds NaN': (
          'Latitude and longitude must be finite numbers.',
          () => controller.setCameraBounds(
            west: nan,
            north: 10,
            south: -10,
            east: 10,
            padding: 0,
          ),
        ),
        'setCameraBounds latitude': (
          'Latitude must be within -90 and 90.',
          () => controller.setCameraBounds(
            west: -10,
            north: 95,
            south: -10,
            east: 10,
            padding: 0,
          ),
        ),
        'setCameraBounds padding': (
          'Padding 4294967296 does not fit in 32 bits.',
          () => controller.setCameraBounds(
            west: -10,
            north: 10,
            south: -10,
            east: 10,
            padding: 4294967296,
          ),
        ),
      };
      for (final MapEntry(key: label, value: (message, call))
          in calls.entries) {
        await expectLater(
          call(),
          throwsA(
            platformError(
              'INVALID_ARGUMENT',
            ).having((e) => e.message, 'message', message),
          ),
          reason: label,
        );
      }
    });

    test('fail the image source calls before they change anything', () async {
      const nanQuad = LatLngQuad(
        topLeft: LatLng(2, -2),
        topRight: LatLng(2, nan),
        bottomRight: LatLng(-2, 2),
        bottomLeft: LatLng(-2, -2),
      );
      final nonFinite = platformError('INVALID_ARGUMENT').having(
        (e) => e.message,
        'message',
        'Latitude and longitude must be finite numbers.',
      );

      await expectLater(
        controller.addImageSource('image', _png(1), nanQuad),
        throwsA(nonFinite),
      );
      expect(map.sources, isEmpty);

      await controller.addImageSource('image', _png(1), _quad);
      final url = map.url('image');
      await expectLater(
        controller.updateImageSource('image', _png(2), nanQuad),
        throwsA(nonFinite),
      );
      expect(map.url('image'), url);
    });
  });

  group('takeSnapshot', () {
    test('a newer call answers the one still running with '
        'SNAPSHOT_ERROR', () async {
      final first = controller.takeSnapshot();
      final second = controller.takeSnapshot();

      await expectLater(
        first,
        throwsA(
          platformError('SNAPSHOT_ERROR').having(
            (e) => e.message,
            'message',
            'A newer takeSnapshot call cancelled this one.',
          ),
        ),
      );
      map.fireOnce('render');
      expect(await second, isNotEmpty);
    });

    test('dispose answers the call still running with MAP_DISPOSED', () async {
      final snapshot = controller.takeSnapshot();
      controller.dispose();

      await expectLater(
        snapshot,
        throwsA(
          platformError('MAP_DISPOSED').having(
            (e) => e.message,
            'message',
            'The map was disposed before the snapshot was ready.',
          ),
        ),
      );
    });
  });
}

/// [data] without the copy of each feature id that keeps ids on web.
Object? _withoutKeptIds(Object? data) {
  if (data is! Map) return data;
  final features = data['features'];
  if (features is! List) return data;
  return {
    ...data,
    'features': [
      for (final feature in features)
        if (feature is Map && feature['properties'] is Map)
          {
            ...feature,
            'properties': {...feature['properties'] as Map}
              ..remove(featureIdProperty),
          }
        else
          feature,
    ],
  };
}
