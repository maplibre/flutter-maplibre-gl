package org.maplibre.maplibregl;

import androidx.annotation.Nullable;

import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodChannel;

/**
 * The calls of one map, as {@link MapHostApi} hands them over. Each one is named after the {@link
 * MapLibreMapHostApi} method it serves, takes its arguments in the same order, and answers through
 * {@code result}.
 *
 * <p>While {@link #isMapReady()} is false, {@link MapHostApi} answers every call but {@link
 * #mapWaitForMap}, {@link #mapPause} and {@link #mapResume} with {@code MAP_NOT_READY} itself,
 * without calling it.
 *
 * <p>{@link MapLibreMapController} implements it. It is an interface so the JVM tests can stand in
 * for the controller.
 */
public interface MapCalls extends MethodChannel.MethodCallHandler {
  /** Whether the native map exists. It does not while the MapView is being rebuilt. */
  boolean isMapReady();

  /**
   * Answers SOURCE_ALREADY_EXISTS when the style already holds a source with {@code sourceId}.
   * {@link MapHostApi} asks it before every call that adds a source.
   *
   * @return true when {@code result} has been answered.
   */
  boolean rejectDuplicateSourceId(String sourceId, MethodChannel.Result result);

  /**
   * Answers LAYER_ALREADY_EXISTS when the style already holds a layer with {@code layerId}. {@link
   * MapHostApi} asks it before every call that adds a layer.
   *
   * @return true when {@code result} has been answered.
   */
  boolean rejectDuplicateLayerId(String layerId, MethodChannel.Result result);

  // Map

  void mapWaitForMap(MethodChannel.Result result);

  void mapUpdate(Map<String, Object> options, MethodChannel.Result result);

  void mapMatchMapLanguageWithDeviceDefault(MethodChannel.Result result);

  void mapSetMapLanguage(String language, MethodChannel.Result result);

  void mapSetTelemetryEnabled(boolean enabled, MethodChannel.Result result);

  void mapGetTelemetryEnabled(MethodChannel.Result result);

  void mapSetMaximumFps(long fps, MethodChannel.Result result);

  void mapForceOnlineMode(MethodChannel.Result result);

  void mapPause(MethodChannel.Result result);

  void mapResume(MethodChannel.Result result);

  void mapSetCustomHeaders(
      Map<String, String> headers, List<String> filter, MethodChannel.Result result);

  void mapGetCustomHeaders(MethodChannel.Result result);

  void mapInvalidateAmbientCache(MethodChannel.Result result);

  void mapClearAmbientCache(MethodChannel.Result result);

  void mapTakeSnapshot(@Nullable Long width, @Nullable Long height, MethodChannel.Result result);

  // Camera

  void cameraMove(List<Object> cameraUpdate, MethodChannel.Result result);

  void cameraAnimate(
      List<Object> cameraUpdate, @Nullable Long duration, MethodChannel.Result result);

  void cameraEase(
      List<Object> cameraUpdate,
      @Nullable Long duration,
      @Nullable String interpolation,
      MethodChannel.Result result);

  void mapQueryCameraPosition(MethodChannel.Result result);

  void mapUpdateContentInsets(
      Map<String, Double> bounds, boolean animated, MethodChannel.Result result);

  void mapSetCameraBounds(
      double west,
      double north,
      double south,
      double east,
      long padding,
      MethodChannel.Result result);

  // Location

  void mapUpdateMyLocationTrackingMode(long mode, MethodChannel.Result result);

  void locationComponentGetLastLocation(MethodChannel.Result result);

  void locationComponentSetTrackingCameraOptions(
      double tilt, @Nullable Long duration, MethodChannel.Result result);

  void locationComponentSetManualLocation(Map<String, Object> update, MethodChannel.Result result);

  // Queries

  void mapGetVisibleRegion(MethodChannel.Result result);

  void mapToScreenLocation(double latitude, double longitude, MethodChannel.Result result);

  void mapToScreenLocationBatch(double[] coordinates, MethodChannel.Result result);

  void mapToLatLng(double x, double y, MethodChannel.Result result);

  void mapGetMetersPerPixelAtLatitude(double latitude, MethodChannel.Result result);

  void mapQueryRenderedFeaturesAtPoint(
      double x,
      double y,
      List<String> layerIds,
      @Nullable List<Object> filter,
      MethodChannel.Result result);

  void mapQueryRenderedFeaturesInRect(
      double left,
      double top,
      double right,
      double bottom,
      List<String> layerIds,
      @Nullable String filter,
      MethodChannel.Result result);

  void mapQuerySourceFeatures(
      String sourceId,
      @Nullable String sourceLayerId,
      @Nullable List<Object> filter,
      MethodChannel.Result result);

  // Sources

  void mapEditGeoJsonSource(String id, String data, MethodChannel.Result result);

  void mapEditGeoJsonUrl(String id, String url, MethodChannel.Result result);

  void sourceAddGeoJson(String sourceId, String geojson, MethodChannel.Result result);

  void sourceSetGeoJson(String sourceId, String geojson, MethodChannel.Result result);

  void sourceSetFeature(String sourceId, String geojsonFeature, MethodChannel.Result result);

  void sourceSetFeatureState(
      String sourceId,
      String featureId,
      Map<String, Object> state,
      @Nullable String sourceLayer,
      MethodChannel.Result result);

  void sourceRemoveFeatureState(
      String sourceId,
      @Nullable String featureId,
      @Nullable String stateKey,
      @Nullable String sourceLayer,
      MethodChannel.Result result);

  void sourceGetFeatureState(
      String sourceId,
      String featureId,
      @Nullable String sourceLayer,
      MethodChannel.Result result);

  void sourceGetClusterExpansionZoom(String sourceId, long clusterId, MethodChannel.Result result);

  void sourceGetClusterChildren(String sourceId, long clusterId, MethodChannel.Result result);

  void sourceGetClusterLeaves(
      String sourceId, long clusterId, long limit, long offset, MethodChannel.Result result);

  void styleAddSource(
      String sourceId, Map<String, Object> properties, MethodChannel.Result result);

  void styleRemoveSource(String sourceId, MethodChannel.Result result);

  void styleAddImageSource(
      String imageSourceId,
      byte[] bytes,
      long length,
      List<Object> coordinates,
      MethodChannel.Result result);

  void styleUpdateImageSource(
      String imageSourceId,
      @Nullable byte[] bytes,
      @Nullable Long length,
      @Nullable List<Object> coordinates,
      MethodChannel.Result result);

  void styleGetSourceIds(MethodChannel.Result result);

  void styleGetSourceProperties(String sourceId, MethodChannel.Result result);

  // Layers

  void symbolLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void lineLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void fillLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void fillExtrusionLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void circleLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void rasterLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void hillshadeLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void colorReliefLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void backgroundLayerAdd(
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void heatmapLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      String filter,
      Map<String, Object> properties,
      MethodChannel.Result result);

  void layerSetProperties(
      String layerId, Map<String, Object> properties, MethodChannel.Result result);

  void layerSetVisibility(String layerId, boolean visible, MethodChannel.Result result);

  void layerSetVisibilityBatch(
      List<String> layerIds, boolean visible, MethodChannel.Result result);

  void layerSetZoomRange(
      String layerId, double minzoom, double maxzoom, MethodChannel.Result result);

  void layerGetVisibility(String layerId, MethodChannel.Result result);

  void styleAddLayer(
      String imageLayerId,
      String imageSourceId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      MethodChannel.Result result);

  void styleAddLayerBelow(
      String imageLayerId,
      String imageSourceId,
      String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      MethodChannel.Result result);

  void styleRemoveLayer(String layerId, MethodChannel.Result result);

  void styleMoveLayer(String layerId, @Nullable String belowLayerId, MethodChannel.Result result);

  void styleSetFilter(String layerId, String filter, MethodChannel.Result result);

  void styleGetFilter(String layerId, MethodChannel.Result result);

  void mapSetLayerFilter(String id, String filter, MethodChannel.Result result);

  void styleGetLayerIds(MethodChannel.Result result);

  void styleGetLayerProperties(String layerId, MethodChannel.Result result);
}
