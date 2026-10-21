// Schema of the messages between the Dart side of maplibre_gl and its Android
// and iOS implementations. Pigeon generates the Dart, Kotlin and Swift code
// from it; run `melos run generate:pigeon` after any change and commit the
// generated files with it.
//
// Payloads that are style-spec JSON or user data (offline region definitions
// and metadata) cross as maps or JSON strings, exactly as they did over the
// hand-written method channels, so both platforms keep reading them with the
// code they already have.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'maplibre_gl',
    dartOut: 'lib/src/native/messages.g.dart',
    kotlinOut: 'android/src/main/java/org/maplibre/maplibregl/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'org.maplibre.maplibregl',
      errorClassName: 'PigeonError',
    ),
    swiftOut: 'ios/maplibre_gl/Sources/maplibre_gl/Messages.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'PigeonError'),
  ),
)
/// Where an offline region download stands.
enum PgOfflineDownloadStatus { start, progress, success, error }

/// One event of an offline region download, sent for the download started
/// with the same `downloadId`.
class PgOfflineDownloadEvent {
  PgOfflineDownloadEvent({
    required this.status,
    this.progress,
    this.completedResourceCount,
    this.requiredResourceCount,
    this.completedResourceSize,
    this.errorCode,
    this.errorMessage,
    this.errorDetails,
  });

  PgOfflineDownloadStatus status;

  /// Percentage, 0 to 100, for [PgOfflineDownloadStatus.progress].
  double? progress;
  int? completedResourceCount;
  int? requiredResourceCount;
  int? completedResourceSize;

  /// Set for [PgOfflineDownloadStatus.error].
  String? errorCode;
  String? errorMessage;
  Object? errorDetails;
}

/// Operations that belong to the plugin rather than to one map.
@HostApi()
abstract class MapLibreGlobalHostApi {
  void preWarm();

  void installOfflineMapTiles(String tilesDb);

  /// Android only; iOS answers `UNSUPPORTED`.
  void setOffline(bool offline);

  @asyncCallback
  void setHttpHeaders(Map<String, String> headers);

  /// The merged regions as a JSON array.
  @asyncCallback
  String mergeOfflineRegions(String path);

  String? getOfflineDatabasePath();

  /// The stored regions as a JSON array.
  @asyncCallback
  String getListOfRegions();

  /// The updated region as a JSON object.
  @asyncCallback
  String updateOfflineRegionMetadata(int id, Map<String, Object?> metadata);

  @asyncCallback
  void setOfflineTileCountLimit(int limit);

  @asyncCallback
  void setOfflineMaxConcurrentRequests(
    int? maxRequests,
    int? maxRequestsPerHost,
  );

  @asyncCallback
  void pauseOfflineRegionDownload(int id);

  @asyncCallback
  void resumeOfflineRegionDownload(int id);

  /// The status as a JSON object.
  @asyncCallback
  String getOfflineRegionStatus(int id);

  @asyncCallback
  void deleteOfflineRegion(int id);

  @asyncCallback
  void clearAmbientCache();

  @asyncCallback
  void setMaximumAmbientCacheSize(int bytes);

  @asyncCallback
  void resetOfflineDatabase();

  /// Starts downloading a region and answers with it as a JSON object once it
  /// is created. Its progress arrives through
  /// [MapLibreOfflineDownloadFlutterApi.onDownloadEvent] with [downloadId].
  @asyncCallback
  String downloadOfflineRegion(
    int downloadId,
    Map<String, Object?> definition,
    Map<String, Object?> metadata,
  );
}

/// Offline download events, from native to Dart.
@FlutterApi()
abstract class MapLibreOfflineDownloadFlutterApi {
  @asyncCallback
  void onDownloadEvent(int downloadId, PgOfflineDownloadEvent event);
}
