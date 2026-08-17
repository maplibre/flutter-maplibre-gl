import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

// The style root objects are handed to the renderer as-is, and the style spec
// spells every key in kebab-case. A misspelled key is not rejected, it is
// ignored, so a wrong name here is a silent no-op at runtime rather than an
// error. The same goes for a null value, which the style validator refuses.
// That is what these tests pin down; each field gets a distinct value so a
// swapped key does not pass unnoticed.
void main() {
  group('SkyProperties', () {
    test('toJson uses the style-spec key names', () {
      const props = SkyProperties(
        skyColor: '#88C6FC',
        horizonColor: '#ffffff',
        fogColor: '#dddddd',
        fogGroundBlend: 0.1,
        horizonFogBlend: 0.2,
        skyHorizonBlend: 0.3,
        atmosphereBlend: [
          'interpolate',
          ['linear'],
          ['zoom'],
          0,
          1,
          5,
          0,
        ],
      );

      expect(props.toJson(), {
        'sky-color': '#88C6FC',
        'horizon-color': '#ffffff',
        'fog-color': '#dddddd',
        'fog-ground-blend': 0.1,
        'horizon-fog-blend': 0.2,
        'sky-horizon-blend': 0.3,
        'atmosphere-blend': [
          'interpolate',
          ['linear'],
          ['zoom'],
          0,
          1,
          5,
          0,
        ],
      });
    });

    test('toJson omits the unset properties', () {
      const props = SkyProperties(skyColor: '#88C6FC');

      expect(props.toJson(), {'sky-color': '#88C6FC'});
    });
  });

  group('TerrainProperties', () {
    test('toJson keeps the source and the exaggeration', () {
      const props = TerrainProperties(source: 'dem', exaggeration: 1.5);

      expect(props.toJson(), {'source': 'dem', 'exaggeration': 1.5});
    });

    test('toJson omits a null exaggeration so the style default applies', () {
      const props = TerrainProperties(source: 'dem');

      expect(props.toJson(), {'source': 'dem'});
    });
  });

  // The light key names are already pinned down by the setLight test in
  // method_channel_layer_test.dart. What is left is the omission, which
  // matters more here than for the web-only objects: light reaches the
  // Android and iOS codecs too.
  group('LightProperties', () {
    test('toJson omits the unset properties', () {
      const props = LightProperties(intensity: 0.4);

      expect(props.toJson(), {'intensity': 0.4});
    });
  });
}
