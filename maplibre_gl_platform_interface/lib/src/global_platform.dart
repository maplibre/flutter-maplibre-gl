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
/// [ensureLibraryLoaded] throw [UnimplementedError] unless a platform
/// overrides them, so an implementation written against an older version of
/// this class keeps compiling.
abstract class MapLibreGlobalPlatform {
  /// The instance behind the global functions in `maplibre_gl`, such as
  /// `preWarm()`, `ensureWebLibraryLoaded()` and the offline region calls.
  ///
  /// Defaults to [MapLibreGlobalMethodChannel]. Platform packages replace it
  /// when they register themselves.
  static MapLibreGlobalPlatform instance = MapLibreGlobalMethodChannel();

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
      throw UnimplementedError('installOfflineMapTiles() is not implemented.');

  /// Forces the map engine offline, or gives the network state back to the
  /// system.
  Future<void> setOffline(bool offline) =>
      throw UnimplementedError('setOffline() is not implemented.');

  /// Sets the HTTP headers sent with every request of every map.
  Future<void> setHttpHeaders(Map<String, String> headers) =>
      throw UnimplementedError('setHttpHeaders() is not implemented.');

  /// Imports the regions of another offline database and returns them.
  Future<List<OfflineRegion>> mergeOfflineRegions(String path) =>
      throw UnimplementedError('mergeOfflineRegions() is not implemented.');

  /// The absolute path of the offline database, or `null`.
  Future<String?> getOfflineDatabasePath() =>
      throw UnimplementedError('getOfflineDatabasePath() is not implemented.');

  /// The offline regions stored on the device.
  Future<List<OfflineRegion>> getListOfRegions() =>
      throw UnimplementedError('getListOfRegions() is not implemented.');

  /// Replaces the metadata of a region and returns the updated region.
  Future<OfflineRegion> updateOfflineRegionMetadata(
    int id,
    Map<String, dynamic> metadata,
  ) =>
      throw UnimplementedError(
        'updateOfflineRegionMetadata() is not implemented.',
      );

  /// Caps the number of tiles an offline download may store.
  Future<void> setOfflineTileCountLimit(int limit) =>
      throw UnimplementedError(
        'setOfflineTileCountLimit() is not implemented.',
      );

  /// Limits the concurrent tile requests, in total and per host.
  Future<void> setOfflineMaxConcurrentRequests({
    int? maxRequests,
    int? maxRequestsPerHost,
  }) =>
      throw UnimplementedError(
        'setOfflineMaxConcurrentRequests() is not implemented.',
      );

  /// Pauses the download of a region.
  Future<void> pauseOfflineRegionDownload(int id) =>
      throw UnimplementedError(
        'pauseOfflineRegionDownload() is not implemented.',
      );

  /// Resumes the paused download of a region.
  Future<void> resumeOfflineRegionDownload(int id) =>
      throw UnimplementedError(
        'resumeOfflineRegionDownload() is not implemented.',
      );

  /// The download status of a region.
  Future<OfflineRegionStatus> getOfflineRegionStatus(int id) =>
      throw UnimplementedError('getOfflineRegionStatus() is not implemented.');

  /// Deletes a region.
  Future<void> deleteOfflineRegion(int id) =>
      throw UnimplementedError('deleteOfflineRegion() is not implemented.');

  /// Removes the ambient cache tiles that belong to no offline region.
  Future<void> clearAmbientCache() =>
      throw UnimplementedError('clearAmbientCache() is not implemented.');

  /// Sets the size limit of the ambient cache, in bytes.
  Future<void> setMaximumAmbientCacheSize(int bytes) =>
      throw UnimplementedError(
        'setMaximumAmbientCacheSize() is not implemented.',
      );

  /// Deletes every offline region and clears the ambient cache.
  Future<void> resetOfflineDatabase() =>
      throw UnimplementedError('resetOfflineDatabase() is not implemented.');

  /// Starts downloading a region and completes with it once it is created.
  /// [onEvent] receives the progress of the download, then its end.
  Future<OfflineRegion> downloadOfflineRegion(
    OfflineRegionDefinition definition, {
    Map<String, dynamic> metadata = const {},
    void Function(DownloadRegionStatus event)? onEvent,
  }) => throw UnimplementedError('downloadOfflineRegion() is not implemented.');
}

/// The default [MapLibreGlobalPlatform] until a platform registers its own.
///
/// Android and iOS now register an implementation of their own from
/// `maplibre_gl`, so this class only answers [preWarm] and
/// [ensureLibraryLoaded] for a host where no implementation registered.
class MapLibreGlobalMethodChannel extends MapLibreGlobalPlatform {
  static const _channel = MethodChannel('plugins.flutter.io/maplibre_gl');

  @override
  Future<void> preWarm() async {
    try {
      await _channel.invokeMethod('preWarm');
    } on MissingPluginException {
      // Platform doesn't implement preWarm; no-op.
    }
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    // Nothing to load: the native SDKs ship inside the app binary. Kept a
    // completed future rather than a throw so app code can await it
    // unconditionally on every platform.
  }
}
