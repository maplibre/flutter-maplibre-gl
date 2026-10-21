part of '../maplibre_gl.dart';

/// Registers the Android and iOS implementation of the plugin.
///
/// Flutter calls [registerWith] before `main()` runs, through the
/// `dartPluginClass` of this package; apps never need to. Where the generated
/// registrant does not run, such as an isolate the app spawns, the global
/// functions and [MapLibreMap] install it on first use.
///
/// @nodoc
class MapLibreNativePlugin {
  MapLibreNativePlugin._();

  /// Installs the Pigeon-based implementation of the plugin-wide calls and
  /// of the calls of each map.
  ///
  /// [globalHostApi] replaces the generated client of the plugin-wide calls,
  /// and [mapHostApi] builds the client of the map with the given platform
  /// view id in place of the generated one, for tests.
  static void registerWith({
    @visibleForTesting MapLibreGlobalHostApi? globalHostApi,
    @visibleForTesting MapLibreMapHostApi Function(int id)? mapHostApi,
  }) {
    MapLibreGlobalPlatform.instance = _MapLibreNativeGlobalPlatform(
      globalHostApi ?? MapLibreGlobalHostApi(),
    );
    MapLibrePlatform.createInstance = () => _MapLibreNativePlatform(mapHostApi);
  }
}

/// The [MapLibreGlobalPlatform] of Android and iOS, talking to the native
/// code through the messages generated from `pigeons/messages.dart`.
class _MapLibreNativeGlobalPlatform extends MapLibreGlobalPlatform
    implements MapLibreOfflineDownloadFlutterApi {
  _MapLibreNativeGlobalPlatform(this._api);

  final MapLibreGlobalHostApi _api;

  // Set up on the first download rather than in the constructor: registerWith
  // runs before main(), when there is no binding to give a message handler to.
  bool _listeningForDownloads = false;

  /// Listeners of the downloads in progress, by the id this class gave each
  /// download. Native tags every event with that id.
  final Map<int, void Function(DownloadRegionStatus)> _downloadListeners = {};

  // Starts from the clock rather than 0: a hot restart builds a new instance
  // while native downloads started before it may still send events, and an id
  // handed out again would deliver them to the new download.
  int _nextDownloadId = DateTime.now().microsecondsSinceEpoch;

  @override
  Future<void> preWarm() async {
    try {
      await _api.preWarm();
    } on PlatformException catch (e) {
      // No native side to answer, for instance in a host app that does not
      // register the plugin: warming up is optional, so do nothing.
      if (e.code != 'channel-error') rethrow;
    }
  }

  @override
  Future<void> ensureLibraryLoaded() async {
    // Nothing to load: the native SDKs ship inside the app binary. Kept a
    // completed future rather than a throw so app code can await it
    // unconditionally on every platform.
  }

  @override
  Future<void> installOfflineMapTiles(String tilesDb) =>
      _api.installOfflineMapTiles(tilesDb);

  @override
  Future<void> setOffline(bool offline) {
    // Reject here rather than let native answer: the MapLibre iOS SDK has no
    // switch to force the map offline.
    if (defaultTargetPlatform != TargetPlatform.android) {
      return Future.error(
        UnsupportedError(
          'setOffline is not available on ${defaultTargetPlatform.name} '
          'because the MapLibre SDK there has no offline switch. It is '
          'supported on Android only.',
        ),
      );
    }
    return _api.setOffline(offline);
  }

  @override
  Future<void> setHttpHeaders(Map<String, String> headers) =>
      _api.setHttpHeaders(headers);

  @override
  Future<List<OfflineRegion>> mergeOfflineRegions(String path) async =>
      _regionsFromJson(await _api.mergeOfflineRegions(path));

  @override
  Future<String?> getOfflineDatabasePath() => _api.getOfflineDatabasePath();

  @override
  Future<List<OfflineRegion>> getListOfRegions() async =>
      _regionsFromJson(await _api.getListOfRegions());

  @override
  Future<OfflineRegion> updateOfflineRegionMetadata(
    int id,
    Map<String, dynamic> metadata,
  ) async => OfflineRegion.fromMap(
    json.decode(await _api.updateOfflineRegionMetadata(id, metadata)),
  );

  @override
  Future<void> setOfflineTileCountLimit(int limit) =>
      _api.setOfflineTileCountLimit(limit);

  @override
  Future<void> setOfflineMaxConcurrentRequests({
    int? maxRequests,
    int? maxRequestsPerHost,
  }) => _api.setOfflineMaxConcurrentRequests(maxRequests, maxRequestsPerHost);

  @override
  Future<void> pauseOfflineRegionDownload(int id) =>
      _api.pauseOfflineRegionDownload(id);

  @override
  Future<void> resumeOfflineRegionDownload(int id) =>
      _api.resumeOfflineRegionDownload(id);

  @override
  Future<OfflineRegionStatus> getOfflineRegionStatus(int id) async =>
      OfflineRegionStatus.fromMap(
        Map<String, dynamic>.from(
          json.decode(await _api.getOfflineRegionStatus(id)),
        ),
      );

  @override
  Future<void> deleteOfflineRegion(int id) => _api.deleteOfflineRegion(id);

  @override
  Future<void> clearAmbientCache() => _api.clearAmbientCache();

  @override
  Future<void> setMaximumAmbientCacheSize(int bytes) =>
      _api.setMaximumAmbientCacheSize(bytes);

  @override
  Future<void> resetOfflineDatabase() async {
    // The downloads the reset can end. One started while it runs is not
    // among them and keeps its listener.
    final resetDownloadIds = _downloadListeners.keys.toList();
    try {
      await _api.resetOfflineDatabase();
    } finally {
      // Native ends every download in flight with a DatabaseReset error, which
      // removes its listener. The short delay lets those events arrive first;
      // any of those downloads still registered afterwards would never hear
      // from native again, so its listener is dropped.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      resetDownloadIds.forEach(_downloadListeners.remove);
    }
  }

  @override
  Future<OfflineRegion> downloadOfflineRegion(
    OfflineRegionDefinition definition, {
    Map<String, dynamic> metadata = const {},
    void Function(DownloadRegionStatus event)? onEvent,
  }) async {
    if (!_listeningForDownloads) {
      MapLibreOfflineDownloadFlutterApi.setUp(this);
      _listeningForDownloads = true;
    }
    final downloadId = _nextDownloadId++;
    if (onEvent != null) _downloadListeners[downloadId] = onEvent;
    final String regionJson;
    try {
      regionJson = await _api.downloadOfflineRegion(
        downloadId,
        definition.toMap(),
        metadata,
      );
    } catch (_) {
      // A call that fails, for instance on a definition native cannot read,
      // may end without the final event that would remove the listener.
      _downloadListeners.remove(downloadId);
      rethrow;
    }
    return OfflineRegion.fromMap(json.decode(regionJson));
  }

  /// Called by native with the events of the download [downloadId].
  @override
  Future<void> onDownloadEvent(
    int downloadId,
    PgOfflineDownloadEvent event,
  ) async {
    final listener = _downloadListeners[downloadId];
    if (listener == null) return;
    final status = switch (event.status) {
      PgOfflineDownloadStatus.start => InProgress(0.0),
      PgOfflineDownloadStatus.progress => InProgress(
        event.progress ?? 0.0,
        completedResourceCount: event.completedResourceCount ?? 0,
        requiredResourceCount: event.requiredResourceCount ?? 0,
        completedResourceSize: event.completedResourceSize ?? 0,
      ),
      PgOfflineDownloadStatus.success => Success(),
      PgOfflineDownloadStatus.error => Error(
        PlatformException(
          code: event.errorCode ?? 'error',
          message: event.errorMessage,
          details: event.errorDetails,
        ),
      ),
    };
    if (status is Success || status is Error) {
      _downloadListeners.remove(downloadId);
    }
    listener(status);
  }

  static List<OfflineRegion> _regionsFromJson(String regionsJson) =>
      List<Map<String, dynamic>>.from(
        json.decode(regionsJson),
      ).map(OfflineRegion.fromMap).toList();
}
