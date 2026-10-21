@JS()
library;

import 'dart:js_interop';

import 'package:maplibre_gl_platform_interface/download_region_status.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';
import 'package:maplibre_gl_web/src/js_loader.dart';

/// Calls `maplibregl.prewarm()` to pre-create the Web Worker pool.
@JS('maplibregl.prewarm')
external void _maplibrePrewarm();

/// The web [MapLibreGlobalPlatform]: plugin-global calls that must work
/// before any map widget, and therefore any [MapLibrePlatform] instance,
/// exists.
///
/// Installed by `MapLibreMapPlugin.registerWith`, which the generated web
/// bootstrap runs before the app's `main()`, so `preWarm()` and
/// `ensureWebLibraryLoaded()` reach this class even as the first statement of
/// `main()`.
class MapLibreGlobalWeb extends MapLibreGlobalPlatform {
  @override
  Future<void> preWarm() async {
    // On web the expensive part is fetching maplibre-gl-js itself; the worker
    // pool is cheap by comparison. Starting the download during app start-up
    // instead of at the first map build is what makes preWarm() earn its name
    // here.
    await MapLibreJsLoader.ensureLoaded();
    _maplibrePrewarm();
  }

  @override
  Future<void> ensureLibraryLoaded() => MapLibreJsLoader.ensureLoaded();

  // MapLibre GL JS has no offline storage, no ambient cache on disk and no
  // switch to force the map offline. Each call says so, instead of failing
  // with a MissingPluginException that reads like a broken registration. The
  // error arrives through the returned future, as that exception did.
  static Future<Never> _unsupported(String method, String reason) =>
      Future.error(
        UnsupportedError('$method is not available on web: $reason'),
      );

  static const _noOffline = 'MapLibre GL JS has no offline storage.';

  @override
  Future<void> installOfflineMapTiles(String tilesDb) =>
      _unsupported('installOfflineMapTiles', _noOffline);

  @override
  Future<void> setOffline(bool offline) => _unsupported(
    'setOffline',
    'MapLibre GL JS has no switch to force the map offline. It is supported '
        'on Android only.',
  );

  @override
  Future<void> setHttpHeaders(Map<String, String> headers) => _unsupported(
    'setHttpHeaders',
    'the browser sends the requests of MapLibre GL JS itself.',
  );

  @override
  Future<List<OfflineRegion>> mergeOfflineRegions(String path) =>
      _unsupported('mergeOfflineRegions', _noOffline);

  @override
  Future<String?> getOfflineDatabasePath() =>
      _unsupported('getOfflineDatabasePath', _noOffline);

  @override
  Future<List<OfflineRegion>> getListOfRegions() =>
      _unsupported('getListOfRegions', _noOffline);

  @override
  Future<OfflineRegion> updateOfflineRegionMetadata(
    int id,
    Map<String, dynamic> metadata,
  ) => _unsupported('updateOfflineRegionMetadata', _noOffline);

  @override
  Future<void> setOfflineTileCountLimit(int limit) =>
      _unsupported('setOfflineTileCountLimit', _noOffline);

  @override
  Future<void> setOfflineMaxConcurrentRequests({
    int? maxRequests,
    int? maxRequestsPerHost,
  }) => _unsupported('setOfflineMaxConcurrentRequests', _noOffline);

  @override
  Future<void> pauseOfflineRegionDownload(int id) =>
      _unsupported('pauseOfflineRegionDownload', _noOffline);

  @override
  Future<void> resumeOfflineRegionDownload(int id) =>
      _unsupported('resumeOfflineRegionDownload', _noOffline);

  @override
  Future<OfflineRegionStatus> getOfflineRegionStatus(int id) =>
      _unsupported('getOfflineRegionStatus', _noOffline);

  @override
  Future<void> deleteOfflineRegion(int id) =>
      _unsupported('deleteOfflineRegion', _noOffline);

  @override
  Future<void> clearAmbientCache() => _unsupported(
    'clearAmbientCache',
    'the ambient cache is the browser cache.',
  );

  @override
  Future<void> setMaximumAmbientCacheSize(int bytes) => _unsupported(
    'setMaximumAmbientCacheSize',
    'the ambient cache is the browser cache.',
  );

  @override
  Future<void> resetOfflineDatabase() =>
      _unsupported('resetOfflineDatabase', _noOffline);

  @override
  Future<OfflineRegion> downloadOfflineRegion(
    OfflineRegionDefinition definition, {
    Map<String, dynamic> metadata = const {},
    void Function(DownloadRegionStatus event)? onEvent,
  }) => _unsupported('downloadOfflineRegion', _noOffline);
}
