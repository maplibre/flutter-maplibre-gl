import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('LatLng', () {
    test('basic construction', () {
      const latLng = LatLng(45.0, 90.0);
      expect(latLng.latitude, 45.0);
      expect(latLng.longitude, 90.0);
    });

    test('clamps latitude to [-90, 90]', () {
      const tooHigh = LatLng(100.0, 0.0);
      expect(tooHigh.latitude, 90.0);

      const tooLow = LatLng(-100.0, 0.0);
      expect(tooLow.latitude, -90.0);
    });

    test('latitude at exact boundaries', () {
      const atMax = LatLng(90.0, 0.0);
      expect(atMax.latitude, 90.0);

      const atMin = LatLng(-90.0, 0.0);
      expect(atMin.latitude, -90.0);
    });

    test('normalizes longitude to [-180, 180)', () {
      const wrapped = LatLng(0.0, 200.0);
      expect(wrapped.longitude, closeTo(-160.0, 1e-10));

      const wrappedNeg = LatLng(0.0, -200.0);
      expect(wrappedNeg.longitude, closeTo(160.0, 1e-10));
    });

    test('longitude at boundaries', () {
      const atMin = LatLng(0.0, -180.0);
      expect(atMin.longitude, -180.0);

      // 180.0 wraps to -180.0
      const atMax = LatLng(0.0, 180.0);
      expect(atMax.longitude, -180.0);
    });

    test('longitude wrapping beyond 360', () {
      const wrapped = LatLng(0.0, 540.0);
      expect(wrapped.longitude, -180.0);
    });

    test('toJson produces [lat, lng]', () {
      const latLng = LatLng(10.0, 20.0);
      final json = latLng.toJson() as List<double>;
      expect(json, [10.0, 20.0]);
    });

    test('toGeoJsonCoordinates produces [lng, lat] (reversed order)', () {
      const latLng = LatLng(10.0, 20.0);
      final coords = latLng.toGeoJsonCoordinates() as List<double>;
      expect(coords, [20.0, 10.0]);
    });

    test('operator + adds coordinates', () {
      const a = LatLng(10.0, 20.0);
      const b = LatLng(5.0, 10.0);
      final result = a + b;
      expect(result.latitude, 15.0);
      expect(result.longitude, 30.0);
    });

    test('operator - subtracts coordinates', () {
      const a = LatLng(10.0, 20.0);
      const b = LatLng(5.0, 10.0);
      final result = a - b;
      expect(result.latitude, 5.0);
      expect(result.longitude, 10.0);
    });

    test('operator + clamps and normalizes result', () {
      const a = LatLng(80.0, 170.0);
      const b = LatLng(20.0, 20.0);
      final result = a + b;
      expect(result.latitude, 90.0); // clamped
      expect(result.longitude, closeTo(-170.0, 1e-10)); // normalized
    });

    test('equality', () {
      const a = LatLng(45.0, 90.0);
      const b = LatLng(45.0, 90.0);
      const c = LatLng(45.0, 91.0);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('hashCode consistency', () {
      const a = LatLng(45.0, 90.0);
      const b = LatLng(45.0, 90.0);
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      const latLng = LatLng(45.0, 90.0);
      // On web (JS), integer doubles print without ".0" suffix
      expect(latLng.toString(), matches(RegExp(r'LatLng\(45\.?0?, 90\.?0?\)')));
    });
  });

  group('LatLngBounds', () {
    test('basic construction', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      expect(bounds.southwest, const LatLng(10.0, 20.0));
      expect(bounds.northeast, const LatLng(30.0, 40.0));
    });

    test('asserts southwest.lat <= northeast.lat', () {
      expect(
        () => LatLngBounds(
          southwest: const LatLng(50.0, 0.0),
          northeast: const LatLng(10.0, 0.0),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toList produces [[sw.lat, sw.lng], [ne.lat, ne.lng]]', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final list = bounds.toList() as List;
      expect(list[0], [10.0, 20.0]);
      expect(list[1], [30.0, 40.0]);
    });

    test('fromList roundtrip', () {
      final original = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final restored = LatLngBounds.fromList(original.toList());
      expect(restored, original);
    });

    test('fromList with null returns null', () {
      expect(LatLngBounds.fromList(null), isNull);
    });

    test('contains returns true for point inside', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      expect(bounds.contains(const LatLng(20.0, 30.0)), isTrue);
    });

    test('contains returns true for point on boundary', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      expect(bounds.contains(const LatLng(10.0, 20.0)), isTrue);
      expect(bounds.contains(const LatLng(30.0, 40.0)), isTrue);
    });

    test('contains returns false for point outside', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      expect(bounds.contains(const LatLng(5.0, 30.0)), isFalse);
      expect(bounds.contains(const LatLng(20.0, 50.0)), isFalse);
    });

    test('contains handles longitude wrap-around', () {
      // Bounds that cross the antimeridian: sw.lng > ne.lng
      final bounds = LatLngBounds(
        southwest: const LatLng(-10.0, 170.0),
        northeast: const LatLng(10.0, -170.0),
      );
      // Point at 175 lng should be inside (between 170 and -170 wrapping)
      expect(bounds.contains(const LatLng(0.0, 175.0)), isTrue);
      // Point at -175 lng should be inside
      expect(bounds.contains(const LatLng(0.0, -175.0)), isTrue);
      // Point at 0 lng should be outside
      expect(bounds.contains(const LatLng(0.0, 0.0)), isFalse);
    });

    test('equality', () {
      final a = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final b = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      // On web (JS), integer doubles print without ".0" suffix
      expect(
        bounds.toString(),
        matches(
          RegExp(
            r'LatLngBounds\(LatLng\(10\.?0?, 20\.?0?\), LatLng\(30\.?0?, 40\.?0?\)\)',
          ),
        ),
      );
    });
  });

  group('LatLngQuad', () {
    const quad = LatLngQuad(
      topLeft: LatLng(40.0, -74.0),
      topRight: LatLng(40.0, -73.0),
      bottomRight: LatLng(39.0, -73.0),
      bottomLeft: LatLng(39.0, -74.0),
    );

    test('toList produces 4 coordinate pairs', () {
      final list = quad.toList() as List;
      expect(list.length, 4);
      expect(list[0], [40.0, -74.0]);
      expect(list[1], [40.0, -73.0]);
      expect(list[2], [39.0, -73.0]);
      expect(list[3], [39.0, -74.0]);
    });

    test('fromList roundtrip', () {
      final restored = LatLngQuad.fromList(quad.toList());
      expect(restored, quad);
    });

    test('fromList with null returns null', () {
      expect(LatLngQuad.fromList(null), isNull);
    });

    test('equality', () {
      const same = LatLngQuad(
        topLeft: LatLng(40.0, -74.0),
        topRight: LatLng(40.0, -73.0),
        bottomRight: LatLng(39.0, -73.0),
        bottomLeft: LatLng(39.0, -74.0),
      );
      expect(quad, equals(same));
      expect(quad.hashCode, same.hashCode);
    });

    test('inequality when one corner differs', () {
      const different = LatLngQuad(
        topLeft: LatLng(41.0, -74.0),
        topRight: LatLng(40.0, -73.0),
        bottomRight: LatLng(39.0, -73.0),
        bottomLeft: LatLng(39.0, -74.0),
      );
      expect(quad, isNot(equals(different)));
    });

    test('toString', () {
      expect(quad.toString(), contains('LatLngQuad'));
    });
  });

  group('UserLocation', () {
    test('basic construction', () {
      final timestamp = DateTime(2024);
      final location = UserLocation(
        position: const LatLng(45.0, 90.0),
        altitude: 100.0,
        bearing: 180.0,
        speed: 5.0,
        horizontalAccuracy: 10.0,
        verticalAccuracy: 15.0,
        timestamp: timestamp,
        heading: null,
      );
      expect(location.position, const LatLng(45.0, 90.0));
      expect(location.altitude, 100.0);
      expect(location.bearing, 180.0);
      expect(location.speed, 5.0);
      expect(location.horizontalAccuracy, 10.0);
      expect(location.verticalAccuracy, 15.0);
      expect(location.timestamp, timestamp);
      expect(location.heading, isNull);
    });

    test('with nullable fields as null', () {
      final location = UserLocation(
        position: const LatLng(0.0, 0.0),
        altitude: null,
        bearing: null,
        speed: null,
        horizontalAccuracy: null,
        verticalAccuracy: null,
        timestamp: DateTime(2024),
        heading: null,
      );
      expect(location.altitude, isNull);
      expect(location.bearing, isNull);
      expect(location.speed, isNull);
    });
  });

  group('UserHeading', () {
    test('basic construction', () {
      final timestamp = DateTime(2024);
      final heading = UserHeading(
        magneticHeading: 90.0,
        trueHeading: 92.0,
        headingAccuracy: 5.0,
        x: 1.0,
        y: 2.0,
        z: 3.0,
        timestamp: timestamp,
      );
      expect(heading.magneticHeading, 90.0);
      expect(heading.trueHeading, 92.0);
      expect(heading.headingAccuracy, 5.0);
      expect(heading.x, 1.0);
      expect(heading.y, 2.0);
      expect(heading.z, 3.0);
      expect(heading.timestamp, timestamp);
    });
  });
}
