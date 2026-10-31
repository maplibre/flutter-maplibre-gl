// Schema of the messages between the Dart side of maplibre_gl and its Android
// and iOS implementations. Pigeon generates the Dart, Kotlin and Swift code
// from it; run `melos run generate:pigeon` after any change and commit the
// generated files with it.
//
// Conventions of the map messages:
// - Geographical coordinates are degrees, in a PgLatLng.
// - Screen points, offsets and distances are logical pixels (points on iOS,
//   density independent pixels on Android), x to the right and y down from
//   the top left corner of the map view.
// - Durations are milliseconds.
// - Colors are 32-bit ARGB values, as Dart `Color.toARGB32` gives them.
// - Enums keep the order of the Dart enum they stand for, so their raw
//   values are the indices of that enum.
// - A style filter is the JSON text of its expression. Null means no filter,
//   and so does the JSON text `null`.
// - Features are GeoJSON Feature objects, each one as its own JSON text, so
//   nested properties keep their exact shape.
//
// Some payloads stay maps or JSON text because their values are style data
// of no fixed shape: layer and source properties (style-spec values, any of
// which can be an expression), the light, feature state (app data), styles,
// and the offline region definitions and metadata. Native hands them to the
// converters it already has for style-spec data.
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

/// A rectangle of latitudes and longitudes, given by two of its corners.
class PgLatLngBounds {
  PgLatLngBounds({required this.southwest, required this.northeast});

  PgLatLng southwest;
  PgLatLng northeast;
}

/// Four geographical corners, which need not form a rectangle: where an
/// image source is drawn.
class PgLatLngQuad {
  PgLatLngQuad({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  PgLatLng topLeft;
  PgLatLng topRight;
  PgLatLng bottomRight;
  PgLatLng bottomLeft;
}

/// A point of the map view, or an offset on screen, in logical pixels: x to
/// the right and y down, from the top left corner of the map view for a
/// point.
class PgScreenPoint {
  PgScreenPoint({required this.x, required this.y});

  double x;
  double y;
}

/// A space along each edge of the map view, in logical pixels.
class PgEdgeInsets {
  PgEdgeInsets({
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });

  double top;
  double left;
  double bottom;
  double right;
}

/// The camera of a map.
class PgCameraPosition {
  PgCameraPosition({
    required this.bearing,
    required this.target,
    required this.tilt,
    required this.zoom,
  });

  /// Degrees clockwise from north.
  double bearing;

  /// The location at the center of the map view.
  PgLatLng target;

  /// Degrees from the nadir.
  double tilt;

  /// The zoom level.
  double zoom;
}

/// A change of the camera, one subclass per kind. Native reads it against
/// the camera the map has when the call arrives.
sealed class PgCameraUpdate {}

/// Moves the camera to [cameraPosition].
class PgCameraUpdateNewCameraPosition extends PgCameraUpdate {
  PgCameraUpdateNewCameraPosition({required this.cameraPosition});

  PgCameraPosition cameraPosition;
}

/// Centers the camera on [latLng], keeping the zoom, bearing and tilt.
class PgCameraUpdateNewLatLng extends PgCameraUpdate {
  PgCameraUpdateNewLatLng({required this.latLng});

  PgLatLng latLng;
}

/// Fits [bounds] in the map view inset by [padding], at the greatest zoom
/// that shows them whole, keeping the bearing and tilt. The padding adds to
/// the content insets of the map and does not stay on after the move.
class PgCameraUpdateNewLatLngBounds extends PgCameraUpdate {
  PgCameraUpdateNewLatLngBounds({required this.bounds, required this.padding});

  PgLatLngBounds bounds;
  PgEdgeInsets padding;
}

/// Centers the camera on [latLng] at [zoom], keeping the bearing and tilt.
class PgCameraUpdateNewLatLngZoom extends PgCameraUpdate {
  PgCameraUpdateNewLatLngZoom({required this.latLng, required this.zoom});

  PgLatLng latLng;
  double zoom;
}

/// Pans the view by [dx] and [dy] logical pixels: a positive [dx] moves the
/// view east and a positive [dy] south, for a camera facing north.
class PgCameraUpdateScrollBy extends PgCameraUpdate {
  PgCameraUpdateScrollBy({required this.dx, required this.dy});

  double dx;
  double dy;
}

/// Changes the zoom by [amount]. With a [focus], the location under that
/// point of the map view stays where it is on screen.
class PgCameraUpdateZoomBy extends PgCameraUpdate {
  PgCameraUpdateZoomBy({required this.amount, this.focus});

  double amount;
  PgScreenPoint? focus;
}

/// Zooms in by one level.
class PgCameraUpdateZoomIn extends PgCameraUpdate {
  PgCameraUpdateZoomIn();
}

/// Zooms out by one level.
class PgCameraUpdateZoomOut extends PgCameraUpdate {
  PgCameraUpdateZoomOut();
}

/// Sets the zoom level to [zoom].
class PgCameraUpdateZoomTo extends PgCameraUpdate {
  PgCameraUpdateZoomTo({required this.zoom});

  double zoom;
}

/// Sets the bearing to [bearing] degrees clockwise from north.
class PgCameraUpdateBearingTo extends PgCameraUpdate {
  PgCameraUpdateBearingTo({required this.bearing});

  double bearing;
}

/// Sets the tilt to [tilt] degrees from the nadir, keeping the zoom.
class PgCameraUpdateTiltTo extends PgCameraUpdate {
  PgCameraUpdateTiltTo({required this.tilt});

  double tilt;
}

/// The timing curve of an eased camera move, the Dart
/// `CameraAnimationInterpolation`. Android tells only [linear] apart: the
/// others ease in and out there.
enum PgCameraAnimationInterpolation {
  linear,
  easeInOut,
  easeOut,
  fastOutLinearIn,
}

/// How the camera follows the user location, the Dart
/// `MyLocationTrackingMode`. The raw values are those of iOS
/// `MLNUserTrackingMode`; on Android the cases match, in order, the camera
/// modes NONE, TRACKING, TRACKING_COMPASS and TRACKING_GPS.
enum PgMyLocationTrackingMode { none, tracking, trackingCompass, trackingGps }

/// How the user location is drawn, the Dart `MyLocationRenderMode`.
enum PgMyLocationRenderMode { normal, compass, gps }

/// A corner of the map view, for the logo, the compass and the attribution
/// button. The raw values are those of iOS `MLNOrnamentPosition`.
enum PgOrnamentPosition { topLeft, topRight, bottomLeft, bottomRight }

/// How long the map glides after a pan, the Dart `PanInertia`.
enum PgPanInertia { none, short, normal }

/// The Android location priority, the Dart `LocationPriority`. The raw values
/// are those of the `LocationEngineRequest` priorities.
enum PgLocationPriority { highAccuracy, balanced, lowPower, noPower }

/// Where the user location comes from: the platform location engine, or the
/// app through [MapLibreMapHostApi.locationComponentSetManualLocation].
enum PgLocationSource { platform, manual }

/// Bounds for the camera target. Null [bounds] lift the restriction, which
/// is not the same as leaving this option out.
class PgCameraTargetBounds {
  PgCameraTargetBounds({this.bounds});

  PgLatLngBounds? bounds;
}

/// The zoom range of the camera. A null end leaves that side unbounded, which
/// is not the same as leaving this option out.
class PgMinMaxZoomPreference {
  PgMinMaxZoomPreference({this.minZoom, this.maxZoom});

  double? minZoom;
  double? maxZoom;
}

/// The colors of the user location puck, the Dart `MyLocationStyle`. A null
/// color keeps the platform default.
class PgMyLocationStyle {
  PgMyLocationStyle({
    this.fillColor,
    this.bearingColor,
    this.accuracyColor,
    required this.accuracyCircleEnabled,
    this.pulseEnabled,
    this.pulseColor,
  });

  int? fillColor;
  int? bearingColor;

  /// Only its red, green and blue channels are used.
  int? accuracyColor;
  bool accuracyCircleEnabled;

  /// Null keeps the platform default.
  bool? pulseEnabled;
  int? pulseColor;
}

/// The settings of the platform location engine. Dart fills only the fields
/// of the platform it runs on: on Android [interval], [priority] and
/// [displacement], on iOS [enableHighAccuracy], [displacement], [intervalMs]
/// and [pulseWindowMs].
class PgLocationEngineProperties {
  PgLocationEngineProperties({
    this.interval,
    this.priority,
    this.displacement,
    this.enableHighAccuracy,
    this.intervalMs,
    this.pulseWindowMs,
  });

  /// Android: milliseconds between location updates.
  int? interval;

  /// Android.
  PgLocationPriority? priority;

  /// Meters the device moves before an update. iOS reads it as the distance
  /// filter.
  int? displacement;

  /// iOS: the best accuracy rather than a hundred meters.
  bool? enableHighAccuracy;

  /// iOS: milliseconds between two GPS pulses, 0 for continuous updates.
  int? intervalMs;

  /// iOS: milliseconds the GPS stays on in each pulse.
  int? pulseWindowMs;
}

/// The options of a map. On creation a null field keeps the platform
/// default; in [MapLibreMapHostApi.mapUpdate] it leaves the option as it is,
/// as Dart sends only the options that changed. Web-only options are not
/// sent.
class PgMapOptions {
  PgMapOptions({
    this.compassEnabled,
    this.cameraTargetBounds,
    this.styleString,
    this.minMaxZoomPreference,
    this.rotateGesturesEnabled,
    this.scrollGesturesEnabled,
    this.tiltGesturesEnabled,
    this.zoomGesturesEnabled,
    this.doubleClickZoomEnabled,
    this.panInertia,
    this.hapticFeedbackEnabled,
    this.trackCameraPosition,
    this.myLocationEnabled,
    this.myLocationTrackingMode,
    this.myLocationRenderMode,
    this.myLocationStyle,
    this.logoEnabled,
    this.logoViewPosition,
    this.logoViewMargins,
    this.compassViewPosition,
    this.compassViewMargins,
    this.attributionEnabled,
    this.attributionButtonPosition,
    this.attributionButtonMargins,
    this.attributionButtonColor,
    this.locationEngineProperties,
    this.locationSource,
    this.foregroundLoadColor,
    this.translucentTextureSurface,
    this.featureTapsTriggersMapClick,
    this.symbolPlacementTransitionsEnabled,
  });

  bool? compassEnabled;
  PgCameraTargetBounds? cameraTargetBounds;

  /// A style JSON, URL, file path or asset name.
  String? styleString;
  PgMinMaxZoomPreference? minMaxZoomPreference;
  bool? rotateGesturesEnabled;
  bool? scrollGesturesEnabled;
  bool? tiltGesturesEnabled;
  bool? zoomGesturesEnabled;
  bool? doubleClickZoomEnabled;
  PgPanInertia? panInertia;

  /// iOS only.
  bool? hapticFeedbackEnabled;

  /// Whether the camera events and [MapLibreMapHostApi.mapUpdate] report the
  /// camera position.
  bool? trackCameraPosition;
  bool? myLocationEnabled;
  PgMyLocationTrackingMode? myLocationTrackingMode;
  PgMyLocationRenderMode? myLocationRenderMode;
  PgMyLocationStyle? myLocationStyle;
  bool? logoEnabled;
  PgOrnamentPosition? logoViewPosition;

  /// The horizontal and vertical margins, in logical pixels.
  PgScreenPoint? logoViewMargins;
  PgOrnamentPosition? compassViewPosition;

  /// The horizontal and vertical margins, in logical pixels.
  PgScreenPoint? compassViewMargins;
  bool? attributionEnabled;
  PgOrnamentPosition? attributionButtonPosition;

  /// The horizontal and vertical margins, in logical pixels.
  PgScreenPoint? attributionButtonMargins;

  /// ARGB.
  int? attributionButtonColor;
  PgLocationEngineProperties? locationEngineProperties;
  PgLocationSource? locationSource;

  /// Android only, ARGB.
  int? foregroundLoadColor;

  /// Android only.
  bool? translucentTextureSurface;
  bool? featureTapsTriggersMapClick;
  bool? symbolPlacementTransitionsEnabled;
}

/// What Dart hands the platform view of a map when it creates it, encoded
/// with the codec of these messages (`MapLibreMapHostApi.pigeonChannelCodec`
/// in Dart). The native platform view factories decode it with the same
/// generated codec.
class PgCreationParams {
  PgCreationParams({
    this.styleString,
    required this.options,
    this.initialCameraPosition,
    required this.dragEnabled,
    this.iosLongClickDurationMs,
    required this.textureLayer,
  });

  /// The style to create the map with: a style JSON, URL, file path or asset
  /// name. [options] carries the same value.
  String? styleString;

  /// The initial options.
  PgMapOptions options;

  /// Null leaves the camera to the style, or to the platform default.
  PgCameraPosition? initialCameraPosition;

  /// Whether the features of interactive layers can be dragged.
  bool dragEnabled;

  /// iOS only: how long a press lasts before it is a long click, in
  /// milliseconds. Null keeps the platform default.
  int? iosLongClickDurationMs;

  /// Android only: whether the app asked for the texture layer
  /// (`AndroidViewMode.textureLayer` in the plugin), which renders the map
  /// into a `TextureView`. `translucentTextureSurface` in [options] does too.
  /// Always false on iOS.
  bool textureLayer;
}

/// The update [MapLibreMapHostApi.locationComponentSetManualLocation] makes
/// the user location.
class PgManualLocationUpdate {
  PgManualLocationUpdate({
    required this.position,
    required this.timestamp,
    this.horizontalAccuracy,
    this.verticalAccuracy,
    this.altitude,
    this.bearing,
    this.speed,
  });

  PgLatLng position;

  /// Milliseconds since the epoch. Dart sends the time of the call when the
  /// app gives none.
  int timestamp;

  /// Meters. Null when unknown, as are the fields below.
  double? horizontalAccuracy;

  /// Meters.
  double? verticalAccuracy;

  /// Meters.
  double? altitude;

  /// The direction of travel, in degrees clockwise from north.
  double? bearing;

  /// Meters per second.
  double? speed;
}

/// The compass heading of a user location update. Only iOS sends one.
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

/// A user location update.
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

/// A tap on a feature of an interactive layer.
class PgFeatureTap {
  PgFeatureTap({
    this.id,
    required this.point,
    required this.latLng,
    this.layerId,
  });

  /// The feature id, as the SDK reports it.
  Object? id;

  /// Where the tap landed on the map view.
  PgScreenPoint point;

  /// Where the tap landed on the map.
  PgLatLng latLng;
  String? layerId;
}

/// One step of a feature drag.
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

  /// Where the finger is on the map view.
  PgScreenPoint point;

  /// Where the drag started on the map.
  PgLatLng origin;

  /// Where the finger is on the map.
  PgLatLng current;

  /// How far the finger moved since the previous step, in degrees.
  PgLatLng delta;

  /// `start`, `drag` or `end`.
  String eventType;
}

/// The calls of one map, from Dart to native. Each map has its own channels,
/// told apart by a message channel suffix: the platform view id of the map.
///
/// Every method answers once its work is done, or fails with the error code
/// native reports. See the top of this file for the units, the filters and
/// the features.
@HostApi()
abstract class MapLibreMapHostApi {
  /// Answers once the native map is ready for the other calls.
  @asyncCallback
  void mapWaitForMap();

  /// Applies the options that are set and answers with the camera position,
  /// or with null when the map does not track the camera position.
  @asyncCallback
  PgCameraPosition? mapUpdate(PgMapOptions options);

  /// Animates the camera to [cameraUpdate] over [duration] milliseconds, or
  /// over the platform default when it is null. Answers whether the move
  /// finished, false when something cut it short.
  @asyncCallback
  bool? cameraAnimate(PgCameraUpdate cameraUpdate, int? duration);

  /// Moves the camera to [cameraUpdate] at once. Answers whether the move
  /// finished.
  @asyncCallback
  bool? cameraMove(PgCameraUpdate cameraUpdate);

  /// Sets how the camera follows the user location.
  @asyncCallback
  void mapUpdateMyLocationTrackingMode(PgMyLocationTrackingMode mode);

  /// Tilts the camera to [tilt] degrees while it tracks the user location,
  /// without ending the tracking, over [duration] milliseconds or the
  /// platform default when it is null. Answers whether the tilt landed.
  @asyncCallback
  bool? locationComponentSetTrackingCameraOptions(double tilt, int? duration);

  /// Makes [update] the user location, for a map whose location source is
  /// [PgLocationSource.manual].
  @asyncCallback
  void locationComponentSetManualLocation(PgManualLocationUpdate update);

  /// Shows the labels of the map in the language of the device.
  @asyncCallback
  void mapMatchMapLanguageWithDeviceDefault();

  /// Sets the content insets of the map, the space along its edges that the
  /// camera keeps clear, animated or not.
  @asyncCallback
  void mapUpdateContentInsets(PgEdgeInsets insets, bool animated);

  /// Shows the labels of the map in [language], an ISO language code.
  @asyncCallback
  void mapSetMapLanguage(String language);

  /// Turns telemetry on or off where the SDK has it.
  @asyncCallback
  void mapSetTelemetryEnabled(bool enabled);

  /// Answers whether telemetry is on.
  @asyncCallback
  bool mapGetTelemetryEnabled();

  /// Caps the frame rate of the map at [fps].
  @asyncCallback
  void mapSetMaximumFps(int fps);

  /// Tells the map it is online, so it loads from the network again. Android
  /// only: iOS has nothing to do.
  @asyncCallback
  void mapForceOnlineMode();

  /// Stops the rendering and the location updates of the map.
  @asyncCallback
  void mapPause();

  /// Starts again what [mapPause] stopped.
  @asyncCallback
  void mapResume();

  /// Eases the camera to [cameraUpdate] over [duration] milliseconds, or over
  /// the platform default when it is null or not positive, along
  /// [interpolation], or the platform default curve when it is null. Answers
  /// whether the move finished.
  @asyncCallback
  bool cameraEase(
    PgCameraUpdate cameraUpdate,
    int? duration,
    PgCameraAnimationInterpolation? interpolation,
  );

  /// Answers with the current camera position.
  @asyncCallback
  PgCameraPosition mapQueryCameraPosition();

  /// Replaces the data of the GeoJSON source [id] with [data], GeoJSON text.
  /// Answers whether it did, false when there is no style or no such GeoJSON
  /// source, or when the SDK rejects the data.
  @asyncCallback
  bool mapEditGeoJsonSource(String id, String data);

  /// Points the GeoJSON source [id] at [url]. Answers whether it did, false
  /// when there is no style or no such GeoJSON source, or when the SDK
  /// rejects the URL.
  @asyncCallback
  bool mapEditGeoJsonUrl(String id, String url);

  /// Sets [filter], the JSON text of an expression, on the layer [id].
  /// Answers whether it did, false when there is no style or no such layer,
  /// when the layer takes no filter, or when the filter does not parse.
  @asyncCallback
  bool mapSetLayerFilter(String id, String filter);

  /// Answers with the style of the map as JSON text, or with null when the
  /// map has no style.
  @asyncCallback
  String? mapGetStyle();

  /// Adds [headers] to the requests of the map whose URL matches one of the
  /// patterns in [filter], or to every request when [filter] is empty.
  @asyncCallback
  void mapSetCustomHeaders(Map<String, String> headers, List<String> filter);

  /// Answers with the headers [mapSetCustomHeaders] set.
  @asyncCallback
  Map<String, String> mapGetCustomHeaders();

  /// Answers with the features rendered at the point [x], [y] of the map
  /// view, on the layers [layerIds] or on all of them when it is empty, that
  /// match [filter].
  @asyncCallback
  List<String> mapQueryRenderedFeaturesAtPoint(
    double x,
    double y,
    List<String> layerIds,
    String? filter,
  );

  /// Answers with the features rendered in the rectangle of the map view
  /// from [left], [top] to [right], [bottom], on the layers [layerIds] or on
  /// all of them when it is empty, that match [filter].
  @asyncCallback
  List<String> mapQueryRenderedFeaturesInRect(
    double left,
    double top,
    double right,
    double bottom,
    List<String> layerIds,
    String? filter,
  );

  /// Answers with the features of the source [sourceId], in its layer
  /// [sourceLayerId] for a vector source, that match [filter], rendered or
  /// not. A vector source without [sourceLayerId], or a source of another
  /// kind, answers none.
  @asyncCallback
  List<String> mapQuerySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    String? filter,
  );

  /// Answers with the zoom at which the cluster [clusterId] of the GeoJSON
  /// source [sourceId] splits.
  @asyncCallback
  int sourceGetClusterExpansionZoom(String sourceId, int clusterId);

  /// Answers with the features one zoom level below the cluster [clusterId]
  /// of the GeoJSON source [sourceId].
  @asyncCallback
  List<String> sourceGetClusterChildren(String sourceId, int clusterId);

  /// Answers with the points of the cluster [clusterId] of the GeoJSON source
  /// [sourceId], [limit] of them after skipping [offset].
  @asyncCallback
  List<String> sourceGetClusterLeaves(
    String sourceId,
    int clusterId,
    int limit,
    int offset,
  );

  /// Marks the ambient cache as stale, so it is checked against the network.
  @asyncCallback
  void mapInvalidateAmbientCache();

  /// Empties the ambient cache.
  @asyncCallback
  void mapClearAmbientCache();

  /// Answers with the last known user location. Fails when there is none or
  /// the location is off.
  @asyncCallback
  PgLatLng locationComponentGetLastLocation();

  /// Answers with the region the map view shows.
  @asyncCallback
  PgLatLngBounds mapGetVisibleRegion();

  /// Adds the image [bytes] to the style as [name], as a signed distance
  /// field image when [sdf] is true. [length] is the length of [bytes].
  /// [pixelRatio] is the number of image pixels per logical pixel, or null for
  /// the screen density.
  @asyncCallback
  void styleAddImage(
    String name,
    Uint8List bytes,
    int length,
    bool sdf,
    double? pixelRatio,
  );

  /// Adds an image source [imageSourceId] that draws the image [bytes] on
  /// [coordinates]. [length] is the length of [bytes].
  @asyncCallback
  void styleAddImageSource(
    String imageSourceId,
    Uint8List bytes,
    int length,
    PgLatLngQuad coordinates,
  );

  /// Changes the image, the corners, or both, of the image source
  /// [imageSourceId]. What is null stays as it is. [length] is the length of
  /// [bytes].
  @asyncCallback
  void styleUpdateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    int? length,
    PgLatLngQuad? coordinates,
  );

  /// Answers with where the location [latitude], [longitude] is on the map
  /// view.
  @asyncCallback
  PgScreenPoint mapToScreenLocation(double latitude, double longitude);

  /// The batch form of [mapToScreenLocation]: [coordinates] holds latitude
  /// and longitude pairs one after the other, and the answer holds the x and
  /// y of each in the same order.
  @asyncCallback
  Float64List mapToScreenLocationBatch(Float64List coordinates);

  /// Removes the source [sourceId] from the style.
  @asyncCallback
  void styleRemoveSource(String sourceId);

  /// Adds a raster layer [imageLayerId] that draws the source
  /// [imageSourceId], on top of the others.
  @asyncCallback
  void styleAddLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  );

  /// Adds a raster layer [imageLayerId] that draws the source
  /// [imageSourceId], below the layer [belowLayerId].
  @asyncCallback
  void styleAddLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  );

  /// Removes the layer [layerId] from the style.
  @asyncCallback
  void styleRemoveLayer(String layerId);

  /// Moves the layer [layerId] below the layer [belowLayerId], or on top of
  /// the others when it is null.
  @asyncCallback
  void styleMoveLayer(String layerId, String? belowLayerId);

  /// Sets [filter] on the layer [layerId], or removes its filter when
  /// [filter] is null.
  @asyncCallback
  void styleSetFilter(String layerId, String? filter);

  /// Answers with the filter of the layer [layerId] as JSON text, or with
  /// null when it has none.
  @asyncCallback
  String? styleGetFilter(String layerId);

  /// Answers with the location at the point [x], [y] of the map view.
  @asyncCallback
  PgLatLng mapToLatLng(double x, double y);

  /// Answers with the meters per pixel at [latitude] at the current zoom, as
  /// the SDK reports them.
  @asyncCallback
  double mapGetMetersPerPixelAtLatitude(double latitude);

  /// Adds a GeoJSON source [sourceId] holding [geojson], GeoJSON text.
  @asyncCallback
  void sourceAddGeoJson(String sourceId, String geojson);

  /// Replaces the data of the GeoJSON source [sourceId] with [geojson],
  /// GeoJSON text.
  @asyncCallback
  void sourceSetGeoJson(String sourceId, String geojson);

  /// Eases the camera to the bounds from [west], [south] to [east], [north],
  /// inset by [padding] logical pixels. Answers once the move starts.
  @asyncCallback
  void mapSetCameraBounds(
    double west,
    double north,
    double south,
    double east,
    int padding,
  );

  /// Adds a symbol layer. [properties] are its paint and layout properties
  /// in style-spec form. [enableInteraction] makes its features report taps
  /// and drags.
  @asyncCallback
  void symbolLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// Adds a line layer, as [symbolLayerAdd].
  @asyncCallback
  void lineLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// Sets the paint and layout [properties], in style-spec form, of the
  /// layer [layerId].
  @asyncCallback
  void layerSetProperties(String layerId, Map<String, Object?> properties);

  /// Adds a circle layer, as [symbolLayerAdd].
  @asyncCallback
  void circleLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// Adds a fill layer, as [symbolLayerAdd].
  @asyncCallback
  void fillLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// Adds a fill extrusion layer, as [symbolLayerAdd].
  @asyncCallback
  void fillExtrusionLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    bool enableInteraction,
    Map<String, Object?> properties,
  );

  /// Adds the source [sourceId]. [properties] is the source in style-spec
  /// form.
  @asyncCallback
  void styleAddSource(String sourceId, Map<String, Object?> properties);

  /// Adds a raster layer. [properties] are its paint and layout properties
  /// in style-spec form.
  @asyncCallback
  void rasterLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// Adds a hillshade layer, as [rasterLayerAdd].
  @asyncCallback
  void hillshadeLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// Adds a color relief layer, as [rasterLayerAdd].
  @asyncCallback
  void colorReliefLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// Adds a background layer, as [rasterLayerAdd] but without a source.
  @asyncCallback
  void backgroundLayerAdd(
    String layerId,
    String? belowLayerId,
    double? minzoom,
    double? maxzoom,
    Map<String, Object?> properties,
  );

  /// Adds a heatmap layer, as [symbolLayerAdd] but without interaction.
  @asyncCallback
  void heatmapLayerAdd(
    String sourceId,
    String layerId,
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    String? filter,
    Map<String, Object?> properties,
  );

  /// Replaces the feature of the GeoJSON source [sourceId] that has the id
  /// of [geojsonFeature], GeoJSON text. Without such a feature nothing
  /// changes.
  @asyncCallback
  void sourceSetFeature(String sourceId, String geojsonFeature);

  /// Merges [state], app data of any shape, into the state of the feature
  /// [featureId]. Android only: Dart rejects the call on iOS before sending
  /// it.
  @asyncCallback
  void sourceSetFeatureState(
    String sourceId,
    String featureId,
    Map<String, Object?> state,
    String? sourceLayer,
  );

  /// Removes the key [stateKey] of the state of the feature [featureId], or
  /// the whole state of that feature without [stateKey], or the state of
  /// every feature of the source without [featureId]. Android only: Dart
  /// rejects the call on iOS before sending it.
  @asyncCallback
  void sourceRemoveFeatureState(
    String sourceId,
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  );

  /// Answers with the state of the feature [featureId] as JSON text, or with
  /// null when it has none. Android only: Dart rejects the call on iOS before
  /// sending it.
  @asyncCallback
  String? sourceGetFeatureState(
    String sourceId,
    String featureId,
    String? sourceLayer,
  );

  /// Sets the light of the style. [light] holds the light properties in
  /// style-spec form. It stays a map because each property can be any value
  /// in Dart: native checks that each one is a constant of the right type.
  @asyncCallback
  void styleSetLight(Map<String, Object?> light);

  /// Shows or hides the layer [layerId].
  @asyncCallback
  void layerSetVisibility(String layerId, bool visible);

  /// Shows or hides the layers [layerIds]. Answers with the ids that matched
  /// no layer.
  @asyncCallback
  List<String>? layerSetVisibilityBatch(List<String> layerIds, bool visible);

  /// Sets the zoom range of the layer [layerId].
  @asyncCallback
  void layerSetZoomRange(String layerId, double minzoom, double maxzoom);

  /// Answers whether the layer [layerId] is visible, or with null when there
  /// is no such layer.
  @asyncCallback
  bool? layerGetVisibility(String layerId);

  /// Answers with a PNG of the map, [width] by [height] logical pixels, or
  /// the size of the map view for what is null.
  @asyncCallback
  Uint8List? mapTakeSnapshot(int? width, int? height);

  /// Answers with the ids of the layers of the style, in the order of the
  /// style.
  @asyncCallback
  List<String> styleGetLayerIds();

  /// Answers with the ids of the sources of the style.
  @asyncCallback
  List<String> styleGetSourceIds();

  /// Answers with the layer [layerId] in style-spec form as JSON text, or
  /// with null when there is no such layer.
  @asyncCallback
  String? styleGetLayerProperties(String layerId);

  /// Answers with the source [sourceId] in style-spec form as JSON text, or
  /// with null when there is no such source.
  @asyncCallback
  String? styleGetSourceProperties(String sourceId);

  /// Replaces the style with [style]: a style JSON, URL, file path or asset
  /// name.
  @asyncCallback
  void styleSetStyle(String style);
}

/// The events of one map, from native to Dart, on channels told apart by the
/// same suffix as [MapLibreMapHostApi].
@FlutterApi()
abstract class MapLibreMapFlutterApi {
  /// The user tapped a feature of an interactive layer.
  @asyncCallback
  void featureOnTap(PgFeatureTap tap);

  /// The user dragged a feature of an interactive layer.
  @asyncCallback
  void featureOnDrag(PgFeatureDrag drag);

  /// The camera started to move. [isGesture] is whether the SDK reports a
  /// gesture of the user as the cause.
  @asyncCallback
  void cameraOnMoveStarted(bool isGesture);

  /// The camera moved, for a map that tracks the camera position.
  @asyncCallback
  void cameraOnMove(PgCameraPosition position);

  /// The camera stopped. [position] is null when the map does not track the
  /// camera position.
  @asyncCallback
  void cameraOnIdle(PgCameraPosition? position);

  /// A style finished loading.
  @asyncCallback
  void mapOnStyleLoaded();

  /// The user tapped the map at [point] of the map view, [latLng] on the
  /// map.
  @asyncCallback
  void mapOnMapClick(PgScreenPoint point, PgLatLng latLng);

  /// The user long pressed the map at [point] of the map view, [latLng] on
  /// the map.
  @asyncCallback
  void mapOnMapLongClick(PgScreenPoint point, PgLatLng latLng);

  /// The way the camera follows the user location changed to [mode].
  @asyncCallback
  void mapOnCameraTrackingChanged(PgMyLocationTrackingMode mode);

  /// The camera stopped following the user location.
  @asyncCallback
  void mapOnCameraTrackingDismissed();

  /// The map finished rendering and has nothing left to load or animate.
  @asyncCallback
  void mapOnIdle();

  /// The user location changed, with the compass [heading] on iOS.
  @asyncCallback
  void mapOnUserLocationUpdated(
    PgUserLocation userLocation,
    PgUserHeading? heading,
  );
}
