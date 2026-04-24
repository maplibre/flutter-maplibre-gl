part of '../maplibre_gl_platform_interface.dart';

/// Easing curve for [MapLibreMapController.easeCamera] animations.
///
/// Platform support varies — iOS exposes four distinct timing functions via
/// `CAMediaTimingFunction`, Web implements each value as a cubic Bezier passed
/// to MapLibre GL JS's `easeTo({easing})`, while MapLibre Android only exposes
/// a boolean `easingInterpolator` flag (linear vs. the native
/// ease-in/ease-out). Per-value behavior is documented below.
///
/// When `easeCamera` is called without an interpolation, each platform uses
/// its historical default (iOS, Android, and Web all default to an ease-in/ease-out curve).
enum CameraAnimationInterpolation {
  /// Constant velocity throughout the animation (no easing).
  ///
  /// Best for continuous tracking scenarios (e.g. following a moving GPS
  /// target) where velocity discontinuities between successive `easeCamera`
  /// calls would produce perceptible "animated jumps".
  ///
  /// Fully supported on iOS, Android, and Web.
  linear,

  /// Accelerate at the start and decelerate at the end.
  ///
  /// Produces a smooth, natural-feeling movement. This is the platform
  /// default on iOS, Android, and Web when no interpolation is specified.
  easeInOut,

  /// Decelerate towards the end of the animation.
  ///
  /// iOS: mapped to `CAMediaTimingFunctionName.easeOut`.
  ///
  /// Web: implemented as cubic Bezier `(0, 0, 0.58, 1)`.
  ///
  /// Android: MapLibre Android does not expose custom timing curves via
  /// [easeCamera], so this falls back to the default ease-in/ease-out and
  /// is indistinguishable from [easeInOut] on Android.
  easeOut,

  /// Material Design "fast out, linear in" curve — cubic Bezier
  /// `(0.4, 0.0, 1.0, 1.0)`. Accelerates quickly, then approaches the target
  /// at constant velocity.
  ///
  /// iOS: implemented exactly via `CAMediaTimingFunction(controlPoints:)`.
  ///
  /// Web: implemented exactly via MapLibre GL JS `easeTo({easing})`.
  ///
  /// Android: MapLibre Android does not expose custom timing curves via
  /// [easeCamera], so this falls back to the default ease-in/ease-out and
  /// is indistinguishable from [easeInOut] on Android.
  fastOutLinearIn,
}

/// The default instance of [MapLibrePlatform] to use.
typedef OnPlatformViewCreatedCallback = void Function(int);

abstract class MapLibrePlatform {
  static MapLibreMethodChannel? _instance;

  /// The default instance of [MapLibrePlatform] to use.
  ///
  /// Defaults to [MapLibreMethodChannel].
  ///
  /// Platform-specific plugins should set this with their own platform-specific
  /// class that extends [MapLibrePlatform] when they register themselves.
  static MapLibrePlatform Function() createInstance =
      () => _instance ?? MapLibreMethodChannel();

  final onInfoWindowTappedPlatform = ArgumentCallbacks<String>();

  final onFeatureTappedPlatform = ArgumentCallbacks<Map<String, dynamic>>();

  final onFeatureHoverPlatform = ArgumentCallbacks<Map<String, dynamic>>();
  final onFeatureDraggedPlatform = ArgumentCallbacks<Map<String, dynamic>>();

  final onCameraMoveStartedPlatform = ArgumentCallbacks<void>();

  final onCameraMovePlatform = ArgumentCallbacks<CameraPosition>();

  final onCameraIdlePlatform = ArgumentCallbacks<CameraPosition?>();

  final onMapStyleLoadedPlatform = ArgumentCallbacks<void>();

  final onMapClickPlatform = ArgumentCallbacks<Map<String, dynamic>>();

  final onMapLongClickPlatform = ArgumentCallbacks<Map<String, dynamic>>();

  final onMapMouseMovePlatform = ArgumentCallbacks<Map<String, dynamic>>();

  final onCameraTrackingChangedPlatform =
      ArgumentCallbacks<MyLocationTrackingMode>();

  final onCameraTrackingDismissedPlatform = ArgumentCallbacks<void>();

  final onMapIdlePlatform = ArgumentCallbacks<void>();

  final onUserLocationUpdatedPlatform = ArgumentCallbacks<UserLocation>();

  Future<void> initPlatform(int id);
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  );
  Future<CameraPosition?> updateMapOptions(Map<String, dynamic> optionsUpdate);
  Future<bool?> animateCamera(CameraUpdate cameraUpdate, {Duration? duration});
  Future<bool?> moveCamera(CameraUpdate cameraUpdate);
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  );

  Future<void> matchMapLanguageWithDeviceDefault();

  void resizeWebMap();
  void forceResizeWebMap();

  Future<void> updateContentInsets(EdgeInsets insets, bool animated);
  Future<void> setMapLanguage(String language);
  Future<void> setTelemetryEnabled(bool enabled);

  Future<bool> getTelemetryEnabled();

  /// Performance Controls
  /// Sets the maximum frames per second for the map rendering.
  Future<void> setMaximumFps(int fps);

  /// Forces the map to use online mode (disables offline mode).
  Future<void> forceOnlineMode();

  /// Animates the camera to a new position with a specified duration and interpolation.
  ///
  /// The [cameraUpdate] specifies the target camera position.
  /// The [duration] specifies how long the animation should take.
  /// The [interpolation] controls the easing curve (defaults to platform default if not specified).
  ///
  /// Use [CameraAnimationInterpolation.linear] for smooth continuous tracking without
  /// velocity discontinuities. Use other modes for discrete camera movements.
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  });

  /// Queries the current camera position.
  Future<CameraPosition?> queryCameraPosition();

  /// Edits a GeoJSON source with new data.
  Future<bool> editGeoJsonSource(String id, String data);

  /// Edits a GeoJSON source with a new URL.
  Future<bool> editGeoJsonUrl(String id, String url);

  /// Sets a filter for a layer.
  Future<bool> setLayerFilter(String layerId, String filter);

  /// Gets the current map style as JSON string.
  Future<String?> getStyle();

  /// Sets custom HTTP headers for map requests.
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  );

  /// Gets the current custom HTTP headers.
  Future<Map<String, String>> getCustomHeaders();

  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  );

  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  );

  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  );
  Future invalidateAmbientCache();
  Future clearAmbientCache();
  Future<LatLng?> requestMyLocationLatLng();

  Future<LatLngBounds> getVisibleRegion();

  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]);

  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  );

  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  );

  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  );

  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  );

  Future<void> removeLayer(String imageLayerId);

  Future<List> getLayerIds();

  Future<List> getSourceIds();

  Future<void> setFilter(String layerId, dynamic filter);

  Future<dynamic> getFilter(String layerId);

  Future<Point> toScreenLocation(LatLng latLng);

  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs);

  Future<LatLng> toLatLng(Point screenLocation);

  Future<double> getMetersPerPixelAtLatitude(double latitude);

  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  });

  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson);

  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  });

  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  );

  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  });

  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  });

  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  });

  Future<void> removeSource(String sourceId);

  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  });

  Future<void> addLineLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  });

  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  );

  Future<void> addCircleLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  });

  Future<void> addFillLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  });

  Future<void> addFillExtrusionLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    required bool enableInteraction,
  });

  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  });

  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  });

  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  });

  Future<void> addSource(String sourceId, SourceProperties properties);

  Future<void> setLayerVisibility(String layerId, bool visible);

  /// Returns the visibility of a layer.
  /// Returns true if visible, false if hidden, null if layer not found.
  Future<bool?> getLayerVisibility(String layerId);

  /// Sets the web map to a custom size for rendering.
  /// Returns the previous/initial size of the web map before this change.
  Future<Size> setWebMapToCustomSize(Size size);

  /// Waits until the map is idle after camera movement.
  Future<void> waitUntilMapIsIdleAfterMovement();

  /// Waits until all visible map tiles are loaded.
  Future<void> waitUntilMapTilesAreLoaded();

  /// Takes a screenshot of the current map view as PNG bytes.
  /// Returns a [Uint8List] containing the PNG image data.
  /// Supported on all platforms (Android, iOS, Web).
  ///
  /// If [width] and [height] are provided, the snapshot is rendered at that
  /// size (in logical pixels) using an offscreen renderer, preserving the
  /// current camera position and style. When omitted the snapshot matches the
  /// current map view size.
  Future<Uint8List> takeSnapshot({int? width, int? height});

  /// Method to set style string
  /// A MapLibre GL style document defining the map's appearance.
  /// The style document specification is at [https://maplibre.org/maplibre-style-spec].
  /// A short introduction can be found in the documentation of the [maplibre_gl] library.
  /// The [styleString] supports following formats:
  ///
  /// 1. Passing the URL of the map style. This should be a custom map style served remotely using a URL that start with 'http(s)://'
  /// 2. Passing the style as a local asset. Create a JSON file in the `assets` and add a reference in `pubspec.yml`. Set the style string to the relative path for this asset in order to load it into the map.
  /// 3. Passing the style as a local file. create a JSON file in app directory (e.g. ApplicationDocumentsDirectory). Set the style string to the absolute path of this JSON file.
  /// 4. Passing the raw JSON of the map style. This is only supported on Android.
  Future<void> setStyle(String styleString);

  @mustCallSuper
  void dispose() {
    // clear all callbacks to avoid cyclic refs
    onInfoWindowTappedPlatform.clear();
    onFeatureTappedPlatform.clear();
    onFeatureHoverPlatform.clear();
    onFeatureDraggedPlatform.clear();
    onCameraMoveStartedPlatform.clear();
    onCameraMovePlatform.clear();
    onCameraIdlePlatform.clear();
    onMapStyleLoadedPlatform.clear();

    onMapClickPlatform.clear();
    onMapLongClickPlatform.clear();
    onMapMouseMovePlatform.clear();
    onCameraTrackingChangedPlatform.clear();
    onCameraTrackingDismissedPlatform.clear();
    onMapIdlePlatform.clear();
    onUserLocationUpdatedPlatform.clear();
  }
}
