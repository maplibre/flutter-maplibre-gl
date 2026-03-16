import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

void main() {
  group('CameraPosition', () {
    test('basic construction with defaults', () {
      const camera = CameraPosition(target: LatLng(45.0, 90.0));
      expect(camera.bearing, 0.0);
      expect(camera.target, const LatLng(45.0, 90.0));
      expect(camera.tilt, 0.0);
      expect(camera.zoom, 0.0);
    });

    test('construction with all parameters', () {
      const camera = CameraPosition(
        bearing: 45.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      expect(camera.bearing, 45.0);
      expect(camera.target, const LatLng(10.0, 20.0));
      expect(camera.tilt, 30.0);
      expect(camera.zoom, 15.0);
    });

    test('toMap produces correct structure', () {
      const camera = CameraPosition(
        bearing: 45.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      final map = camera.toMap() as Map<String, dynamic>;
      expect(map['bearing'], 45.0);
      expect(map['target'], [10.0, 20.0]);
      expect(map['tilt'], 30.0);
      expect(map['zoom'], 15.0);
    });

    test('fromMap roundtrip', () {
      const original = CameraPosition(
        bearing: 45.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      final restored = CameraPosition.fromMap(original.toMap());
      expect(restored, original);
    });

    test('fromMap with null returns null', () {
      expect(CameraPosition.fromMap(null), isNull);
    });

    test('equality', () {
      const a = CameraPosition(
        bearing: 45.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      const b = CameraPosition(
        bearing: 45.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      const c = CameraPosition(
        bearing: 90.0,
        target: LatLng(10.0, 20.0),
        tilt: 30.0,
        zoom: 15.0,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString', () {
      const camera = CameraPosition(target: LatLng(10.0, 20.0), zoom: 5.0);
      expect(camera.toString(), contains('CameraPosition'));
      // Use regex to handle JS printing "10" vs VM printing "10.0"
      expect(camera.toString(), matches(RegExp(r'10\.?0?')));
    });
  });

  group('CameraUpdate', () {
    test('newCameraPosition', () {
      const camera = CameraPosition(
        target: LatLng(10.0, 20.0),
        zoom: 5.0,
      );
      final update = CameraUpdate.newCameraPosition(camera);
      final json = update.toJson() as List;
      expect(json[0], 'newCameraPosition');
      expect(json[1], isA<Map>());
    });

    test('newLatLng', () {
      final update = CameraUpdate.newLatLng(const LatLng(10.0, 20.0));
      final json = update.toJson() as List;
      expect(json[0], 'newLatLng');
      expect(json[1], [10.0, 20.0]);
    });

    test('newLatLngBounds', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final update = CameraUpdate.newLatLngBounds(
        bounds,
        left: 10,
        top: 20,
        right: 30,
        bottom: 40,
      );
      final json = update.toJson() as List;
      expect(json[0], 'newLatLngBounds');
      expect(json[2], 10.0); // left
      expect(json[3], 20.0); // top
      expect(json[4], 30.0); // right
      expect(json[5], 40.0); // bottom
    });

    test('newLatLngZoom', () {
      final update = CameraUpdate.newLatLngZoom(const LatLng(10.0, 20.0), 12.0);
      final json = update.toJson() as List;
      expect(json[0], 'newLatLngZoom');
      expect(json[1], [10.0, 20.0]);
      expect(json[2], 12.0);
    });

    test('scrollBy', () {
      final update = CameraUpdate.scrollBy(50.0, 75.0);
      final json = update.toJson() as List;
      expect(json[0], 'scrollBy');
      expect(json[1], 50.0);
      expect(json[2], 75.0);
    });

    test('zoomBy without focus', () {
      final update = CameraUpdate.zoomBy(2.0);
      final json = update.toJson() as List;
      expect(json[0], 'zoomBy');
      expect(json[1], 2.0);
      expect(json.length, 2);
    });

    test('zoomBy with focus', () {
      final update = CameraUpdate.zoomBy(2.0, const Offset(100.0, 200.0));
      final json = update.toJson() as List;
      expect(json[0], 'zoomBy');
      expect(json[1], 2.0);
      expect(json[2], [100.0, 200.0]);
    });

    test('zoomIn', () {
      final update = CameraUpdate.zoomIn();
      final json = update.toJson() as List;
      expect(json[0], 'zoomIn');
    });

    test('zoomOut', () {
      final update = CameraUpdate.zoomOut();
      final json = update.toJson() as List;
      expect(json[0], 'zoomOut');
    });

    test('zoomTo', () {
      final update = CameraUpdate.zoomTo(10.0);
      final json = update.toJson() as List;
      expect(json[0], 'zoomTo');
      expect(json[1], 10.0);
    });

    test('bearingTo', () {
      final update = CameraUpdate.bearingTo(90.0);
      final json = update.toJson() as List;
      expect(json[0], 'bearingTo');
      expect(json[1], 90.0);
    });

    test('tiltTo', () {
      final update = CameraUpdate.tiltTo(60.0);
      final json = update.toJson() as List;
      expect(json[0], 'tiltTo');
      expect(json[1], 60.0);
    });
  });

  group('CameraTargetBounds', () {
    test('with bounds', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final ctb = CameraTargetBounds(bounds);
      expect(ctb.bounds, bounds);
    });

    test('unbounded', () {
      expect(CameraTargetBounds.unbounded.bounds, isNull);
    });

    test('toJson with bounds', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final json = CameraTargetBounds(bounds).toJson() as List;
      expect(json.length, 1);
      expect(json[0], isNotNull);
    });

    test('toJson unbounded', () {
      final json = CameraTargetBounds.unbounded.toJson() as List;
      expect(json[0], isNull);
    });

    test('equality', () {
      final bounds = LatLngBounds(
        southwest: const LatLng(10.0, 20.0),
        northeast: const LatLng(30.0, 40.0),
      );
      final a = CameraTargetBounds(bounds);
      final b = CameraTargetBounds(bounds);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('toString', () {
      expect(
        CameraTargetBounds.unbounded.toString(),
        contains('CameraTargetBounds'),
      );
    });
  });

  group('MinMaxZoomPreference', () {
    test('basic construction', () {
      const pref = MinMaxZoomPreference(3.0, 18.0);
      expect(pref.minZoom, 3.0);
      expect(pref.maxZoom, 18.0);
    });

    test('unbounded', () {
      expect(MinMaxZoomPreference.unbounded.minZoom, isNull);
      expect(MinMaxZoomPreference.unbounded.maxZoom, isNull);
    });

    test('asserts minZoom <= maxZoom', () {
      expect(
        () => MinMaxZoomPreference(20.0, 10.0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('allows null min or max', () {
      const onlyMin = MinMaxZoomPreference(5.0, null);
      expect(onlyMin.minZoom, 5.0);
      expect(onlyMin.maxZoom, isNull);

      const onlyMax = MinMaxZoomPreference(null, 15.0);
      expect(onlyMax.minZoom, isNull);
      expect(onlyMax.maxZoom, 15.0);
    });

    test('toJson', () {
      const pref = MinMaxZoomPreference(3.0, 18.0);
      final json = pref.toJson() as List;
      expect(json, [3.0, 18.0]);
    });

    test('equality', () {
      const a = MinMaxZoomPreference(3.0, 18.0);
      const b = MinMaxZoomPreference(3.0, 18.0);
      const c = MinMaxZoomPreference(3.0, 20.0);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('toString', () {
      const pref = MinMaxZoomPreference(3.0, 18.0);
      expect(pref.toString(), contains('MinMaxZoomPreference'));
    });
  });
}
