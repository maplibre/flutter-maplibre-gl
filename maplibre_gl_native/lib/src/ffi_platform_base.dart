import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

/// [MapLibrePlatform] base that stubs every interface member with an
/// [UnimplementedError], so [MapLibreFfiPlatform] can override only the
/// surface actually covered by the spike while keeping the missing pieces
/// loud and explicit.
abstract class MapLibreFfiPlatformBase extends MapLibrePlatform {
  Never _unimplemented(String name) => throw UnimplementedError(
    'MapLibreFfiPlatform.$name is not implemented yet in the '
    'maplibre_gl_native spike',
  );

  @override
  Future<void> initPlatform(int id) => _unimplemented('initPlatform');

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) => _unimplemented('buildView');

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) => _unimplemented('updateMapOptions');

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) => _unimplemented('animateCamera');

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) =>
      _unimplemented('moveCamera');

  @override
  Future<void> updateMyLocationTrackingMode(
    MyLocationTrackingMode myLocationTrackingMode,
  ) => _unimplemented('updateMyLocationTrackingMode');

  @override
  Future<void> matchMapLanguageWithDeviceDefault() =>
      _unimplemented('matchMapLanguageWithDeviceDefault');

  @override
  void resizeWebMap() => _unimplemented('resizeWebMap');

  @override
  void forceResizeWebMap() => _unimplemented('forceResizeWebMap');

  @override
  Future<void> updateContentInsets(EdgeInsets insets, bool animated) =>
      _unimplemented('updateContentInsets');

  @override
  Future<void> setMapLanguage(String language) =>
      _unimplemented('setMapLanguage');

  @override
  Future<void> setTelemetryEnabled(bool enabled) =>
      _unimplemented('setTelemetryEnabled');

  @override
  Future<bool> getTelemetryEnabled() => _unimplemented('getTelemetryEnabled');

  @override
  Future<void> setMaximumFps(int fps) => _unimplemented('setMaximumFps');

  @override
  Future<void> forceOnlineMode() => _unimplemented('forceOnlineMode');

  @override
  Future<bool> easeCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
    CameraAnimationInterpolation? interpolation,
  }) => _unimplemented('easeCamera');

  @override
  Future<CameraPosition?> queryCameraPosition() =>
      _unimplemented('queryCameraPosition');

  @override
  Future<bool> editGeoJsonSource(String id, String data) =>
      _unimplemented('editGeoJsonSource');

  @override
  Future<bool> editGeoJsonUrl(String id, String url) =>
      _unimplemented('editGeoJsonUrl');

  @override
  Future<bool> setLayerFilter(String layerId, String filter) =>
      _unimplemented('setLayerFilter');

  @override
  Future<String?> getStyle() => _unimplemented('getStyle');

  @override
  Future<void> setCustomHeaders(
    Map<String, String> headers,
    List<String> filter,
  ) => _unimplemented('setCustomHeaders');

  @override
  Future<Map<String, String>> getCustomHeaders() =>
      _unimplemented('getCustomHeaders');

  @override
  Future<List> queryRenderedFeatures(
    Point<double> point,
    List<String> layerIds,
    List<Object>? filter,
  ) => _unimplemented('queryRenderedFeatures');

  @override
  Future<List> queryRenderedFeaturesInRect(
    Rect rect,
    List<String> layerIds,
    String? filter,
  ) => _unimplemented('queryRenderedFeaturesInRect');

  @override
  Future<List> querySourceFeatures(
    String sourceId,
    String? sourceLayerId,
    List<Object>? filter,
  ) => _unimplemented('querySourceFeatures');

  @override
  Future invalidateAmbientCache() => _unimplemented('invalidateAmbientCache');

  @override
  Future clearAmbientCache() => _unimplemented('clearAmbientCache');

  @override
  Future<LatLng?> requestMyLocationLatLng() =>
      _unimplemented('requestMyLocationLatLng');

  @override
  Future<LatLngBounds> getVisibleRegion() => _unimplemented('getVisibleRegion');

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) =>
      _unimplemented('addImage');

  @override
  Future<void> addImageSource(
    String imageSourceId,
    Uint8List bytes,
    LatLngQuad coordinates,
  ) => _unimplemented('addImageSource');

  @override
  Future<void> updateImageSource(
    String imageSourceId,
    Uint8List? bytes,
    LatLngQuad? coordinates,
  ) => _unimplemented('updateImageSource');

  @override
  Future<void> addLayer(
    String imageLayerId,
    String imageSourceId,
    double? minzoom,
    double? maxzoom,
  ) => _unimplemented('addLayer');

  @override
  Future<void> addLayerBelow(
    String imageLayerId,
    String imageSourceId,
    String belowLayerId,
    double? minzoom,
    double? maxzoom,
  ) => _unimplemented('addLayerBelow');

  @override
  Future<void> removeLayer(String imageLayerId) =>
      _unimplemented('removeLayer');

  @override
  Future<List> getLayerIds() => _unimplemented('getLayerIds');

  @override
  Future<List> getSourceIds() => _unimplemented('getSourceIds');

  @override
  Future<void> setFilter(String layerId, dynamic filter) =>
      _unimplemented('setFilter');

  @override
  Future<dynamic> getFilter(String layerId) => _unimplemented('getFilter');

  @override
  Future<Point> toScreenLocation(LatLng latLng) =>
      _unimplemented('toScreenLocation');

  @override
  Future<List<Point>> toScreenLocationBatch(Iterable<LatLng> latLngs) =>
      _unimplemented('toScreenLocationBatch');

  @override
  Future<LatLng> toLatLng(Point screenLocation) => _unimplemented('toLatLng');

  @override
  Future<double> getMetersPerPixelAtLatitude(double latitude) =>
      _unimplemented('getMetersPerPixelAtLatitude');

  @override
  Future<void> addGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson, {
    String? promoteId,
  }) => _unimplemented('addGeoJsonSource');

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojson,
  ) => _unimplemented('setGeoJsonSource');

  @override
  Future<void> setCameraBounds({
    required double west,
    required double north,
    required double south,
    required double east,
    required int padding,
  }) => _unimplemented('setCameraBounds');

  @override
  Future<void> setFeatureForGeoJsonSource(
    String sourceId,
    Map<String, dynamic> geojsonFeature,
  ) => _unimplemented('setFeatureForGeoJsonSource');

  @override
  Future<void> setFeatureState(
    String sourceId,
    String featureId,
    Map<String, dynamic> state, {
    String? sourceLayer,
  }) => _unimplemented('setFeatureState');

  @override
  Future<void> removeFeatureState(
    String sourceId, {
    String? featureId,
    String? stateKey,
    String? sourceLayer,
  }) => _unimplemented('removeFeatureState');

  @override
  Future<Map<String, dynamic>?> getFeatureState(
    String sourceId,
    String featureId, {
    String? sourceLayer,
  }) => _unimplemented('getFeatureState');

  @override
  Future<void> removeSource(String sourceId) => _unimplemented('removeSource');

  @override
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
  }) => _unimplemented('addSymbolLayer');

  @override
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
  }) => _unimplemented('addLineLayer');

  @override
  Future<void> setLayerProperties(
    String layerId,
    Map<String, dynamic> properties,
  ) => _unimplemented('setLayerProperties');

  @override
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
  }) => _unimplemented('addCircleLayer');

  @override
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
  }) => _unimplemented('addFillLayer');

  @override
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
  }) => _unimplemented('addFillExtrusionLayer');

  @override
  Future<void> addRasterLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _unimplemented('addRasterLayer');

  @override
  Future<void> addHillshadeLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _unimplemented('addHillshadeLayer');

  @override
  Future<void> addHeatmapLayer(
    String sourceId,
    String layerId,
    Map<String, dynamic> properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
  }) => _unimplemented('addHeatmapLayer');

  @override
  Future<void> addSource(String sourceId, SourceProperties properties) =>
      _unimplemented('addSource');

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) =>
      _unimplemented('setLayerVisibility');

  @override
  Future<bool?> getLayerVisibility(String layerId) =>
      _unimplemented('getLayerVisibility');

  @override
  Future<Size> setWebMapToCustomSize(Size size) =>
      _unimplemented('setWebMapToCustomSize');

  @override
  Future<void> waitUntilMapIsIdleAfterMovement() =>
      _unimplemented('waitUntilMapIsIdleAfterMovement');

  @override
  Future<void> waitUntilMapTilesAreLoaded() =>
      _unimplemented('waitUntilMapTilesAreLoaded');

  @override
  Future<Uint8List> takeSnapshot({int? width, int? height}) =>
      _unimplemented('takeSnapshot');

  @override
  Future<void> setStyle(String styleString) => _unimplemented('setStyle');
}
