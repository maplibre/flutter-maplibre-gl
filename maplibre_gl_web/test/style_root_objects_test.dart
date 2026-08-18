// Drives the style root object setters against a stand-in for maplibre-gl-js,
// so it needs a browser, but never the library itself:
// `flutter test --platform chrome`.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/maplibre_gl_web.dart';
import 'package:maplibre_gl_web/src/interop/ui/map_interop.dart';
import 'package:maplibre_gl_web/src/ui/map.dart';
import 'package:maplibre_gl_web/src/utils.dart';

/// Web is the platform these five calls run on: four of them do nothing
/// anywhere else. Each is a name and a payload handed straight to
/// maplibre-gl-js, so a key spelled the way Dart spells it, or a value not
/// wrapped the way the library expects, is a silent no-op on a live map and
/// nothing in Dart can tell. What crosses into JS is asserted here.
void main() {
  /// A map that keeps what each style root object setter was handed, under the
  /// name of the value, and answers with itself as maplibre-gl-js does.
  JSObject recordingMap() {
    final map = JSObject();
    void record(String name, JSAny? value) => map.setProperty(name.toJS, value);

    map.setProperty(
      'setSky'.toJS,
      ((JSAny? sky, JSAny? options) {
        record('sky', sky);
        return map;
      }).toJS,
    );
    map.setProperty(
      'setTerrain'.toJS,
      ((JSAny? terrain) {
        record('terrain', terrain);
        return map;
      }).toJS,
    );
    map.setProperty(
      'setProjection'.toJS,
      ((JSAny? projection) {
        record('projection', projection);
        return map;
      }).toJS,
    );
    map.setProperty(
      'setLight'.toJS,
      ((JSAny? light, JSAny? options) {
        record('light', light);
        return map;
      }).toJS,
    );
    map.setProperty(
      'setGlobalStateProperty'.toJS,
      ((JSAny? name, JSAny? value) {
        record('globalStateName', name);
        record('globalStateValue', value);
        return map;
      }).toJS,
    );
    return map;
  }

  /// A controller driving [map] instead of a real one.
  MapLibreMapController controllerFor(JSObject map) =>
      MapLibreMapController()
        ..debugSetMap(MapLibreMap.fromJsObject(map as MapLibreMapJsImpl));

  /// What [map] was handed as [name], back in Dart.
  dynamic recorded(JSObject map, String name) =>
      dartify(map.getProperty<JSAny?>(name.toJS));

  group('the style root objects on web', () {
    test('setSky hands over the sky as the spec names it', () async {
      final map = recordingMap();

      await controllerFor(map).setSky(
        const SkyProperties(skyColor: '#199EF3', atmosphereBlend: 0.4),
      );

      expect(recorded(map, 'sky'), {
        'sky-color': '#199EF3',
        'atmosphere-blend': 0.4,
      });
    });

    test('setTerrain hands over the terrain, and null to remove it', () async {
      final map = recordingMap();
      final controller = controllerFor(map);

      await controller.setTerrain(
        const TerrainProperties(source: 'terrain-dem', exaggeration: 1.5),
      );
      expect(recorded(map, 'terrain'), {
        'source': 'terrain-dem',
        'exaggeration': 1.5,
      });

      await controller.setTerrain(null);
      expect(
        map.getProperty<JSAny?>('terrain'.toJS),
        isNull,
        reason: 'only null flattens the map; an empty object is a terrain',
      );
    });

    test('setProjection wraps the type in a projection object', () async {
      final map = recordingMap();

      await controllerFor(map).setProjection('globe');

      expect(recorded(map, 'projection'), {'type': 'globe'});
    });

    test('setLight hands over the light as the spec names it', () async {
      final map = recordingMap();

      await controllerFor(map).setLight(
        const LightProperties(
          anchor: 'map',
          position: [1.5, 90, 80],
          color: '#ffffff',
          intensity: 0.4,
        ),
      );

      expect(recorded(map, 'light'), {
        'anchor': 'map',
        'position': [1.5, 90, 80],
        'color': '#ffffff',
        'intensity': 0.4,
      });
    });

    test('setGlobalStateProperty hands over the name and the value', () async {
      final map = recordingMap();

      await controllerFor(map).setGlobalStateProperty('showLabels', false);

      expect(recorded(map, 'globalStateName'), 'showLabels');
      expect(recorded(map, 'globalStateValue'), isFalse);
    });
  });
}
