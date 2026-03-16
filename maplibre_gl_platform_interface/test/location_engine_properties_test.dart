import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('LocationEngineAndroidProperties', () {
    test('default values', () {
      const props = LocationEngineAndroidProperties.defaultProperties;
      expect(props.interval, 1000);
      expect(props.displacement, 0);
      expect(props.priority, LocationPriority.balanced);
    });

    test('toList produces [interval, priority.index, displacement]', () {
      const props = LocationEngineAndroidProperties.defaultProperties;
      final list = props.toList();
      expect(list, [1000, LocationPriority.balanced.index, 0]);
    });

    test('toList with custom values', () {
      const props = LocationEngineAndroidProperties(
        interval: 500,
        displacement: 10,
        priority: LocationPriority.highAccuracy,
      );
      final list = props.toList();
      expect(list, [500, LocationPriority.highAccuracy.index, 10]);
    });

    test('copyWith replaces specified fields', () {
      const original = LocationEngineAndroidProperties.defaultProperties;
      final updated = original.copyWith(interval: 2000);
      expect(updated.interval, 2000);
      expect(updated.displacement, 0); // preserved
      expect(updated.priority, LocationPriority.balanced); // preserved
    });

    test('copyWith with all fields', () {
      const original = LocationEngineAndroidProperties.defaultProperties;
      final updated = original.copyWith(
        interval: 500,
        displacement: 50,
        priority: LocationPriority.lowPower,
      );
      expect(updated.interval, 500);
      expect(updated.displacement, 50);
      expect(updated.priority, LocationPriority.lowPower);
    });

    test('equality', () {
      const a = LocationEngineAndroidProperties.defaultProperties;
      const b = LocationEngineAndroidProperties.defaultProperties;
      const c = LocationEngineAndroidProperties(
        interval: 500,
        displacement: 0,
        priority: LocationPriority.balanced,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString', () {
      const props = LocationEngineAndroidProperties.defaultProperties;
      expect(props.toString(), contains('LocationEngineAndroidProperties'));
      expect(props.toString(), contains('1000'));
    });
  });

  group('LocationEnginePlatforms', () {
    test('defaultPlatform.toList() works on all platforms', () {
      expect(LocationEnginePlatforms.defaultPlatform.toList(), isList);
    });

    test('default uses defaultProperties for android', () {
      const platforms = LocationEnginePlatforms.defaultPlatform;
      expect(
        platforms.androidPlatform,
        LocationEngineAndroidProperties.defaultProperties,
      );
    });

    test('custom android properties', () {
      const custom = LocationEnginePlatforms(
        androidPlatform: LocationEngineAndroidProperties(
          interval: 500,
          displacement: 10,
          priority: LocationPriority.highAccuracy,
        ),
      );
      expect(custom.androidPlatform.interval, 500);
      expect(custom.androidPlatform.displacement, 10);
    });
  });

  group('LocationPriority', () {
    test('enum values exist', () {
      expect(LocationPriority.values.length, 4);
      expect(LocationPriority.highAccuracy.index, 0);
      expect(LocationPriority.balanced.index, 1);
      expect(LocationPriority.lowPower.index, 2);
      expect(LocationPriority.noPower.index, 3);
    });
  });
}
