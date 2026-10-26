part of '../maplibre_gl_platform_interface.dart';

/// Platform hooks for operations that are global to the plugin rather than
/// tied to a single map, so they can run before any map widget exists.
///
/// [MapLibrePlatform] is created per map widget through
/// [MapLibrePlatform.createInstance], which makes it unusable for calls apps
/// issue from `main()`, before the first map is built. This class fills that
/// gap: each platform replaces [instance] when it registers, the same way it
/// replaces [MapLibrePlatform.createInstance].
///
/// The methods back the top-level functions of `maplibre_gl` with the same
/// names, which document them for apps. Those added after [preWarm] and
/// [ensureLibraryLoaded] fail with [UnimplementedError] unless a platform
/// overrides them, so an implementation written against an older version of
/// this class keeps compiling. The error arrives through the returned future,
/// not as a throw from the call itself.
abstract class MapLibreGlobalPlatform {
  static final MapLibreGlobalPlatform _unregistered =
      _UnregisteredGlobalPlatform();

  /// The instance behind the global functions in `maplibre_gl`, such as
  /// `preWarm()`, `ensureWebLibraryLoaded()` and the offline region calls.
  ///
  /// Platform packages replace it when they register themselves, and tests
  /// can replace it with a fake. Until then [preWarm] and
  /// [ensureLibraryLoaded] do nothing and the other calls fail with
  /// [UnimplementedError].
  static MapLibreGlobalPlatform instance = _unregistered;

  /// Whether [instance] was replaced, by a platform package or a test.
  ///
  /// Assigning back the instance read before any replacement makes this
  /// `false` again.
  static bool get isRegistered => !identical(instance, _unregistered);

  /// Starts up the underlying map engine ahead of the first map widget.
  Future<void> preWarm();

  /// Completes once the underlying map library is ready to be called.
  ///
  /// Only web does real work here, where MapLibre GL JS is fetched at
  /// runtime; Android and iOS complete immediately because their engine is
  /// linked into the app binary. See the app-facing `ensureWebLibraryLoaded()`
  /// in `maplibre_gl`.
  Future<void> ensureLibraryLoaded();

  /// Copies a sideloaded tiles database into place, from an absolute path or
  /// a Flutter asset key.
  Future<void> installOfflineMapTiles(String tilesDb) =>
      _notImplemented('installOfflineMapTiles');

  /// Forces the map engine offline, or gives the network state back to the
  /// system.
  Future<void> setOffline(bool offline) => _notImplemented('setOffline');

  /// Sets the HTTP headers sent with every request of every map.
  Future<void> setHttpHeaders(Map<String, String> headers) =>
      _notImplemented('setHttpHeaders');

  /// Imports the regions of another offline database and returns them.
  Future<List<OfflineRegion>> mergeOfflineRegions(String path) =>
      _notImplemented('mergeOfflineRegions');

  /// The absolute path of the offline database, or `null`.
  Future<String?> getOfflineDatabasePath() =>
      _notImplemented('getOfflineDatabasePath');

  /// The offline regions stored on the device.
  Future<List<OfflineRegion>> getListOfRegions() =>
      _notImplemented('getListOfRegions');

  /// Replaces the metadata of a region and returns the updated region.
  Future<OfflineRegion> updateOfflineRegionMetadata(
    int id,
    Map<String, dynamic> metadata,
  ) => _notImplemented('updateOfflineRegionMetadata');

  /// Caps the number of tiles an offline download may store.
  Future<void> setOfflineTileCountLimit(int limit) =>
      _notImplemented('setOfflineTileCountLimit');

  /// Limits the concurrent tile requests, in total and per host.
  Future<void> setOfflineMaxConcurrentRequests({
    int? maxRequests,
    int? maxRequestsPerHost,
  }) => _notImplemented('setOfflineMaxConcurrentRequests');

  /// Pauses the download of a region.
  Future<void> pauseOfflineRegionDownload(int id) =>
      _notImplemented('pauseOfflineRegionDownload');

  /// Resumes the paused download of a region.
  Future<void> resumeOfflineRegionDownload(int id) =>
      _notImplemented('resumeOfflineRegionDownload');

  /// The download status of a region.
  Future<OfflineRegionStatus> getOfflineRegionStatus(int id) =>
      _notImplemented('getOfflineRegionStatus');

  /// Deletes a region.
  Future<void> deleteOfflineRegion(int id) =>
      _notImplemented('deleteOfflineRegion');

  /// Removes the ambient cache tiles that belong to no offline region.
  Future<void> clearAmbientCache() => _notImplemented('clearAmbientCache');

  /// Sets the size limit of the ambient cache, in bytes.
  Future<void> setMaximumAmbientCacheSize(int bytes) =>
      _notImplemented('setMaximumAmbientCacheSize');

  /// Deletes every offline region and clears the ambient cache.
  Future<void> resetOfflineDatabase() =>
      _notImplemented('resetOfflineDatabase');

  /// Starts downloading a region and completes with it once it is created.
  /// [onEvent] receives the progress of the download, then its end.
  Future<OfflineRegion> downloadOfflineRegion(
    OfflineRegionDefinition definition, {
    Map<String, dynamic> metadata = const {},
    void Function(DownloadRegionStatus event)? onEvent,
  }) => _notImplemented('downloadOfflineRegion');

  // The answer of a member the platform does not override. The error arrives
  // through the returned future, so callers handle it like any other failure
  // of the call. Typed after the member rather than Future<Never>, so a
  // catchError handler can return a fallback value.
  static Future<T> _notImplemented<T>(String method) =>
      Future<T>.error(UnimplementedError('$method() is not implemented.'));
}

/// The [MapLibreGlobalPlatform] of a host where no implementation registered,
/// such as a desktop app.
class _UnregisteredGlobalPlatform extends MapLibreGlobalPlatform {
  // Warming up is optional and there is no library to load, so both complete
  // and app code can await them on every host.
  @override
  Future<void> preWarm() async {}

  @override
  Future<void> ensureLibraryLoaded() async {}
}
