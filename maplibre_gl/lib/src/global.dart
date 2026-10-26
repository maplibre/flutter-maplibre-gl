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
  // implementation on first use. Only when nothing is installed: a package or
  // a test may have installed its own on purpose.
  if (!MapLibreGlobalPlatform.isRegistered && _isAndroidOrIOS) {
    MapLibreNativePlugin._installGlobal();
  }
  return MapLibreGlobalPlatform.instance;
}

// The same fallback for the platform of each map, which MapLibreMap creates
// through this function. Each fallback installs only its own half, so a fake
// of the other one stays.
MapLibrePlatform _createMapLibrePlatform() {
  if (!MapLibrePlatform.isRegistered && _isAndroidOrIOS) {
    MapLibreNativePlugin._installMap();
  }
  return MapLibrePlatform.createInstance();
}

bool get _isAndroidOrIOS =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Copies the tiles database [tilesDb], an absolute path or a Flutter asset,
/// in place of the offline database, so its tiles are available offline.
///
/// Throws a [PlatformException] with code `INVALID_ARGUMENT` when there is no
/// file at [tilesDb], and `OFFLINE_DATABASE_ERROR` when the copy fails.
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
/// process. To send headers only to some URLs, use
/// [MaplibreMapController.setCustomHeaders] with a filter instead.
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
/// Throws a [PlatformException] with code `OFFLINE_DATABASE_ERROR` when the
/// file cannot be merged, with MapLibre's reason as the message.
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
  // Reject here rather than let the platform answer first: on web that
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
/// [metadata] is stored as the JSON [jsonEncode] gives it, so a `Uint8List`
/// comes back as a list of numbers. Metadata [jsonEncode] cannot encode, such
/// as a `NaN` or a map with keys that are not strings, throws a
/// [PlatformException] with code `INVALID_ARGUMENT`.
///
/// Throws a [PlatformException] with code `REGION_NOT_FOUND` when no region
/// has that [id].
Future<OfflineRegion> updateOfflineRegionMetadata(
  int id,
  Map<String, dynamic> metadata,
) => _global.updateOfflineRegionMetadata(id, metadata);

/// Caps the number of tiles a single offline region download may store.
/// A download that would need more ends with an [Error] event whose code is
/// `TILE_COUNT_LIMIT_EXCEEDED`, and the region is deleted.
///
/// Throws a [PlatformException] with code `INVALID_ARGUMENT` if [limit] is
/// negative.
Future<void> setOfflineTileCountLimit(int limit) =>
    _global.setOfflineTileCountLimit(limit);

/// Sets the maximum number of concurrent HTTP requests for tile downloads.
///
/// [maxRequests] controls the total number of concurrent requests (Android
/// only). [maxRequestsPerHost] controls the per-host concurrency limit
/// (both platforms). Lowering these values can help avoid rate limiting from
/// tile servers (e.g. Cloudflare).
///
/// Throws a [PlatformException] with code `INVALID_ARGUMENT` if either value
/// is below 1.
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
///
/// Throws a [PlatformException] with code `REGION_NOT_FOUND` when no region
/// has that [id].
Future<void> pauseOfflineRegionDownload(int id) =>
    _global.pauseOfflineRegionDownload(id);

/// Resumes a paused offline region download.
///
/// It also resumes a region no [downloadOfflineRegion] call of this app
/// session follows, such as one paused before the app restarted; read its
/// progress with [getOfflineRegionStatus]. A complete region is left as it
/// is.
///
/// Throws a [PlatformException] with code `REGION_NOT_FOUND` when no region
/// has that [id].
Future<void> resumeOfflineRegionDownload(int id) =>
    _global.resumeOfflineRegionDownload(id);

/// Gets the current download status of an offline region.
///
/// Throws a [PlatformException] with code `REGION_NOT_FOUND` when no region
/// has that [id].
Future<OfflineRegionStatus> getOfflineRegionStatus(int id) =>
    _global.getOfflineRegionStatus(id);

/// Deletes the offline region with the given [id] and the tiles only it uses.
///
/// A download of the region still in progress ends with an [Error] event
/// whose code is `REGION_DELETED`. Throws a [PlatformException] with code
/// `REGION_NOT_FOUND` when no region has that [id].
Future<void> deleteOfflineRegion(int id) => _global.deleteOfflineRegion(id);

/// Removes all tiles from the shared ambient cache that are not associated
/// with any offline region. Call this after [deleteOfflineRegion] to fully
/// evict tiles that would otherwise be reused by a future download of the
/// same area.
///
/// Throws a [PlatformException] with code `AMBIENT_CACHE_ERROR` when MapLibre
/// fails to clear the cache.
Future<void> clearAmbientCache() => _global.clearAmbientCache();

/// Sets the size limit, in [bytes], of the ambient cache: the tiles and
/// style resources the map keeps on disk from normal browsing. The default
/// is 50 MB and `0` turns the cache off. Offline regions do not count
/// towards the limit.
///
/// Call it before the first map is created. A cache already over the new
/// limit is trimmed right away.
///
/// Throws an [ArgumentError] if [bytes] is negative, and a
/// [PlatformException] with code `AMBIENT_CACHE_ERROR` when MapLibre fails to
/// apply the limit. Android and iOS only; throws [UnsupportedError] on web.
Future<void> setMaximumAmbientCacheSize(int bytes) {
  if (bytes < 0) {
    throw ArgumentError.value(bytes, 'bytes', 'Must be 0 or more');
  }
  return _global.setMaximumAmbientCacheSize(bytes);
}

/// Resets the entire offline database: deletes every offline region and
/// clears the ambient cache. Use with care: offline regions cannot be
/// recovered afterwards.
///
/// Downloads still in progress end with an [Error] event whose code is
/// `DATABASE_RESET`. Throws a [PlatformException] with code
/// `OFFLINE_DATABASE_ERROR` when MapLibre fails to reset the database.
Future<void> resetOfflineDatabase() => _global.resetOfflineDatabase();

/// Downloads the region described by [definition] for offline use and
/// completes with it once the region is created, before its tiles are in.
///
/// [onEvent] receives the progress of the download: [InProgress] events, then
/// [Success], or [Error] with the [PlatformException] that stopped it. Its
/// code says why: see [Error].
/// [metadata] is stored with the region as [updateOfflineRegionMetadata]
/// stores it, and fails the same way when it is not JSON-encodable.
///
/// Download events reach only the root isolate: in a background isolate,
/// passing [onEvent] throws an [UnsupportedError]. Leave it out there and
/// follow the download with [getOfflineRegionStatus].
///
/// Throws a [PlatformException] with code `INVALID_REGION_DEFINITION` when
/// MapLibre cannot create a region from [definition].
Future<OfflineRegion> downloadOfflineRegion(
  OfflineRegionDefinition definition, {
  Map<String, dynamic> metadata = const {},
  Function(DownloadRegionStatus event)? onEvent,
}) => _global.downloadOfflineRegion(
  definition,
  metadata: metadata,
  onEvent: onEvent == null ? null : (event) => onEvent(event),
);
