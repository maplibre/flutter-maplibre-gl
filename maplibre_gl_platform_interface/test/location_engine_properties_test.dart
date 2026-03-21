import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('LocationEnginePlatforms', () {
    test('default values are all null except enableHighAccuracy', () {
      const props = LocationEnginePlatforms.defaultPlatform;
      expect(props.enableHighAccuracy, false);
      expect(props.interval, isNull);
      expect(props.displacement, isNull);
      expect(props.priority, isNull);
      expect(props.maximumAge, isNull);
      expect(props.timeout, isNull);
    });

    test('resolvedPriority defaults based on enableHighAccuracy', () {
      const low = LocationEnginePlatforms.android();
      expect(low.resolvedPriority, LocationPriority.balanced);

      const high = LocationEnginePlatforms.android(enableHighAccuracy: true);
      expect(high.resolvedPriority, LocationPriority.highAccuracy);
    });

    test('explicit priority overrides enableHighAccuracy', () {
      const props = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        priority: LocationPriority.lowPower,
      );
      expect(props.resolvedPriority, LocationPriority.lowPower);
    });

    test('toList() returns a list', () {
      expect(LocationEnginePlatforms.defaultPlatform.toList(), isList);
    });

    test('equality within same constructor', () {
      const a = LocationEnginePlatforms.android();
      const b = LocationEnginePlatforms.android();
      const c = LocationEnginePlatforms.android(enableHighAccuracy: true);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('different constructors with different null fields are not equal', () {
      const android = LocationEnginePlatforms.android();
      const web = LocationEnginePlatforms.web();
      const ios = LocationEnginePlatforms.iOS();
      // Each has different nullable fields set
      expect(android, isNot(equals(web)));
      expect(android, isNot(equals(ios)));
      expect(web, isNot(equals(ios)));
    });

    test('equality differs on each android field', () {
      const base = LocationEnginePlatforms.android();
      const diffAccuracy = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
      );
      const diffInterval = LocationEnginePlatforms.android(interval: 500);
      const diffDisplacement = LocationEnginePlatforms.android(
        displacement: 10,
      );
      const diffPriority = LocationEnginePlatforms.android(
        priority: LocationPriority.noPower,
      );

      expect(base, isNot(equals(diffAccuracy)));
      expect(base, isNot(equals(diffInterval)));
      expect(base, isNot(equals(diffDisplacement)));
      expect(base, isNot(equals(diffPriority)));
    });

    test('equality differs on each web field', () {
      const base = LocationEnginePlatforms.web();
      const diffMaxAge = LocationEnginePlatforms.web(maximumAge: 5000);
      const diffTimeout = LocationEnginePlatforms.web(timeout: 10000);

      expect(base, isNot(equals(diffMaxAge)));
      expect(base, isNot(equals(diffTimeout)));
    });

    test('toString contains all fields', () {
      const props = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        interval: 500,
        displacement: 10,
      );
      final str = props.toString();
      expect(str, contains('enableHighAccuracy: true'));
      expect(str, contains('interval: 500'));
      expect(str, contains('displacement: 10'));
    });
  });

  group('Platform-specific constructors', () {
    test('android constructor only sets android-relevant fields', () {
      const props = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        interval: 500,
        displacement: 10,
        priority: LocationPriority.highAccuracy,
      );
      expect(props.enableHighAccuracy, true);
      expect(props.interval, 500);
      expect(props.displacement, 10);
      expect(props.priority, LocationPriority.highAccuracy);
      // Web fields are null
      expect(props.maximumAge, isNull);
      expect(props.timeout, isNull);
    });

    test('iOS constructor only sets iOS-relevant fields', () {
      const props = LocationEnginePlatforms.iOS(
        enableHighAccuracy: true,
        displacement: 25,
      );
      expect(props.enableHighAccuracy, true);
      expect(props.displacement, 25);
      // Android/web fields are null
      expect(props.interval, isNull);
      expect(props.priority, isNull);
      expect(props.maximumAge, isNull);
      expect(props.timeout, isNull);
    });

    test('web constructor only sets web-relevant fields', () {
      const props = LocationEnginePlatforms.web(
        enableHighAccuracy: true,
        maximumAge: 3000,
        timeout: 5000,
      );
      expect(props.enableHighAccuracy, true);
      expect(props.maximumAge, 3000);
      expect(props.timeout, 5000);
      // Android/iOS fields are null
      expect(props.interval, isNull);
      expect(props.displacement, isNull);
      expect(props.priority, isNull);
    });

    test('platform constructors with defaults', () {
      const android = LocationEnginePlatforms.android();
      const ios = LocationEnginePlatforms.iOS();
      const web = LocationEnginePlatforms.web();

      // All default to no high accuracy
      expect(android.enableHighAccuracy, false);
      expect(ios.enableHighAccuracy, false);
      expect(web.enableHighAccuracy, false);
    });
  });

  group('Android serialization', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test(
      'default toList() returns [interval, priority.index, displacement]',
      () {
        const props = LocationEnginePlatforms.android();
        expect(props.toList(), [1000, LocationPriority.balanced.index, 0]);
      },
    );

    test('high accuracy maps to priority index 0', () {
      const props = LocationEnginePlatforms.android(enableHighAccuracy: true);
      final list = props.toList();
      expect(list[1], LocationPriority.highAccuracy.index);
    });

    test('explicit priority overrides enableHighAccuracy in serialization', () {
      const props = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        priority: LocationPriority.lowPower,
      );
      final list = props.toList();
      expect(list[1], LocationPriority.lowPower.index);
    });

    test('custom values serialize correctly', () {
      const props = LocationEnginePlatforms.android(
        enableHighAccuracy: true,
        interval: 500,
        displacement: 10,
      );
      expect(props.toList(), [500, LocationPriority.highAccuracy.index, 10]);
    });

    test('all priority values serialize correctly', () {
      for (final priority in LocationPriority.values) {
        final props = LocationEnginePlatforms.android(priority: priority);
        expect(props.toList()[1], priority.index);
      }
    });

    test('web-only fields are ignored in serialization', () {
      const props = LocationEnginePlatforms.web(
        maximumAge: 3000,
        timeout: 5000,
      );
      // Only interval, priority, displacement (all defaults)
      expect(props.toList(), [1000, LocationPriority.balanced.index, 0]);
    });
  });

  group('iOS serialization', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('default toList() returns [0, 0]', () {
      const props = LocationEnginePlatforms.iOS();
      expect(props.toList(), [0, 0]);
    });

    test('high accuracy serializes as 1', () {
      const props = LocationEnginePlatforms.iOS(enableHighAccuracy: true);
      expect(props.toList(), [1, 0]);
    });

    test('displacement maps to distanceFilter', () {
      const props = LocationEnginePlatforms.iOS(displacement: 50);
      expect(props.toList(), [0, 50]);
    });

    test('combined high accuracy and displacement', () {
      const props = LocationEnginePlatforms.iOS(
        enableHighAccuracy: true,
        displacement: 25,
      );
      expect(props.toList(), [1, 25]);
    });

    test('android-only and web-only fields are ignored', () {
      const props = LocationEnginePlatforms.android(
        interval: 500,
        priority: LocationPriority.noPower,
      );
      // iOS only serializes enableHighAccuracy and displacement
      expect(props.toList(), [0, 0]);
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
