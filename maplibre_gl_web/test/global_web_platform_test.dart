// MapLibreGlobalWeb imports dart:js_interop, so these tests only run under
// `flutter test --platform chrome`; the VM run skips them.
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/global_web_platform.dart';

void main() {
  final web = MapLibreGlobalWeb();
  final definition = OfflineRegionDefinition(
    bounds: LatLngBounds(
      southwest: const LatLng(10.0, 20.0),
      northeast: const LatLng(30.0, 40.0),
    ),
    mapStyleUrl: 'https://example.com/style.json',
    minZoom: 5.0,
    maxZoom: 15.0,
  );

  // Offline storage and the on-disk ambient cache do not exist in the browser,
  // so every global call says so instead of failing with the
  // MissingPluginException of a channel nobody listens to.
  final calls = <String, Future<Object?> Function()>{
    'installOfflineMapTiles': () => web.installOfflineMapTiles('cache.db'),
    'setOffline': () => web.setOffline(true),
    'setHttpHeaders': () => web.setHttpHeaders({'a': 'b'}),
    'mergeOfflineRegions': () => web.mergeOfflineRegions('/x.db'),
    'getOfflineDatabasePath': web.getOfflineDatabasePath,
    'getListOfRegions': web.getListOfRegions,
    'updateOfflineRegionMetadata': () => web.updateOfflineRegionMetadata(1, {}),
    'setOfflineTileCountLimit': () => web.setOfflineTileCountLimit(10),
    'setOfflineMaxConcurrentRequests':
        () => web.setOfflineMaxConcurrentRequests(maxRequestsPerHost: 2),
    'pauseOfflineRegionDownload': () => web.pauseOfflineRegionDownload(1),
    'resumeOfflineRegionDownload': () => web.resumeOfflineRegionDownload(1),
    'getOfflineRegionStatus': () => web.getOfflineRegionStatus(1),
    'deleteOfflineRegion': () => web.deleteOfflineRegion(1),
    'clearAmbientCache': web.clearAmbientCache,
    'setMaximumAmbientCacheSize': () => web.setMaximumAmbientCacheSize(0),
    'resetOfflineDatabase': web.resetOfflineDatabase,
    'downloadOfflineRegion': () => web.downloadOfflineRegion(definition),
  };

  for (final MapEntry(key: method, value: call) in calls.entries) {
    test('$method throws UnsupportedError naming the method', () {
      expect(
        call,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('$method is not available on web'),
          ),
        ),
      );
    });
  }
}
