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
}
