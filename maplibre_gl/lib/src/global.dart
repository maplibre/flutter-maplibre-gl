// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../maplibre_gl.dart';

// Every call goes through MapLibreGlobalPlatform.instance, which each platform
// replaces when it registers: Pigeon messages on Android and iOS, an
// UnsupportedError per call on web, where offline storage does not exist.
MapLibreGlobalPlatform get _global {
  // The generated registrant only runs in the app's main isolate. Elsewhere,
  // for instance in an isolate the app spawns, install the Android and iOS
  // implementation on first use instead of leaving the default in place. The
  // exact type check keeps a subclass that a package installed on purpose.
  if (!kIsWeb &&
      MapLibreGlobalPlatform.instance.runtimeType ==
          MapLibreGlobalMethodChannel &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    MapLibreNativePlugin.registerWith();
  }
  return MapLibreGlobalPlatform.instance;
}

// The same fallback for the platform of each map, which MapLibreMap creates
// through this function. Where the registrant did not run, the factory still
// returns the default method channel platform, which native no longer
// answers, so the Android and iOS implementation replaces it. Only the map
// factory is replaced: a global platform installed on its own stays.
MapLibrePlatform _createMapLibrePlatform() {
  final platform = MapLibrePlatform.createInstance();
  if (!kIsWeb &&
      // The deprecated default is what tells that nothing registered. Only
      // the default itself: a subclass is a platform a package installed on
      // purpose.
      // ignore: deprecated_member_use
      platform.runtimeType == MapLibreMethodChannel &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    MapLibrePlatform.createInstance = _MapLibreNativePlatform.new;
    return MapLibrePlatform.createInstance();
  }
  return platform;
}

/// Copy tiles db file passed in to the tiles cache directory (sideloaded) to
/// make tiles available offline.
Future<void> installOfflineMapTiles(String tilesDb) =>
    _global.installOfflineMapTiles(tilesDb);

enum DragEventType { start, drag, end }

enum HoverEventType { enter, move, leave }

/// Forces MapLibre offline, or gives the network state back to the system.
///
/// With `true`, MapLibre stops requesting tiles, styles, sprites and glyphs
/// from the network and draws from what is already in the cache or in
/// downloaded offline regions. With `false`, it follows the device's network
/// state again. The setting applies to every map in the app.
///
/// Android only. Throws an [UnsupportedError] on iOS, where the MapLibre iOS
/// SDK has no offline switch, and on web.
Future<void> setOffline(bool offline) => _global.setOffline(offline);

/// Sets HTTP headers that are injected into every network request MapLibre
/// makes (tile fetches, style JSON, sprites, glyphs).
///
/// This is a **global** API: the headers apply to all map instances in the
/// process. To scope headers to specific URLs or to a single map instance,
/// use [MaplibreMapController.setCustomHeaders] instead.
///
/// Headers are applied at request time, so this method can be called before
/// or after a [MaplibreMap] widget is created. Calling it again replaces the
/// previously set headers; pass an empty map to clear all headers.
///
/// Example — attach a bearer token before showing any map:
/// ```dart
/// await setHttpHeaders({'Authorization': 'Bearer $token'});
/// ```
///
/// Example — attach multiple headers:
/// ```dart
/// await setHttpHeaders({
///   'Authorization': 'Bearer $token',
///   'X-Request-ID': requestId,
/// });
/// ```
///
/// Example — clear all previously set headers:
/// ```dart
/// await setHttpHeaders({});
/// ```
Future<void> setHttpHeaders(Map<String, String> headers) =>
    _global.setHttpHeaders(headers);

/// Imports the regions of the offline database at [path], for example one
/// written by [exportOfflineDatabase] on another device, and returns them.
///
/// Android and iOS only; throws [UnsupportedError] on web.
Future<List<OfflineRegion>> mergeOfflineRegions(String path) =>
    _global.mergeOfflineRegions(path);

/// Returns the absolute path of the offline database backing the offline packs
/// and the ambient cache, or `null` if it cannot be resolved.
///
/// This is the file [mergeOfflineRegions] imports from. It holds the whole
/// store, every region plus the ambient cache, so it is not a per-region
/// export.
///
/// Android and iOS only; there is no offline support on web.
Future<String?> getOfflineDatabasePath() => _global.getOfflineDatabasePath();

/// Writes a copy of the offline database to a path of your choosing, file name
/// included, for example
/// `'${(await getTemporaryDirectory()).path}/regions.db'`. The parent directory
/// of [destinationPath] must already exist.
///
/// Returns that same path once written, or `null` when nothing has been
/// downloaded yet. Import the copy elsewhere with [mergeOfflineRegions].
///
/// Like [getOfflineDatabasePath], this covers the whole store rather than one
/// region, and it brings the SQLite `-wal` and `-shm` sidecars along so the
/// copy is consistent.
///
/// Android and iOS only; throws [UnsupportedError] on web.
Future<String?> exportOfflineDatabase(String destinationPath) async {
  // Reject here rather than let the method channel answer first: on web that
  // call fails with a MissingPluginException, which is not the error this
  // documents and not one an app can tell apart from a broken registration.
  if (kIsWeb) {
    throw UnsupportedError('Offline database export is not available on web.');
  }
  final dbPath = await getOfflineDatabasePath();
  if (dbPath == null) return null;
  return copyOfflineDatabase(dbPath, destinationPath);
}

/// Lists the offline regions stored on the device.
///
/// On iOS the stored regions load asynchronously after launch; this waits for
/// them, so a call made right at startup returns the same list as Android.
Future<List<OfflineRegion>> getListOfRegions() => _global.getListOfRegions();

/// Replaces the metadata of the offline region with the given [id] and returns
/// the updated region.
///
/// [metadata] must be JSON-encodable: strings, numbers, booleans, null, and
/// lists and maps of those, with string keys. Other values, such as a
/// `Uint8List`, fail on iOS with `UpdateMetadataError`, while Android stores
/// them in whatever form its JSON encoder gives them (a `Uint8List` comes
/// back as a list of numbers).
///
/// Throws a [PlatformException] with code `UpdateMetadataError` when no region
/// has that [id].
Future<OfflineRegion> updateOfflineRegionMetadata(
  int id,
  Map<String, dynamic> metadata,
) => _global.updateOfflineRegionMetadata(id, metadata);

/// Caps the number of tiles a single offline region download may store.
/// A download that would need more fails with `tileCountLimitExceeded`.
Future<void> setOfflineTileCountLimit(int limit) =>
    _global.setOfflineTileCountLimit(limit);

/// Sets the maximum number of concurrent HTTP requests for tile downloads.
///
/// [maxRequests] controls the total number of concurrent requests (Android
/// only). [maxRequestsPerHost] controls the per-host concurrency limit
/// (both platforms). Lowering these values can help avoid rate limiting from
/// tile servers (e.g. Cloudflare).
///
/// Both values must be >= 1 when provided; OkHttp's `Dispatcher` throws on
/// non-positive values.
Future<void> setOfflineMaxConcurrentRequests({
  int? maxRequests,
  int? maxRequestsPerHost,
}) {
  assert(
    maxRequests == null || maxRequests >= 1,
    'maxRequests must be >= 1 (got $maxRequests)',
  );
  assert(
    maxRequestsPerHost == null || maxRequestsPerHost >= 1,
    'maxRequestsPerHost must be >= 1 (got $maxRequestsPerHost)',
  );
  return _global.setOfflineMaxConcurrentRequests(
    maxRequests: maxRequests,
    maxRequestsPerHost: maxRequestsPerHost,
  );
}

/// Pauses an in-progress offline region download.
Future<void> pauseOfflineRegionDownload(int id) =>
    _global.pauseOfflineRegionDownload(id);

/// Resumes a paused offline region download.
Future<void> resumeOfflineRegionDownload(int id) =>
    _global.resumeOfflineRegionDownload(id);

/// Gets the current download status of an offline region.
Future<OfflineRegionStatus> getOfflineRegionStatus(int id) =>
    _global.getOfflineRegionStatus(id);

/// Deletes the offline region with the given [id] and the tiles only it uses.
Future<void> deleteOfflineRegion(int id) => _global.deleteOfflineRegion(id);

/// Removes all tiles from the shared ambient cache that are not associated
/// with any offline region. Call this after [deleteOfflineRegion] to fully
/// evict tiles that would otherwise be reused by a future download of the
/// same area.
Future<void> clearAmbientCache() => _global.clearAmbientCache();

/// Sets the size limit, in [bytes], of the ambient cache: the tiles and
/// style resources the map keeps on disk from normal browsing. The default
/// is 50 MB and `0` turns the cache off. Offline regions do not count
/// towards the limit.
///
/// Call it before the first map is created. A cache already over the new
/// limit is trimmed right away.
///
/// Throws an [ArgumentError] if [bytes] is negative. Android and iOS only;
/// throws [UnsupportedError] on web.
Future<void> setMaximumAmbientCacheSize(int bytes) {
  if (bytes < 0) {
    throw ArgumentError.value(bytes, 'bytes', 'Must be 0 or more');
  }
  return _global.setMaximumAmbientCacheSize(bytes);
}

/// Resets the entire offline database: deletes every offline region and
/// clears the ambient cache. Use with care — offline regions cannot be
/// recovered afterwards.
Future<void> resetOfflineDatabase() => _global.resetOfflineDatabase();

/// Downloads the region described by [definition] for offline use and
/// completes with it once the region is created, before its tiles are in.
///
/// [onEvent] receives the progress of the download: [InProgress] events, then
/// [Success], or [Error] with the [PlatformException] that stopped it.
/// [metadata] is stored with the region and must be JSON-encodable.
Future<OfflineRegion> downloadOfflineRegion(
  OfflineRegionDefinition definition, {
  Map<String, dynamic> metadata = const {},
  Function(DownloadRegionStatus event)? onEvent,
}) => _global.downloadOfflineRegion(
  definition,
  metadata: metadata,
  onEvent: onEvent == null ? null : (event) => onEvent(event),
);
