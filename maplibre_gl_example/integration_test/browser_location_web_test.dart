// Integration test for the browser location puck on web.
//
// With myLocationEnabled and MyLocationTrackingMode.none the puck shows up and
// the camera stays put, as on Android and iOS. The browser Geolocation API is
// replaced by a fake that answers at once, so no permission prompt is needed.
//
// It imports package:web, which does not compile for Android or iOS, so it
// is not part of all_tests.dart. Run on Chrome:
//   chromedriver --port=4444 &
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/browser_location_web_test.dart \
//     -d web-server --browser-name=chrome
//
// The assertions only run on web; elsewhere the tests are no-ops.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:web/web.dart' as web;

import 'support/map_harness.dart';

const _fix = LatLng(45.4642, 9.19);
const _start = CameraPosition(target: LatLng(0, 0), zoom: 3);

/// Replaces navigator.geolocation with a fake that delivers [_fix] right after
/// every request and counts the watches it was asked for.
const _fakeGeolocation = '''
(() => {
  const watches = new Map();
  let nextId = 1;
  const fix = () => ({
    coords: {
      latitude: 45.4642, longitude: 9.19, accuracy: 30,
      altitude: null, altitudeAccuracy: null, heading: null, speed: null,
    },
    timestamp: Date.now(),
  });
  const fake = {
    watchCount: 0,
    getCurrentPosition(ok) { setTimeout(() => ok(fix()), 0); },
    watchPosition(ok) {
      const id = nextId++;
      fake.watchCount++;
      watches.set(id, ok);
      setTimeout(() => { if (watches.has(id)) ok(fix()); }, 0);
      return id;
    },
    clearWatch(id) { watches.delete(id); },
  };
  Object.defineProperty(navigator, 'geolocation', {
    value: fake,
    configurable: true,
  });
  window.fakeGeolocation = fake;
})();
''';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    if (kIsWeb) {
      globalContext.callMethod<JSAny?>('eval'.toJS, _fakeGeolocation.toJS);
    }
  });

  group('browser location on web', () {
    testWidgets('mode none shows the puck and keeps the camera', (
      tester,
    ) async {
      if (!kIsWeb) return;
      final locations = <UserLocation>[];
      final controller = await _pumpLocationMap(
        tester,
        onLocation: locations.add,
      );

      await _waitForDots(tester, 1);
      expect(locations, isNotEmpty);
      expect(locations.last.position, _fix);
      expect(await controller.requestMyLocationLatLng(), _fix);

      final camera = await controller.queryCameraPosition();
      expect(camera!.target.latitude, closeTo(0, 0.01));
      expect(camera.target.longitude, closeTo(0, 0.01));
    });

    testWidgets('a manual source never asks the browser', (tester) async {
      if (!kIsWeb) return;
      final before = _watchCount();
      await _pumpLocationMap(tester, source: const ManualLocationSource());
      await pumpFor(tester, const Duration(milliseconds: 500));

      expect(_watchCount(), before);
      expect(_dotCount(), 0);
    });

    testWidgets('switching to tracking and back keeps a single puck', (
      tester,
    ) async {
      if (!kIsWeb) return;
      final controller = await _pumpLocationMap(tester);
      await _waitForDots(tester, 1);

      await pumpUntil(
        tester,
        controller.updateMyLocationTrackingMode(
          MyLocationTrackingMode.tracking,
        ),
        'tracking',
      );
      await pumpUntilValue(
        tester,
        controller.queryCameraPosition,
        (camera) => (camera!.target.latitude - _fix.latitude).abs() < 0.01,
        'camera on the fix',
      );
      expect(_dotCount(), 1);

      await pumpUntil(
        tester,
        controller.updateMyLocationTrackingMode(MyLocationTrackingMode.none),
        'none',
      );
      await _waitForDots(tester, 1);
    });
  });
}

Future<MapLibreMapController> _pumpLocationMap(
  WidgetTester tester, {
  LocationSource source = const PlatformLocationSource(),
  void Function(UserLocation)? onLocation,
}) => pumpMap(
  tester,
  builder: (onMapCreated, onStyleLoaded) => MapLibreMap(
    styleString: offlineStyle,
    initialCameraPosition: _start,
    myLocationEnabled: true,
    locationSource: source,
    onUserLocationUpdated: onLocation,
    onMapCreated: onMapCreated,
    onStyleLoadedCallback: onStyleLoaded,
  ),
);

int _dotCount() =>
    web.document.querySelectorAll('.maplibregl-user-location-dot').length;

int _watchCount() =>
    ((globalContext['fakeGeolocation']! as JSObject)['watchCount']! as JSNumber)
        .toDartInt;

/// Pumps until exactly [count] location dots are in the DOM, so a second puck
/// showing up late still fails the test.
Future<void> _waitForDots(WidgetTester tester, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (_dotCount() != count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Expected $count location dot(s), found ${_dotCount()}');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await pumpFor(tester, const Duration(milliseconds: 300));
  expect(_dotCount(), count);
}
