// The predicates below decide which properties reach the Java and Swift
// templates, so a wrong answer here means either native code that does not
// compile or a property that silently does nothing on a platform. They are the
// part of the generator worth locking down.
import 'package:maplibre_code_gen/generate.dart';
import 'package:test/test.dart';

void main() {
  group('compareVersions', () {
    test('orders by numeric component, not lexically', () {
      expect(compareVersions('13.4.1', '13.4.0'), isPositive);
      expect(compareVersions('9.2.0', '13.0.0'), isNegative);
      expect(compareVersions('6.28.0', '6.28.0'), isZero);
    });

    test('treats missing components as zero', () {
      expect(compareVersions('13', '13.0.0'), isZero);
      expect(compareVersions('13.4', '13.4.1'), isNegative);
    });
  });

  group('isImplemented', () {
    test('accepts a version', () {
      expect(isImplemented('13.0.0'), isTrue);
      expect(isImplemented('5'), isTrue);
    });

    test('rejects the values that stand for "not implemented"', () {
      expect(
        isImplemented('https://github.com/maplibre/maplibre-native/issues/251'),
        isFalse,
      );
      expect(isImplemented('wontfix'), isFalse);
      expect(isImplemented('supported'), isFalse);
      expect(isImplemented(null), isFalse);
    });
  });

  group('isSupportedOnPlatform', () {
    Map<String, dynamic> spec(Map<String, dynamic> basic) => {
      'sdk-support': {'basic functionality': basic},
    };

    test('supported when the pinned SDK is at or past the version', () {
      final property = spec({'android': '13.0.0', 'ios': '6.24.0'});
      expect(isSupportedOnPlatform(property, 'android', '13.4.1'), isTrue);
      expect(isSupportedOnPlatform(property, 'android', '13.0.0'), isTrue);
    });

    test('unsupported when the pinned SDK is older than the version', () {
      final property = spec({'android': '14.0.0'});
      expect(isSupportedOnPlatform(property, 'android', '13.4.1'), isFalse);
    });

    test('unsupported when the platform is missing or carries an issue', () {
      expect(
        isSupportedOnPlatform(spec({'js': '5.20.0'}), 'ios', '6.28.0'),
        isFalse,
      );
      final unimplemented = spec({
        'ios': 'https://github.com/maplibre/maplibre-native/issues/4117',
      });
      expect(isSupportedOnPlatform(unimplemented, 'ios', '6.28.0'), isFalse);
    });

    // Properties predating the metadata: assumed supported, and the native
    // build fails loudly if that assumption is ever wrong.
    test('supported when the property carries no sdk-support', () {
      expect(
        isSupportedOnPlatform(<String, dynamic>{}, 'android', '13.4.1'),
        isTrue,
      );
    });
  });

  group('buildSupportLines', () {
    test('names implemented and unimplemented platforms apart', () {
      final lines = buildSupportLines('basic functionality', {
        'basic functionality': {
          'js': '2.1.0',
          'android': 'https://github.com/maplibre/maplibre-native/issues/251',
          'ios': 'https://github.com/maplibre/maplibre-native/issues/251',
        },
      });
      expect(lines, [
        '  basic functionality with js (not on android, ios)',
      ]);
    });

    test('lists every platform when all of them implement it', () {
      final lines = buildSupportLines('data-driven styling', {
        'data-driven styling': {
          'js': '0.21.0',
          'android': '5.0.0',
          'ios': '3.5.0',
        },
      });
      expect(lines, ['  data-driven styling with js, android, ios']);
    });

    test('says so when no platform implements it', () {
      final lines = buildSupportLines('basic functionality', {
        'basic functionality': {'js': 'wontfix'},
      });
      expect(lines, ['  basic functionality on no platform yet']);
    });

    // The spec credits ios with `volatile` since 5.10.0, a Mapbox iOS version
    // the MapLibre iOS SDK never matched with an API, so the docs must move it
    // to the unimplemented side rather than promise silent caching.
    test('moves an overridden platform to the unimplemented side', () {
      final sdkSupport = {
        'basic functionality': {
          'android': '9.3.0',
          'ios': '5.10.0',
          'js': 'wontfix',
        },
      };
      expect(buildSupportLines('basic functionality', sdkSupport, 'volatile'), [
        '  basic functionality with android (not on ios, js)',
      ]);
      expect(buildSupportLines('basic functionality', sdkSupport), [
        '  basic functionality with android, ios (not on js)',
      ]);
    });

    // An entry shaped differently (the vector encoding lists mvt and mlt
    // instead) must not print an empty "Sdk Support:" header.
    test('returns nothing for an absent or empty entry', () {
      expect(buildSupportLines('basic functionality', null), isEmpty);
      expect(
        buildSupportLines('basic functionality', {
          'mvt': {'android': 'supported'},
        }),
        isEmpty,
      );
      expect(
        buildSupportLines('data-driven styling', {
          'data-driven styling': <String, dynamic>{},
        }),
        isEmpty,
      );
    });
  });

  group('buildStyleProperties', () {
    test('wraps array-typed paint properties by spec type', () {
      final properties = buildStyleProperties({
        'paint_hillshade': {
          'hillshade-shadow-color': {'type': 'colorArray', 'doc': 'shadow'},
          'hillshade-illumination-altitude': {
            'type': 'numberArray',
            'doc': 'altitude',
          },
          'hillshade-accent-color': {'type': 'color', 'doc': 'accent'},
        },
      }, 'paint_hillshade');

      expect(properties[0]['isColorArrayProperty'], isTrue);
      expect(properties[0]['iosExpression'], 'wrapColorAsArray(expression)');
      expect(properties[1]['isNumberArrayProperty'], isTrue);
      expect(properties[1]['iosExpression'], 'wrapValueAsArray(expression)');
      expect(properties[2]['isColorArrayProperty'], isFalse);
      expect(properties[2]['iosExpression'], 'expression');
    });

    // The layout branch of the native templates has no wrap, so an array-typed
    // layout property has to stop generation rather than be emitted unwrapped.
    test('refuses an array-typed layout property', () {
      expect(
        () => buildStyleProperties({
          'layout_hillshade': {
            'hillshade-something': {'type': 'numberArray', 'doc': 'x'},
          },
        }, 'layout_hillshade'),
        throwsA(isA<StateError>()),
      );
    });

    test('omits properties the pinned native SDK does not implement', () {
      final styleJson = {
        'paint_raster': {
          'raster-opacity': {
            'type': 'number',
            'doc': 'opacity',
            'sdk-support': {
              'basic functionality': {
                'js': '0.10.0',
                'android': '2.0.1',
                'ios': '2.0.0',
              },
            },
          },
          'resampling': {
            'type': 'enum',
            'doc': 'resampling',
            'sdk-support': {
              'basic functionality': {
                'js': '5.20.0',
                'android':
                    'https://github.com/maplibre/maplibre-native/issues/4117',
                'ios':
                    'https://github.com/maplibre/maplibre-native/issues/4117',
              },
            },
          },
        },
      };

      final all = buildStyleProperties(styleJson, 'paint_raster');
      expect(all.map((p) => p['value']), ['raster-opacity', 'resampling']);

      final android = buildStyleProperties(
        styleJson,
        'paint_raster',
        platform: 'android',
        platformVersion: '13.4.1',
      );
      expect(android.map((p) => p['value']), ['raster-opacity']);
    });
  });
}
