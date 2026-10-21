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

/// A geographical location, in degrees.
class PgLatLng {
  PgLatLng({required this.latitude, required this.longitude});

  double latitude;
  double longitude;
}

/// A point of the map view, in logical pixels from its top left corner.
class PgScreenPoint {
  PgScreenPoint({required this.x, required this.y});

  double x;
  double y;
}

/// The camera of a map: the `position` map of `camera#onMove` and
/// `camera#onIdle`, whose `target` was a `[latitude, longitude]` list.
class PgCameraPosition {
  PgCameraPosition({
    required this.bearing,
    required this.target,
    required this.tilt,
    required this.zoom,
  });

  double bearing;
  PgLatLng target;
  double tilt;
  double zoom;
}

/// The compass heading of a user location update: the `heading` map of
/// `map#onUserLocationUpdated`. Only iOS sends one.
class PgUserHeading {
  PgUserHeading({
    this.magneticHeading,
    this.trueHeading,
    this.headingAccuracy,
    this.x,
    this.y,
    this.z,
    required this.timestamp,
  });

  double? magneticHeading;
  double? trueHeading;
  double? headingAccuracy;
  double? x;
  double? y;
  double? z;

  /// Milliseconds since the epoch.
  int timestamp;
}

/// A user location update: the `userLocation` map of
/// `map#onUserLocationUpdated`.
class PgUserLocation {
  PgUserLocation({
    required this.position,
    this.altitude,
    this.bearing,
    this.speed,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    required this.timestamp,
  });

  /// The legacy `position` list, `[latitude, longitude]`.
  PgLatLng position;
  double? altitude;
  double? bearing;
  double? speed;
  double? horizontalAccuracy;

  /// Absent on Android before API 26.
  double? verticalAccuracy;

  /// Milliseconds since the epoch.
  int timestamp;
}

/// A tap on a feature of an interactive layer: the arguments of
/// `feature#onTap`.
class PgFeatureTap {
  PgFeatureTap({
    this.id,
    required this.point,
    required this.latLng,
    this.layerId,
  });

  /// The feature id, as the SDK reports it.
  Object? id;

  /// The legacy `x` and `y`.
  PgScreenPoint point;

  /// The legacy `lat` and `lng`.
  PgLatLng latLng;
  String? layerId;
}

/// One step of a feature drag: the arguments of `feature#onDrag`.
class PgFeatureDrag {
  PgFeatureDrag({
    this.id,
    required this.point,
    required this.origin,
    required this.current,
    required this.delta,
    required this.eventType,
  });

  /// The feature id, as the SDK reports it.
  Object? id;

  /// The legacy `x` and `y`.
  PgScreenPoint point;

  /// The legacy `originLat` and `originLng`.
  PgLatLng origin;

  /// The legacy `currentLat` and `currentLng`.
  PgLatLng current;

  /// The legacy `deltaLat` and `deltaLng`.
  PgLatLng delta;

  /// `start`, `drag` or `end`.
  String eventType;
}

/// The calls of one map, from Dart to native. Each map has its own channels,
/// told apart by a message channel suffix: the platform view id of the map.
///
/// Every method stands for one call of the method channel these messages
/// replace, named in the first line of its documentation. Its parameters are
/// named after the keys of that call's argument map, so native can rebuild
/// the call and run it through the handler it already has. The documentation
/// notes where a key was left out of the map when null, and where the
/// arguments were not a map. Answers that Dart parses further, such as maps
/// of features or camera positions, come back as [Object] in the shape the
/// handler already answers with.
@HostApi()
abstract class MapLibreMapHostApi {
  /// map#waitForMap
  ///
  /// The legacy call had no arguments. Answers once the map is ready.
  @asyncCallback
  void mapWaitForMap();

  /// map#update
  ///
  /// Answers with the camera position map.
  @asyncCallback
  Object? mapUpdate(Map<String, Object?> options);

  /// camera#animate
  ///
  /// [duration] is in milliseconds and was sent as null when unset.
  @asyncCallback
  bool? cameraAnimate(List<Object?> cameraUpdate, int? duration);

  /// camera#move
  @asyncCallback
  bool? cameraMove(List<Object?> cameraUpdate);

  /// map#updateMyLocationTrackingMode
  ///
  /// [mode] is the index of the Dart `MyLocationTrackingMode`.
  @asyncCallback
  void mapUpdateMyLocationTrackingMode(int mode);

  /// locationComponent#setTrackingCameraOptions
  ///
  /// [duration] is in milliseconds and was sent as null when unset.
  @asyncCallback
  bool? locationComponentSetTrackingCameraOptions(double tilt, int? duration);

  /// locationComponent#setManualLocation
  ///
  /// The legacy arguments were [update] itself, not a map holding it under a
  /// key: `position` (`[latitude, longitude]`) and `timestamp` (milliseconds)
  /// always, and `horizontalAccuracy`, `verticalAccuracy`, `altitude`,
  /// `bearing` and `speed` only when set.
  @asyncCallback
  void locationComponentSetManualLocation(Map<String, Object?> update);

  /// map#matchMapLanguageWithDeviceDefault
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapMatchMapLanguageWithDeviceDefault();

  /// map#updateContentInsets
  ///
  /// [bounds] holds `top`, `left`, `bottom` and `right`.
  @asyncCallback
  void mapUpdateContentInsets(Map<String, double> bounds, bool animated);

  /// map#setMapLanguage
  @asyncCallback
  void mapSetMapLanguage(String language);

  /// map#setTelemetryEnabled
  @asyncCallback
  void mapSetTelemetryEnabled(bool enabled);

  /// map#getTelemetryEnabled
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  bool mapGetTelemetryEnabled();

  /// map#setMaximumFps
  @asyncCallback
  void mapSetMaximumFps(int fps);

  /// map#forceOnlineMode
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapForceOnlineMode();

  /// map#pause
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapPause();

  /// map#resume
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapResume();

  /// camera#ease
  ///
  /// [duration] is in milliseconds and was sent as null when unset.
  /// [interpolation] is the name of a Dart `CameraAnimationInterpolation`
  /// value, and was omitted from the legacy map when null.
  @asyncCallback
  bool cameraEase(
    List<Object?> cameraUpdate,
    int? duration,
    String? interpolation,
  );

  /// map#queryCameraPosition
  ///
  /// The legacy call had no arguments. Answers with the camera position map.
  @asyncCallback
  Object? mapQueryCameraPosition();

  /// map#editGeoJsonSource
  ///
  /// Answers with `{result: bool}`.
  @asyncCallback
  Object? mapEditGeoJsonSource(String id, String data);

  /// map#editGeoJsonUrl
  ///
  /// Answers with `{result: bool}`.
  @asyncCallback
  Object? mapEditGeoJsonUrl(String id, String url);

  /// map#setLayerFilter
  ///
  /// [filter] is the JSON string the caller passed. Answers with
  /// `{result: bool}`.
  @asyncCallback
  Object? mapSetLayerFilter(String id, String filter);

  /// map#getStyle
  ///
  /// The legacy call had no arguments. Answers with `{result: bool, json:
  /// String?}`.
  @asyncCallback
  Object? mapGetStyle();

  /// map#setCustomHeaders
  ///
  /// [filter] holds URL patterns, not a style filter.
  @asyncCallback
  void mapSetCustomHeaders(Map<String, String> headers, List<String> filter);

  /// map#getCustomHeaders
  ///
  /// The legacy arguments were an empty map. Answers with the headers map.
  @asyncCallback
  Object? mapGetCustomHeaders();

  /// map#queryRenderedFeatures
  ///
  /// The point form of the call. [filter] is the expression as a list, not
  /// encoded. Answers with `{features: [String]}`, each feature a JSON string.
  @asyncCallback
  Object? mapQueryRenderedFeaturesAtPoint(
    double x,
    double y,
    List<String> layerIds,
    List<Object?>? filter,
  );

  /// map#queryRenderedFeatures
  ///
  /// The rectangle form of the call. [filter] is the JSON string the caller
  /// passed. Answers with `{features: [String]}`, each feature a JSON string.
  @asyncCallback
  Object? mapQueryRenderedFeaturesInRect(
    double left,
    double top,
    double right,
    double bottom,
    List<String> layerIds,
    String? filter,
  );

  /// map#querySourceFeatures
  ///
  /// [filter] is the expression as a list, not encoded. Answers with
  /// `{features: [String]}`, each feature a JSON string.
  @asyncCallback
  Object? mapQuerySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object?>? filter,
  );

  /// source#getClusterExpansionZoom
  @asyncCallback
  int sourceGetClusterExpansionZoom(String sourceId, int clusterId);

  /// source#getClusterChildren
  ///
  /// Answers with `{features: [String]}`, each feature a JSON string.
  @asyncCallback
  Object? sourceGetClusterChildren(String sourceId, int clusterId);

  /// source#getClusterLeaves
  ///
  /// Answers with `{features: [String]}`, each feature a JSON string.
  @asyncCallback
  Object? sourceGetClusterLeaves(
    String sourceId,
    int clusterId,
    int limit,
    int offset,
  );

  /// map#invalidateAmbientCache
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapInvalidateAmbientCache();

  /// map#clearAmbientCache
  ///
  /// The legacy call had no arguments.
  @asyncCallback
  void mapClearAmbientCache();

  /// locationComponent#getLastLocation
  ///
  /// The legacy call had no arguments. Answers with `{latitude, longitude}`,
  /// or null when there is no location.
  @asyncCallback
  Object? locationComponentGetLastLocation();

  /// map#getVisibleRegion
  ///
  /// The legacy call had no arguments. Answers with `{sw: [latitude,
  /// longitude], ne: [latitude, longitude]}`.
  @asyncCallback
  Object? mapGetVisibleRegion();

  /// style#addImage
  ///
  /// [length] is the length of [bytes].
  @asyncCallback
  void styleAddImage(String name, Uint8List bytes, int length, bool sdf);

  /// style#addImageSource
  ///
  /// [length] is the length of [bytes]. [coordinates] holds the four corners,
  /// each a `[latitude, longitude]` list.
  @asyncCallback
  void styleAddImageSource(
    String imageSourceId,
    Uint8List bytes,
    int length,
    List<Object?> coordinates,
  );

  /// style#updateImageSource
  ///
  /// [length] is the length of [bytes]. [coordinates] holds the four corners,
  /// each a `[latitude, longitude]` list. The null ones were sent as null.
  @asyncCallback
  void styleUpdateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    int? length,
    List<Object?>? coordinates,
  );

  /// map#toScreenLocation
  ///
  /// Answers with `{x, y}`.
  @asyncCallback
  Object? mapToScreenLocation(double latitude, double longitude);

  /// map#toScreenLocationBatch
  ///
  /// [coordinates] holds latitude and longitude pairs, one after the other.
  /// Answers with x and y pairs in the same order.
  @asyncCallback
  Float64List mapToScreenLocationBatch(Float64List coordinates);

  /// style#removeSource
  @asyncCallback
  void styleRemoveSource(String sourceId);

  /// style#addLayer
  @asyncCallback
  void styleAddLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  );

  /// style#addLayerBelow
  @asyncCallback
  void styleAddLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  );

  /// style#removeLayer
  @asyncCallback
  void styleRemoveLayer(String layerId);

  /// style#moveLayer
  ///
  /// [belowLayerId] was omitted from the legacy map when null.
  @asyncCallback
  void styleMoveLayer(String layerId, String? belowLayerId);

  /// style#setFilter
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void styleSetFilter(String layerId, String filter);

  /// style#getFilter
  ///
  /// Answers with `{filter: String?}`, the expression as a JSON string.
  @asyncCallback
  Object? styleGetFilter(String layerId);

  /// map#toLatLng
  ///
  /// Answers with `{latitude, longitude}`.
  @asyncCallback
  Object? mapToLatLng(double x, double y);

  /// map#getMetersPerPixelAtLatitude
  ///
  /// Answers with `{metersperpixel: double}`.
  @asyncCallback
  Object? mapGetMetersPerPixelAtLatitude(double latitude);

  /// source#addGeoJson
  ///
  /// [geojson] is the data encoded by Dart.
  @asyncCallback
  void sourceAddGeoJson(String sourceId, String geojson);

  /// source#setGeoJson
  ///
  /// [geojson] is the data encoded by Dart.
  @asyncCallback
  void sourceSetGeoJson(String sourceId, String geojson);

  /// map#setCameraBounds
  @asyncCallback
  void mapSetCameraBounds(
    double west,
    double north,
    double south,
    double east,
    int padding,
  );

  /// symbolLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void symbolLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// lineLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void lineLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// layer#setProperties
  @asyncCallback
  void layerSetProperties(String layerId, Map<String, Object?> properties);

  /// circleLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void circleLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// fillLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void fillLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// fillExtrusionLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void fillExtrusionLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// style#addSource
  ///
  /// [properties] is the source in style-spec form.
  @asyncCallback
  void styleAddSource(String sourceId, Map<String, Object?> properties);

  /// rasterLayer#add
  @asyncCallback
  void rasterLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// hillshadeLayer#add
  @asyncCallback
  void hillshadeLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// colorReliefLayer#add
  @asyncCallback
  void colorReliefLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// backgroundLayer#add
  @asyncCallback
  void backgroundLayerAdd(
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// heatmapLayer#add
  ///
  /// [filter] is the expression encoded by Dart, the string `null` when there
  /// is none.
  @asyncCallback
  void heatmapLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String filter,
    Map<String, Object?> properties,
  );

  /// source#setFeature
  ///
  /// [geojsonFeature] is the feature encoded by Dart.
  @asyncCallback
  void sourceSetFeature(String sourceId, String geojsonFeature);

  /// source#setFeatureState
  ///
  /// Android only: Dart rejects the call on iOS before sending it.
  @asyncCallback
  void sourceSetFeatureState(
    String sourceId,
    String featureId,
    Map<String, Object?> state,
    String? sourceLayer,
  );

  /// source#removeFeatureState
  ///
  /// Android only: Dart rejects the call on iOS before sending it.
  @asyncCallback
  void sourceRemoveFeatureState(
    String sourceId,
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  );

  /// source#getFeatureState
  ///
  /// Android only: Dart rejects the call on iOS before sending it. Answers
  /// with `{state: String?}`, the state as a JSON string.
  @asyncCallback
  Object? sourceGetFeatureState(
    String sourceId,
    String featureId,
    String? sourceLayer,
  );

  /// style#setLight
  ///
  /// [light] is the light in style-spec form.
  @asyncCallback
  void styleSetLight(Map<String, Object?> light);

  /// layer#setVisibility
  @asyncCallback
  void layerSetVisibility(String layerId, bool visible);

  /// layer#setVisibilityBatch
  ///
  /// Answers with the ids that matched no layer.
  @asyncCallback
  List<String>? layerSetVisibilityBatch(List<String> layerIds, bool visible);

  /// layer#setZoomRange
  @asyncCallback
  void layerSetZoomRange(String layerId, double minzoom, double maxzoom);

  /// layer#getVisibility
  ///
  /// Answers with null when there is no such layer.
  @asyncCallback
  bool? layerGetVisibility(String layerId);

  /// map#takeSnapshot
  ///
  /// [width] and [height] are in logical pixels, and each was omitted from
  /// the legacy map when null. Answers with PNG bytes.
  @asyncCallback
  Uint8List? mapTakeSnapshot(int? width, int? height);

  /// style#getLayerIds
  ///
  /// The legacy call had no arguments. Answers with `{layers: [String]}`.
  @asyncCallback
  Object? styleGetLayerIds();

  /// style#getSourceIds
  ///
  /// The legacy call had no arguments. Answers with `{sources: [String]}`.
  @asyncCallback
  Object? styleGetSourceIds();

  /// style#getLayerProperties
  ///
  /// Answers with `{properties: String}`, the layer as a JSON string, or
  /// without `properties` when there is no such layer.
  @asyncCallback
  Object? styleGetLayerProperties(String layerId);

  /// style#getSourceProperties
  ///
  /// Answers with `{properties: String}`, the source as a JSON string, or
  /// without `properties` when there is no such source.
  @asyncCallback
  Object? styleGetSourceProperties(String sourceId);

  /// style#setStyle
  @asyncCallback
  void styleSetStyle(String style);
}

/// The events of one map, from native to Dart, on channels told apart by the
/// same suffix as [MapLibreMapHostApi].
///
/// Every method stands for one call native made on the method channel these
/// messages replace, named in the first line of its documentation.
@FlutterApi()
abstract class MapLibreMapFlutterApi {
  /// feature#onTap
  @asyncCallback
  void featureOnTap(PgFeatureTap tap);

  /// feature#onDrag
  @asyncCallback
  void featureOnDrag(PgFeatureDrag drag);

  /// camera#onMoveStarted
  @asyncCallback
  void cameraOnMoveStarted();

  /// camera#onMove
  @asyncCallback
  void cameraOnMove(PgCameraPosition position);

  /// camera#onIdle
  ///
  /// [position] is null when the map does not track the camera position.
  @asyncCallback
  void cameraOnIdle(PgCameraPosition? position);

  /// map#onStyleLoaded
  @asyncCallback
  void mapOnStyleLoaded();

  /// map#onMapClick
  ///
  /// [point] is the legacy `x` and `y`, [latLng] the legacy `lat` and `lng`.
  @asyncCallback
  void mapOnMapClick(PgScreenPoint point, PgLatLng latLng);

  /// map#onMapLongClick
  ///
  /// [point] is the legacy `x` and `y`, [latLng] the legacy `lat` and `lng`.
  @asyncCallback
  void mapOnMapLongClick(PgScreenPoint point, PgLatLng latLng);

  /// map#onCameraTrackingChanged
  ///
  /// [mode] is the index of the Dart `MyLocationTrackingMode`.
  @asyncCallback
  void mapOnCameraTrackingChanged(int mode);

  /// map#onCameraTrackingDismissed
  @asyncCallback
  void mapOnCameraTrackingDismissed();

  /// map#onIdle
  @asyncCallback
  void mapOnIdle();

  /// map#onUserLocationUpdated
  @asyncCallback
  void mapOnUserLocationUpdated(
    PgUserLocation userLocation,
    PgUserHeading? heading,
  );
}
