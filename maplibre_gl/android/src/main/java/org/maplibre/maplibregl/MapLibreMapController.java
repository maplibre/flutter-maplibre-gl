// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.maplibre.maplibregl;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.PointF;
import android.graphics.RectF;
import android.location.Location;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.Pair;
import android.content.ComponentCallbacks2;
import android.content.res.Configuration;
import android.view.GestureDetector;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.TextureView;
import android.view.View;
import android.view.ViewConfiguration;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.DefaultLifecycleObserver;
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonNull;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;

import org.jetbrains.annotations.NotNull;
import org.maplibre.android.log.Logger;
import org.maplibre.android.log.LoggerDefinition;
import org.maplibre.android.camera.CameraPosition;
import org.maplibre.android.camera.CameraUpdate;
import org.maplibre.android.camera.CameraUpdateFactory;
import org.maplibre.android.constants.MapLibreConstants;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.geometry.LatLngBounds;
import org.maplibre.android.geometry.LatLngQuad;
import org.maplibre.android.gestures.AndroidGesturesManager;
import org.maplibre.android.gestures.MoveGestureDetector;
import org.maplibre.android.location.LocationComponent;
import org.maplibre.android.location.LocationComponentActivationOptions;
import org.maplibre.android.location.LocationComponentOptions;
import org.maplibre.android.location.OnCameraTrackingChangedListener;
import org.maplibre.android.location.engine.LocationEngineCallback;
import org.maplibre.android.location.engine.LocationEngineRequest;
import org.maplibre.android.location.engine.LocationEngineResult;
import org.maplibre.android.location.modes.CameraMode;
import org.maplibre.android.location.modes.RenderMode;
import org.maplibre.android.maps.MapLibreMap;
import org.maplibre.android.maps.MapLibreMapOptions;
import org.maplibre.android.maps.MapView;
import org.maplibre.android.maps.OnMapReadyCallback;
import org.maplibre.android.maps.Style;
import org.maplibre.android.maps.UiSettings;
import org.maplibre.android.offline.OfflineManager;
import org.maplibre.android.style.expressions.Expression;
import org.maplibre.android.style.layers.CircleLayer;
import org.maplibre.android.style.layers.TransitionOptions;
import org.maplibre.android.style.layers.BackgroundLayer;
import org.maplibre.android.style.layers.ColorReliefLayer;
import org.maplibre.android.style.layers.FillExtrusionLayer;
import org.maplibre.android.style.layers.FillLayer;
import org.maplibre.android.style.layers.HeatmapLayer;
import org.maplibre.android.style.layers.HillshadeLayer;
import org.maplibre.android.style.layers.Layer;
import org.maplibre.android.style.layers.LineLayer;
import org.maplibre.android.style.layers.Property;
import org.maplibre.android.style.layers.PropertyFactory;
import org.maplibre.android.style.layers.PropertyValue;
import org.maplibre.android.style.light.Position;
import org.maplibre.android.style.light.Light;
import org.maplibre.android.style.layers.RasterLayer;
import org.maplibre.android.style.layers.SymbolLayer;
import org.maplibre.android.style.sources.CustomGeometrySource;
import org.maplibre.android.style.sources.GeoJsonOptions;
import org.maplibre.android.style.sources.GeoJsonSource;
import org.maplibre.android.style.sources.ImageSource;
import org.maplibre.android.style.sources.RasterDemSource;
import org.maplibre.android.style.sources.RasterSource;
import org.maplibre.android.style.sources.Source;
import org.maplibre.android.style.sources.VectorSource;
import org.maplibre.geojson.Feature;
import org.maplibre.geojson.FeatureCollection;
import org.maplibre.geojson.Point;
import org.maplibre.android.net.ConnectivityReceiver;
import org.maplibre.android.snapshotter.MapSnapshot;
import org.maplibre.android.snapshotter.MapSnapshotter;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;


/**
 * Controller of a single MapLibre {@link MapView} instance exposed as a Flutter
 * {@link PlatformView}. Mediates between the Pigeon channels of the map, the host
 * activity {@link Lifecycle}, and the native {@link MapView}. Dart calls arrive through
 * {@link MapHostApi}, which hands each one to the {@link MapCalls} method of the same name;
 * events go back through {@link MapLibreMapFlutterApi}.
 *
 * <h2>Surviving activity recreation</h2>
 * Android can destroy and recreate the host activity at any time (rotation, "Don't keep
 * activities", memory pressure). The {@link MapView} holds GL resources tied to the activity
 * that built it, so it is destroyed with the activity and rebuilt against the new one, without
 * the Flutter widget tree seeing the swap.
 *
 * <p>Carried across: the camera ({@link #lastCameraPosition}), MapLibre's own state bundle
 * ({@link #savedMapViewState}), and the controller fields, which outlive the activity. Lost:
 * sources, layers, images and other runtime style changes, which Dart re-applies when
 * {@code map#onStyleLoaded} fires for the new MapView. {@link #recreateMapViewIfNecessary()}
 * lists both sides in full.
 *
 * <p>{@link MapLibreMapFactory} broadcasts the activity hooks ({@link #onActivityAttached()},
 * {@link #onActivityDetached()}, {@link #onActivityRebound()}); with the
 * {@code mapViewCreated/Started/Resumed} flags they keep each MapView's lifecycle calls
 * balanced however Jetpack replays events. While the MapView is being rebuilt,
 * {@link #mapWaitForMap} parks its result until {@link #onMapReady} fires again, and every
 * other map-touching call answers {@code MAP_NOT_READY}.
 *
 * <p>{@link #mapPause} / {@link #mapResume} drive rendering explicitly through
 * {@link #userPaused}: a map paused from Dart stays paused even when the activity returns to
 * the foreground.
 */
@SuppressLint("MissingPermission")
final class MapLibreMapController
    implements DefaultLifecycleObserver,
        ComponentCallbacks2,
        MapLibreMap.OnCameraIdleListener,
        MapLibreMap.OnCameraMoveListener,
        MapLibreMap.OnCameraMoveStartedListener,
        MapView.OnDidBecomeIdleListener,
        MapLibreMap.OnMapClickListener,
        MapLibreMap.OnMapLongClickListener,
        MapCalls,
        MapLibreMapOptionsSink,
        OnMapReadyCallback,
        OnCameraTrackingChangedListener,
        PlatformView {
  private static final String TAG = "MapLibreMapController";

  /**
   * Duration used for {@link #locationComponentSetTrackingCameraOptions} when Dart
   * sends none. Mirrors the SDK's own {@code DEFAULT_TRACKING_TILT_ANIM_DURATION},
   * which is package-private, so the callback-taking overload cannot reuse it.
   */
  private static final long DEFAULT_TRACKING_TILT_DURATION_MS = 1250;

  private final int id;
  private final BinaryMessenger messenger;
  /** Sends the events of this map to Dart. */
  private final MapLibreMapFlutterApi flutterApi;
  private final MapLibreMapsPlugin.LifecycleProvider lifecycleProvider;
  private final MapLibreMapOptions mapLibreMapOptions;
  /**
   * The {@link Lifecycle} this controller is currently observing. Used to detect
   * stale callbacks from a destroyed activity and to avoid double-subscription
   * when the host activity is recreated (e.g. "Don't keep activities", rotation).
   */
  private Lifecycle boundLifecycle;
  /**
   * Last known camera position. Saved before destroying the {@link MapView} so it
   * can be restored once the map is recreated in a fresh activity. Cleared after
   * being applied in {@link #onMapReady(MapLibreMap)}.
   */
  private CameraPosition lastCameraPosition;
  /**
   * State bundle written by {@link MapView#onSaveInstanceState(Bundle)} before the
   * {@link MapView} is destroyed and read back by {@link MapView#onCreate(Bundle)}
   * on the recreated instance. Lets MapLibre restore internal state (camera, style
   * progress, etc.) across activity recreation, complementing {@link #lastCameraPosition}.
   */
  private final Bundle savedMapViewState = new Bundle();
  private float density;
  private final Context applicationContext;
  /**
   * Activity context used to build the {@link MapView}. Re-pointed at the current
   * activity on every {@link #onActivityAttached()}/{@link #onActivityRebound()} so
   * we don't pin a destroyed activity in memory. Register long-lived listeners against
   * {@link #applicationContext} instead of this field.
   */
  private Context context;
  private final String styleStringInitial;
  /**
   * Container that wraps the {@link MapView}. Returned as the platform view so the
   * inner {@link MapView} can be swapped out (after activity recreation) without
   * Flutter noticing. Created with {@link #applicationContext} on purpose: it lives
   * across activities, and uses no activity-themed attributes.
   * See {@link MapLibreMapController#destroyMapViewIfNecessary()} for details.
   */
  private FrameLayout mapViewContainer;
  private MapView mapView;
  private MapLibreMap mapLibreMap;
  private boolean trackCameraPosition = false;
  private boolean myLocationEnabled = false;
  private boolean manualLocationSource = false;
  // The manual location sent while the puck is hidden, shown once it is visible again.
  private final PendingManualLocation<Location> pendingManualLocation =
      new PendingManualLocation<>();
  private int myLocationTrackingMode = 0;
  private int myLocationRenderMode = 0;
  private LocationPuckStyle myLocationStyle = LocationPuckStyle.DEFAULT;
  /** Id prefix of the layers the MapLibre location component adds to the style. */
  private static final String LOCATION_COMPONENT_LAYER_PREFIX = "mapbox-location-";
  private LocationEngineFactory myLocationEngineFactory = new LocationEngineFactory();
  private boolean disposed = false;
  private boolean dragEnabled = true;
  private boolean featureTapsTriggersMapClick = false;
  // Whether MapLibre fades symbols as it places them. A style holds its own
  // transition options, so this is applied again on every style load.
  private boolean symbolPlacementTransitionsEnabled = true;
  // The style's own transition, saved when placement transitions are turned
  // off and written back when they are turned on again. Null while they are on.
  private TransitionOptions transitionBeforePlacementOff = null;
  // Tint of the attribution (i) button, or null to leave the MapLibre SDK
  // default in place. Only set through the attributionButtonColor map option.
  private Integer attributionButtonColor = null;
  // Index of the Dart PanInertia value, or null to leave the SDK fling
  // settings alone. Only set through the panInertia map option.
  private Integer panInertia = null;
  /**
   * Idempotency guards for {@link MapView} lifecycle dispatch, so each transition fires
   * once per {@link MapView} instance. See the lifecycle observer section below.
   */
  private boolean mapViewCreated = false;
  private boolean mapViewStarted = false;
  private boolean mapViewResumed = false;
  /**
   * True when Dart has explicitly requested {@code pauseMap()}. Suppresses the
   * natural {@link #onResume(LifecycleOwner)} until {@code resumeMap()} is called,
   * so a backgrounded map stays paused even when the host activity returns to the
   * foreground.
   */
  private boolean userPaused = false;
  private MethodChannel.Result mapReadyResult;
  private LocationComponent locationComponent = null;
  private LocationEngineCallback<LocationEngineResult> locationEngineCallback = null;
  private Style style;
  private Feature draggedFeature;
  private AndroidGesturesManager androidGesturesManager;

  private LatLng dragOrigin;
  private LatLng dragPrevious;
  // The draggable feature under the finger that came down, until the drag starts or the finger
  // lifts.
  private Feature dragCandidate;
  // From the start of a drag until the last finger lifts or a second finger comes down: the map
  // gets none of the gesture.
  private boolean dragOwnsGesture;
  // Reports taps on touch-up while reportsTapsOnTouchUp. A framework detector without a double-tap
  // listener: it judges a tap as the map's own detector does (touch slop, long press, gesture
  // classification, on every Android version) but does not wait for a second tap.
  private GestureDetector tapDetector;
  // A tap reported on touch-up whose late onMapClick from MapLibre may still come. The next touch
  // down cancels that onMapClick, so it clears this too.
  private boolean tapReportedOnTouchUp;
  private MapSnapshotter activeSnapshotter;
  // The takeSnapshot call activeSnapshotter answers.
  private MethodChannel.Result activeSnapshotResult;
  // Never added to a style: the engine checks the filter of each feature query on it.
  private CircleLayer queryFilterCheck;
  // Never added to a style, one per layer type: the engine checks layer properties on them.
  private final Map<String, Layer> propertyCheckLayers = new HashMap<>();
  // Image source corners set through this API, which the SDK cannot read back.
  private final Map<String, LatLngQuad> imageSourceCoordinates = new HashMap<>();
  // The filter of each layer this API added or filtered, as it was written, by layer id; JsonNull
  // for none. The engine turns a legacy filter into internal operators such as filter-==.
  private final Map<String, JsonElement> layerFilters = new HashMap<>();

  private Set<String> interactiveFeatureLayerIds;
  // GeoJSON last fed to each source added through addGeoJsonSource, kept for
  // setGeoJsonFeature. Holds the raw String until the first setFeature parses
  // it into a FeatureCollectionText, so plain data updates never pay a parse
  // on the platform thread.
  private Map<String, Object> addedFeaturesByLayer;

  private LatLngBounds bounds = null;
  Style.OnStyleLoaded onStyleLoadedCallback =
      new Style.OnStyleLoaded() {
        @Override
        public void onStyleLoaded(@NonNull Style style) {
          MapLibreMapController.this.style = style;
          // A new style brings its own transition, with placement transitions on.
          transitionBeforePlacementOff = null;
          applyPlacementTransitions(style);

          // Called unconditionally: updateMyLocationEnabled() checks myLocationEnabled
          // itself, and enableLocationComponent() checks the permission, so a map
          // without either ends up doing nothing here. Calling it on every style load
          // is what brings the location component back after the style is replaced or
          // the activity is recreated, which an early return would skip.
          updateMyLocationEnabled();

          if (null != bounds) {
            setCameraTargetBounds(bounds);
          }

          mapLibreMap.addOnMapClickListener(MapLibreMapController.this);
          mapLibreMap.addOnMapLongClickListener(MapLibreMapController.this);

          flutterApi.mapOnStyleLoaded(PigeonReplies.IGNORE);
        }
      };

  MapLibreMapController(
      int id,
      Context context,
      BinaryMessenger messenger,
      MapLibreMapsPlugin.LifecycleProvider lifecycleProvider,
      MapLibreMapOptions options,
      String styleStringInitial,
      boolean dragEnabled,
      boolean featureTapsTriggersMapClick
  ) {
    MapLibreUtils.getMapLibre(context);
    this.id = id;
    this.context = context;
    this.applicationContext =
        context.getApplicationContext() != null ? context.getApplicationContext() : context;
    this.mapLibreMapOptions = options;
    this.dragEnabled = dragEnabled;
    this.featureTapsTriggersMapClick = featureTapsTriggersMapClick;
    this.styleStringInitial = styleStringInitial;
    this.mapViewContainer = new FrameLayout(applicationContext);
    this.mapView = new MapView(context, options);
    this.interactiveFeatureLayerIds = new HashSet<>();
    this.addedFeaturesByLayer = new HashMap<String, Object>();
    this.density = context.getResources().getDisplayMetrics().density;
    this.lifecycleProvider = lifecycleProvider;
    if (dragEnabled) {
      this.androidGesturesManager = createDragGesturesManager(this.mapView.getContext());
    }

    mapViewContainer.addView(mapView);
    // The channels of this map are told apart by the view id, on both sides.
    this.messenger = messenger;
    this.flutterApi = new MapLibreMapFlutterApi(messenger, String.valueOf(id));
    MapLibreMapHostApi.Companion.setUp(messenger, new MapHostApi(this), String.valueOf(id));
  }

  @Override
  public View getView() {
    return mapViewContainer;
  }

  /**
   * Initial wire-up after construction. Order matters:
   * <ol>
   *   <li>Register component callbacks against the {@link #applicationContext}
   *       so we don't pin the host {@link android.app.Activity}.</li>
   *   <li>Subscribe to the host activity {@link Lifecycle}. Jetpack replays the
   *       missed events synchronously, which drives {@code mapView.onCreate()},
   *       {@code onStart()} and {@code onResume()} via our lifecycle observer
   *       methods. The {@link #savedMapViewState} bundle is empty here, which
   *       is equivalent to "no saved state" for MapLibre.</li>
   *   <li>Call {@link MapView#getMapAsync} only AFTER {@code onCreate} has fired,
   *       to comply with MapLibre's documented call order.</li>
   * </ol>
   */
  void init() {
    applicationContext.registerComponentCallbacks(this);
    registerToLifecycle();
    mapView.getMapAsync(this);
  }

  /**
   * Invoked by {@link MapLibreMapFactory} when the plugin re-attaches to an activity.
   * Triggered both on first attach and after a full activity teardown (e.g. with
   * "Don't keep activities" enabled). Refreshes context references, recreates the
   * {@link MapView} if the previous one was destroyed, and rebinds the new lifecycle.
   */
  void onActivityAttached() {
    rebindToActivity();
  }

  /**
   * Points the controller at the activity currently hosting it: refreshes the context
   * references, rebuilds the {@link MapView} if the previous one was destroyed, and
   * moves the lifecycle subscription to the new activity.
   *
   * <p>Shared by {@link #onActivityAttached()} and {@link #onActivityRebound()}. Both
   * hooks reach this in the same state, because in the Flutter standard ordering the
   * old activity's {@code onDestroy} has already torn the MapView down by the time
   * either runs; keeping one implementation is what stops the two paths drifting.
   */
  private void rebindToActivity() {
    if (disposed) {
      return;
    }

    unregisterFromLifecycle();
    updateActivityContext();

    final boolean recreated = (mapView == null);
    if (recreated) {
      recreateMapViewIfNecessary();
    }

    // Register the new lifecycle BEFORE getMapAsync so Jetpack's synchronous
    // replay drives mapView.onCreate(savedMapViewState) first. Calling
    // getMapAsync against a not-yet-created MapView is technically tolerated
    // by MapLibre but violates the documented contract.
    registerToLifecycle();

    if (recreated) {
      mapView.getMapAsync(this);
    }
  }

  /**
   * Invoked when the plugin is fully detached from the activity (i.e. the host
   * activity is being destroyed without a config change, e.g. "Don't keep
   * activities" or a real activity finish). Saves what state we can and tears
   * down the native {@link MapView}.
   */
  void onActivityDetached() {
    saveCameraPosition();
    destroyMapViewIfNecessary();
    unregisterFromLifecycle();
  }

  /**
   * Invoked after a configuration change (e.g. rotation). In the Flutter standard
   * ordering the old activity's {@code onDestroy} fires before this hook, so by
   * the time we get here the {@link MapView} has already been torn down via the
   * lifecycle observer and we go through the same path as a full re-attach. The
   * fast-path (mapView still alive) only triggers if reattachment somehow beats
   * the old activity's destroy callback. {@link #lastCameraPosition} and
   * {@link #savedMapViewState} bridge the gap either way.
   */
  void onActivityRebound() {
    rebindToActivity();
  }

  /**
   * Re-points {@link #context} at the freshly attached activity so we never hold a
   * destroyed activity reference. Also refreshes {@link #density} because display
   * configuration can change across activity recreation (font scale, display size).
   */
  private void updateActivityContext() {
    final Context activityContext = lifecycleProvider.getContext();
    if (activityContext != null) {
      this.context = activityContext;
      this.density = activityContext.getResources().getDisplayMetrics().density;
    }
  }

  private void registerToLifecycle() {
    Lifecycle lifecycle = lifecycleProvider.getLifecycle();
    if (lifecycle != null && lifecycle != boundLifecycle) {
      lifecycle.addObserver(this);
      boundLifecycle = lifecycle;
    }
  }

  private void unregisterFromLifecycle() {
    if (boundLifecycle != null) {
      boundLifecycle.removeObserver(this);
      boundLifecycle = null;
    }
  }

  private void saveCameraPosition() {
    if (mapLibreMap != null) {
      lastCameraPosition = mapLibreMap.getCameraPosition();
    }
  }

  /**
   * Builds a fresh {@link MapView} bound to the current activity context. Caller
   * must have already updated {@link #context} via {@link #updateActivityContext()}
   * and must call {@link MapView#getMapAsync} AFTER the lifecycle has been bound
   * (so {@code mapView.onCreate(savedMapViewState)} runs first via the lifecycle
   * observer replay).
   *
   * <p>State preserved across recreation:
   * <ul>
   *   <li>{@link #lastCameraPosition} (re-applied in {@link #onMapReady}).</li>
   *   <li>{@link #savedMapViewState} (handed to {@code mapView.onCreate}). MapLibre keeps
   *       the camera and its {@code UiSettings} there, so UI flags changed via
   *       {@link #mapUpdate} after construction come back with it: compass, logo and
   *       attribution visibility, gravity and margins, and the gesture toggles. The
   *       attribution tint is not in it and the pan inertia only partly, so
   *       {@link #onMapReady} re-applies both.</li>
   *   <li>Construction-time {@link MapLibreMapOptions} (UI flags, gestures, etc.).</li>
   *   <li>Controller fields like {@link #trackCameraPosition}, {@link #myLocationEnabled},
   *       {@link #myLocationTrackingMode}, {@link #myLocationRenderMode}, {@link #bounds}.</li>
   * </ul>
   *
   * <p>State lost across recreation (must be re-applied from Dart on
   * {@code onStyleLoadedCallback}):
   * <ul>
   *   <li>Sources / layers / images added at runtime from Dart.</li>
   *   <li>Style switched at runtime via {@code setStyleString} (reverts to the
   *       initial style).</li>
   *   <li>Runtime tweaks applied via {@link #mapUpdate} after construction that
   *       MapLibre does not keep in its state bundle, such as the min/max zoom
   *       preference.</li>
   *   <li>In-flight gestures handled by {@link AndroidGesturesManager}.</li>
   * </ul>
   */
  private void recreateMapViewIfNecessary() {
    if (mapView != null) {
      return;
    }

    final Context mapContext = (context != null) ? context : applicationContext;

    mapLibreMap = null;
    style = null;
    locationComponent = null;
    mapViewCreated = false;
    mapViewStarted = false;
    mapViewResumed = false;
    interactiveFeatureLayerIds.clear();
    addedFeaturesByLayer.clear();
    imageSourceCoordinates.clear();
    layerFilters.clear();

    mapViewContainer.removeAllViews();
    mapView = new MapView(mapContext, mapLibreMapOptions);
    if (dragEnabled) {
      androidGesturesManager = createDragGesturesManager(mapView.getContext());
    }
    mapViewContainer.addView(mapView);
    // NOTE: getMapAsync is intentionally NOT called here. The caller is responsible
    // for invoking it after registerToLifecycle() so that mapView.onCreate fires
    // first (see onActivityAttached / onActivityRebound).
  }

  private CameraPosition getCameraPosition() {
    if (!trackCameraPosition || mapLibreMap == null) {
      return null;
    }
    return mapLibreMap.getCameraPosition();
  }

  @Override
  public void onMapReady(MapLibreMap mapLibreMap) {
    this.mapLibreMap = mapLibreMap;
    if (mapReadyResult != null) {
      mapReadyResult.success(null);
      mapReadyResult = null;
    }
    mapLibreMap.addOnCameraMoveStartedListener(this);
    mapLibreMap.addOnCameraMoveListener(this);
    mapLibreMap.addOnCameraIdleListener(this);

    // Re-apply an app-provided attribution tint: UiSettings belongs to the
    // MapView, so a recreated view (activity rebind) would otherwise fall back
    // to the SDK default. Without the option we leave that default alone.
    if (attributionButtonColor != null) {
      mapLibreMap.getUiSettings().setAttributionTintColor(attributionButtonColor);
    }

    // Re-apply the pan inertia for the same reason: it lives on UiSettings.
    applyPanInertia();

    // Apply camera target bounds if set during initialization
    if (bounds != null) {
      mapLibreMap.setLatLngBoundsForCameraTarget(bounds);
    }

    // Camera restoration after activity recreation.
    // Priority order:
    //   1. lastCameraPosition saved before the previous MapView was destroyed.
    //   2. initial camera supplied via MapLibreMapOptions (covers the edge case
    //      where the previous MapView was destroyed before onMapReady ever ran,
    //      so lastCameraPosition was never populated).
    CameraPosition restorePosition = lastCameraPosition;
    if (restorePosition == null) {
      restorePosition = mapLibreMapOptions.getCamera();
    }
    if (restorePosition != null) {
      mapLibreMap.moveCamera(CameraUpdateFactory.newCameraPosition(restorePosition));
      lastCameraPosition = null;
    }

    if (androidGesturesManager != null) {
      androidGesturesManager.setMoveGestureListener(new MoveGestureListener());
    }
    tapDetector =
        new GestureDetector(
            mapView.getContext(),
            new GestureDetector.SimpleOnGestureListener() {
              @Override
              public boolean onSingleTapUp(MotionEvent event) {
                if (reportsTapsOnTouchUp()) {
                  final PointF pointf = new PointF(event.getX(), event.getY());
                  reportTap(pointf, mapLibreMap.getProjection().fromScreenLocation(pointf));
                  tapReportedOnTouchUp = true;
                }
                return true;
              }
            });
    // The listener is also a double-tap listener, which would make the detector wait.
    tapDetector.setOnDoubleTapListener(null);
    mapView.setOnTouchListener(
        new View.OnTouchListener() {
          @Override
          public boolean onTouch(View v, MotionEvent event) {
            return onMapTouch(v, event);
          }
        });

    mapView.addOnStyleImageMissingListener(
        (id) -> {
          DisplayMetrics displayMetrics = context.getResources().getDisplayMetrics();
          final Bitmap bitmap =
              AssetIcons.load(
                  mapView.getContext().getAssets(),
                  MapLibreMapsPlugin.flutterAssets.getAssetFilePathByName(id),
                  displayMetrics.density);
          if (bitmap != null) {
            mapLibreMap.getStyle().addImage(id, bitmap);
          }
        });

    mapView.addOnDidBecomeIdleListener(this);

    setStyleString(styleStringInitial);
  }

  @Override
  public void setStyleString(@NonNull String styleString) {
    // clear old layer id from the location Component
    clearLocationComponentLayer();
    styleString = styleString.trim();

    // Prevent race conditions: invalidate current style reference & interactive layers
    // Old Style instances become invalid immediately after setStyle is called.
    this.style = null;
    if (interactiveFeatureLayerIds != null) {
      interactiveFeatureLayerIds.clear();
    }
    // The data of the old style's sources must not come back through setGeoJsonFeature.
    addedFeaturesByLayer.clear();
    imageSourceCoordinates.clear();
    layerFilters.clear();

    // Check if json, url, absolute path or asset path:
    if (styleString == null || styleString.isEmpty()) {
      Log.e(TAG, "setStyleString - string empty or null");
    } else if (styleString.startsWith("{") || styleString.startsWith("[")) {
      mapLibreMap.setStyle(new Style.Builder().fromJson(styleString), onStyleLoadedCallback);
    } else if (styleString.startsWith("/")) {
      // Absolute path
      mapLibreMap.setStyle(
          new Style.Builder().fromUri("file://" + styleString), onStyleLoadedCallback);
    } else if (!styleString.startsWith("http://")
        && !styleString.startsWith("https://")
        && !styleString.startsWith("mapbox://")) {
      // We are assuming that the style will be loaded from an asset here.
      String key = MapLibreMapsPlugin.flutterAssets.getAssetFilePathByName(styleString);
      mapLibreMap.setStyle(new Style.Builder().fromUri("asset://" + key), onStyleLoadedCallback);
    } else {
      mapLibreMap.setStyle(new Style.Builder().fromUri(styleString), onStyleLoadedCallback);
    }
  }



  @SuppressWarnings({"MissingPermission"})
  private void enableLocationComponent(@NonNull Style style) {
    if (manualLocationSource || hasLocationPermission()) {

      locationComponent = mapLibreMap.getLocationComponent();

      LocationComponentActivationOptions.Builder optionsBuilder =
              LocationComponentActivationOptions
                      .builder(context, style)
                      .locationComponentOptions(buildLocationComponentOptions(style));
      if (manualLocationSource) {
        // App-provided locations: disable the native engine. Updates arrive via
        // locationComponentSetManualLocation -> forceLocationUpdate(location).
        optionsBuilder.useDefaultLocationEngine(false);
      } else {
        optionsBuilder.locationEngine(myLocationEngineFactory.getLocationEngine(context));
      }

      locationComponent.activateLocationComponent(optionsBuilder.build());
      locationComponent.setLocationComponentEnabled(true);
      locationComponent.setMaxAnimationFps(30);
      updateMyLocationTrackingMode();
      updateMyLocationRenderMode();
      locationComponent.addOnCameraTrackingChangedListener(this);
    } else {
      Log.e(TAG, "missing location permissions");
    }
  }

  private void updateLocationComponentLayer() {
    if (locationComponent != null && locationComponentRequiresUpdate()) {
      locationComponent.applyStyle(buildLocationComponentOptions(style));
    }
  }

  private void clearLocationComponentLayer() {
    if (locationComponent != null) {
      locationComponent.applyStyle(buildLocationComponentOptions(null));
    }
  }

  String getLastLayerOnStyle(Style style) {
    if (style == null) return null;
    if (!style.isFullyLoaded()) {
        Log.d(TAG, "getLastLayerOnStyle: style not fully loaded yet");
        return null;
    }
    
    final List<Layer> layers = style.getLayers();
    if (layers.size() > 0) {
      return layers.get(layers.size() - 1).getId();
    }

    return null;
  }

  /**
   * The topmost style layer that is not one of the location component's own layers. applyStyle
   * removes those layers before adding them back above this one, so pointing it at one of them
   * fails with "Could not find layer". Before the component has added its layers, or when they
   * are not on top, this is the last layer of the style.
   */
  String getTopLayerBelowLocationComponent(Style style) {
    if (style == null || !style.isFullyLoaded()) return null;
    final List<Layer> layers = style.getLayers();
    for (int i = layers.size() - 1; i >= 0; i--) {
      final String id = layers.get(i).getId();
      if (!id.startsWith(LOCATION_COMPONENT_LAYER_PREFIX)) return id;
    }
    return null;
  }

  /// only update if the last layer is not the mapbox-location-bearing-layer
  boolean locationComponentRequiresUpdate() {
    final String lastLayerId = getLastLayerOnStyle(style);
    return lastLayerId != null && !lastLayerId.equals("mapbox-location-bearing-layer");
  }

  private LocationComponentOptions buildLocationComponentOptions(Style style) {
    final LocationComponentOptions.Builder optionsBuilder =
        LocationComponentOptions.builder(context);
    optionsBuilder.trackingGesturesManagement(true);
    myLocationStyle.applyTo(optionsBuilder);

    final String lastLayerId = getTopLayerBelowLocationComponent(style);
    if (lastLayerId != null) {
      optionsBuilder.layerAbove(lastLayerId);
    }
    return optionsBuilder.build();
  }

  private void onUserLocationUpdate(Location location) {
    if (location == null) {
      return;
    }

    // Absent before API 26, which has no vertical accuracy.
    Double verticalAccuracy = null;
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      verticalAccuracy = (double) location.getVerticalAccuracyMeters();
    }
    final PgUserLocation userLocation =
        new PgUserLocation(
            new PgLatLng(location.getLatitude(), location.getLongitude()),
            location.getAltitude(),
            (double) location.getBearing(),
            (double) location.getSpeed(),
            (double) location.getAccuracy(),
            verticalAccuracy,
            location.getTime());
    // Android reports no compass heading with the location.
    flutterApi.mapOnUserLocationUpdated(userLocation, null, PigeonReplies.IGNORE);
  }

  // The layer's style-spec JSON, or null if the layer is absent. Read from the
  // runtime layer: style.getJson() is the style as loaded, without the layers
  // and properties set since.
  @Nullable
  private String getLayerProperties(String layerId) {
    final Layer layer = style.getLayer(layerId);
    if (layer == null) {
      return null;
    }
    final String type = LayerPropertyConverter.layerType(layer);
    if (type == null) {
      // Not a style-spec layer type (a CustomLayer): only the loaded style can
      // describe it, if it came with it.
      JsonObject loaded = findLoadedLayer(layerId);
      return loaded != null ? loaded.toString() : null;
    }

    final JsonObject json = new JsonObject();
    json.addProperty("id", layerId);
    json.addProperty("type", type);
    String sourceId = null;
    String sourceLayer = null;
    if (layer instanceof SymbolLayer) {
      sourceId = ((SymbolLayer) layer).getSourceId();
      sourceLayer = ((SymbolLayer) layer).getSourceLayer();
    } else if (layer instanceof CircleLayer) {
      sourceId = ((CircleLayer) layer).getSourceId();
      sourceLayer = ((CircleLayer) layer).getSourceLayer();
    } else if (layer instanceof LineLayer) {
      sourceId = ((LineLayer) layer).getSourceId();
      sourceLayer = ((LineLayer) layer).getSourceLayer();
    } else if (layer instanceof FillLayer) {
      sourceId = ((FillLayer) layer).getSourceId();
      sourceLayer = ((FillLayer) layer).getSourceLayer();
    } else if (layer instanceof FillExtrusionLayer) {
      sourceId = ((FillExtrusionLayer) layer).getSourceId();
      sourceLayer = ((FillExtrusionLayer) layer).getSourceLayer();
    } else if (layer instanceof HeatmapLayer) {
      sourceId = ((HeatmapLayer) layer).getSourceId();
      sourceLayer = ((HeatmapLayer) layer).getSourceLayer();
    } else if (layer instanceof ColorReliefLayer) {
      sourceId = ((ColorReliefLayer) layer).getSourceId();
      sourceLayer = ((ColorReliefLayer) layer).getSourceLayer();
    } else if (layer instanceof RasterLayer) {
      sourceId = ((RasterLayer) layer).getSourceId();
    } else if (layer instanceof HillshadeLayer) {
      sourceId = ((HillshadeLayer) layer).getSourceId();
    }
    if (sourceId != null && !sourceId.isEmpty()) {
      json.addProperty("source", sourceId);
    }
    if (sourceLayer != null && !sourceLayer.isEmpty()) {
      json.addProperty("source-layer", sourceLayer);
    }
    // The SDK reports the spec defaults (0 and 24) for an unset zoom range,
    // which a style JSON leaves out.
    if (layer.getMinZoom() > 0) {
      json.addProperty("minzoom", layer.getMinZoom());
    }
    if (layer.getMaxZoom() < 24) {
      json.addProperty("maxzoom", layer.getMaxZoom());
    }
    // Read like getLayerFilter.
    try {
      final JsonElement filter = isFilterable(layer) ? layerFilter(layer) : null;
      if (filter != null) {
        json.add("filter", filter);
      }
    } catch (ReflectiveOperationException e) {
      // Leave the filter out rather than fail the whole read.
    }
    final JsonObject paint = new JsonObject();
    final JsonObject layout = new JsonObject();
    LayerPropertyConverter.readLayerProperties(layer, paint, layout);
    json.add("paint", paint);
    json.add("layout", layout);
    return json.toString();
  }

  // The layer entry of the style as it was loaded, or null.
  private JsonObject findLoadedLayer(String layerId) {
    JsonObject styleJson = JsonParser.parseString(style.getJson()).getAsJsonObject();
    JsonArray layers = styleJson.getAsJsonArray("layers");
    if (layers != null) {
      for (JsonElement element : layers) {
        JsonObject layer = element.getAsJsonObject();
        JsonElement id = layer.get("id");
        if (id != null && layerId.equals(id.getAsString())) {
          return layer;
        }
      }
    }
    return null;
  }

  // Same as getLayerProperties but for sources. A source that came with the
  // style is read from the loaded style JSON, the only place holding all of
  // its properties (data, tiles, ...). The SDK exposes little on a runtime
  // source, so one added later reports its type, its url and its attribution.
  @Nullable
  private String getSourceProperties(String sourceId) {
    final Source source = style.getSource(sourceId);
    if (source == null) {
      return null;
    }
    JsonObject styleJson = JsonParser.parseString(style.getJson()).getAsJsonObject();
    JsonObject sources = styleJson.getAsJsonObject("sources");
    final JsonObject loaded =
        sources != null && sources.has(sourceId) ? sources.getAsJsonObject(sourceId) : null;
    if (source instanceof ImageSource) {
      return imageSourceProperties(sourceId, (ImageSource) source, loaded).toString();
    }
    if (loaded != null) {
      return loaded.toString();
    }

    final JsonObject json = new JsonObject();
    if (source instanceof GeoJsonSource) {
      json.addProperty("type", "geojson");
      final String uri = ((GeoJsonSource) source).getUri();
      if (uri != null && !uri.isEmpty()) {
        json.addProperty("data", uri);
      }
    } else if (source instanceof VectorSource) {
      json.addProperty("type", "vector");
      putIfNotEmpty(json, "url", ((VectorSource) source).getUri());
    } else if (source instanceof RasterDemSource) {
      json.addProperty("type", "raster-dem");
      putIfNotEmpty(json, "url", ((RasterDemSource) source).getUri());
    } else if (source instanceof RasterSource) {
      json.addProperty("type", "raster");
      putIfNotEmpty(json, "url", ((RasterSource) source).getUri());
    } else {
      // Not a style-spec source type (a custom geometry source).
      return null;
    }
    putIfNotEmpty(json, "attribution", source.getAttribution());
    return json.toString();
  }

  /**
   * The style-spec entry of an image source: type, the url when it has one, and four [lng, lat]
   * corners from the top left clockwise.
   */
  private JsonObject imageSourceProperties(
      String sourceId, ImageSource source, @Nullable JsonObject loaded) {
    final JsonObject json = new JsonObject();
    json.addProperty("type", "image");
    putIfNotEmpty(json, "url", source.getUri());
    final LatLngQuad quad = imageSourceCoordinates.get(sourceId);
    if (quad != null) {
      final JsonArray corners = new JsonArray();
      for (LatLng corner :
          new LatLng[] {
            quad.getTopLeft(), quad.getTopRight(), quad.getBottomRight(), quad.getBottomLeft()
          }) {
        final JsonArray pair = new JsonArray();
        pair.add(corner.getLongitude());
        pair.add(corner.getLatitude());
        corners.add(pair);
      }
      json.add("coordinates", corners);
    } else if (loaded != null && loaded.has("coordinates")) {
      json.add("coordinates", loaded.get("coordinates"));
    }
    return json;
  }

  private static void putIfNotEmpty(JsonObject json, String key, String value) {
    if (value != null && !value.isEmpty()) {
      json.addProperty(key, value);
    }
  }

  // Resolves the source a feature-state call addresses, or replies with a
  // descriptive error and returns null so the caller can just bail out.
  //
  // The Android SDK exposes feature state on the source objects themselves
  // (there is no MapLibreMap-level entry point), and only GeoJsonSource and
  // VectorSource carry the API. On a vector source every call is additionally
  // scoped to a source layer, so a missing sourceLayer would leave the call
  // with nothing to address; that is rejected here once instead of in each
  // feature-state call.
  private Source getFeatureStateCapableSource(
      String sourceId, String sourceLayer, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return null;
    }
    final Source source = style.getSource(sourceId);
    if (source == null) {
      replySourceNotFound(result, sourceId);
      return null;
    }
    if (source instanceof VectorSource) {
      if (sourceLayer == null) {
        result.error(
            StyleChecks.SOURCE_LAYER_REQUIRED,
            "Source '"
                + sourceId
                + "' is a vector source, so feature state calls on it require a 'sourceLayer'.",
            null);
        return null;
      }
      return source;
    }
    if (source instanceof GeoJsonSource) {
      return source;
    }
    result.error(
        StyleChecks.UNSUPPORTED_SOURCE_TYPE,
        "Source '"
            + sourceId
            + "' is a "
            + source.getClass().getSimpleName()
            + ". Feature state only applies to GeoJSON and vector sources.",
        null);
    return null;
  }

  // Resolves the GeoJSON source a cluster-inspection call addresses, or replies
  // with a descriptive error and returns null so the caller can just bail out.
  //
  // Clustering is a GeoJSON source feature, and the Android SDK exposes the
  // inspection methods on GeoJsonSource only.
  private GeoJsonSource getClusterCapableSource(
      String sourceId, String methodName, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return null;
    }
    final Source source = style.getSource(sourceId);
    if (source == null) {
      replySourceNotFound(result, sourceId);
      return null;
    }
    if (source instanceof GeoJsonSource) {
      return (GeoJsonSource) source;
    }
    result.error(
        StyleChecks.UNSUPPORTED_SOURCE_TYPE,
        StyleChecks.notGeoJsonSource(sourceId, methodName, true),
        null);
    return null;
  }

  // Builds the argument the SDK's cluster methods take.
  //
  // They are declared as taking a Feature, but everything below them reads a
  // single property off it: the JNI layer copies properties.cluster_id and the
  // renderer looks up that id in the source's supercluster index, ignoring the
  // geometry and every other property. A minimal point feature carrying the id
  // is therefore the whole input, which is what lets the Dart API be an int.
  private static Feature clusterFeature(long clusterId) {
    final JsonObject properties = new JsonObject();
    properties.addProperty("cluster_id", clusterId);
    return Feature.fromGeometry(Point.fromLngLat(0, 0), properties);
  }

  // Whether the source currently holds a cluster with this id.
  //
  // For an id it does not hold, MapLibre Native throws "No cluster with the
  // specified id." on the render thread, where nothing here can catch it, and
  // the app dies. Ids go stale as the data or the viewport changes, so an app
  // can pass one without doing anything wrong. Looking the id up first lets the
  // cluster calls reply CLUSTER_NOT_FOUND instead. Only loaded tiles are
  // searched, which holds for any id the app just read off a feature on screen.
  private static boolean hasCluster(GeoJsonSource source, long clusterId) {
    final List<Feature> clusters =
        source.querySourceFeatures(
            Expression.eq(Expression.get("cluster_id"), Expression.literal(clusterId)));
    return clusters != null && !clusters.isEmpty();
  }

  private static void clusterNotFound(MethodChannel.Result result, String sourceId, long clusterId) {
    result.error(
        "CLUSTER_NOT_FOUND",
        "Cluster '"
            + clusterId
            + "' is not one of the current clusters of source '"
            + sourceId
            + "'. Cluster ids are reassigned as the data or the viewport changes, so read the"
            + " id from a freshly queried feature.",
        null);
  }

  // Every feature the SDK answers with reaches Dart through FeatureJson.
  private static List<String> featuresReply(List<Feature> features) {
    return FeatureJson.of(features);
  }

  // The cluster calls answer with a FeatureCollection, which is null when the
  // id matches nothing.
  private static List<String> featuresReply(FeatureCollection collection) {
    return featuresReply(collection == null ? null : collection.features());
  }

  /**
   * Adds a GeoJSON source with {@code source}, its data. Answers STYLE_NOT_READY without a style.
   */
  private void addGeoJsonSource(String sourceName, String source, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }

    try {
      // synchronousUpdate causes a texture atlas slot-reuse bug in MapLibre Native Android SDK
      // that silently discards icons registered via addImage() in the same render frame.
      // Disabled unconditionally until upstream maplibre-native#4326 is fixed.
      GeoJsonOptions options = new GeoJsonOptions().withSynchronousUpdate(false);
      // The raw JSON goes to the engine, which parses it off the platform
      // thread and keeps numeric ids numeric. A Java FeatureCollection would
      // turn every id into a String, so ["id"] filters on numbers would miss.
      GeoJsonSource geoJsonSource = new GeoJsonSource(sourceName, source, options);
      style.addSource(geoJsonSource);
      // Replaces the data of any earlier source with this id.
      addedFeaturesByLayer.put(sourceName, source);
      imageSourceCoordinates.remove(sourceName);
    } catch (Exception e) {
      Log.e(TAG, "addGeoJsonSource: error adding source '" + sourceName + "'", e);
    }
    result.success(null);
  }

  /**
   * The GeoJSON source {@code sourceId} that {@code methodName} works on, or null after answering
   * STYLE_NOT_READY without a style, SOURCE_NOT_FOUND without the source and
   * UNSUPPORTED_SOURCE_TYPE for a source of another type.
   */
  @Nullable
  private GeoJsonSource geoJsonSource(
      String sourceId, String methodName, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return null;
    }
    final Source source = style.getSource(sourceId);
    if (source == null) {
      replySourceNotFound(result, sourceId);
      return null;
    }
    if (!(source instanceof GeoJsonSource)) {
      result.error(
          StyleChecks.UNSUPPORTED_SOURCE_TYPE,
          StyleChecks.notGeoJsonSource(sourceId, methodName, false),
          null);
      return null;
    }
    return (GeoJsonSource) source;
  }

  /**
   * Replaces the data of the GeoJSON source {@code sourceName}. Answers what {@link
   * #geoJsonSource} answers for a source it cannot change.
   */
  private void setGeoJsonSource(String sourceName, String geojson, MethodChannel.Result result) {
    final GeoJsonSource source = geoJsonSource(sourceName, "setGeoJsonSource", result);
    if (source == null) {
      return;
    }

    try {
      // Raw JSON for the same reason as in addGeoJsonSource.
      addedFeaturesByLayer.put(sourceName, geojson);
      source.setGeoJson(geojson);
    } catch (Exception e) {
      Log.e(TAG, "setGeoJsonSource: error updating source '" + sourceName + "'", e);
    }
    result.success(null);
  }

  // The source data as a FeatureCollection, parsed on first use and cached, or
  // null when it is neither a FeatureCollection nor a Feature.
  private FeatureCollectionText parsedSourceData(String sourceName) {
    final Object stored = addedFeaturesByLayer.get(sourceName);
    if (stored instanceof FeatureCollectionText) {
      return (FeatureCollectionText) stored;
    }
    if (!(stored instanceof String)) {
      return null;
    }
    final FeatureCollectionText collection = FeatureCollectionText.parse((String) stored);
    if (collection != null) {
      addedFeaturesByLayer.put(sourceName, collection);
    }
    return collection;
  }

  /**
   * Replaces the feature with the id of {@code geojsonFeature} in the data addGeoJsonSource or
   * setGeoJsonSource gave {@code sourceName}. Answers what {@link #geoJsonSource} answers for a
   * source it cannot change, and INVALID_GEOJSON for anything but a Feature. A source added some
   * other way, or an id its data does not hold, changes nothing.
   */
  private void setGeoJsonFeature(
      String sourceName, String geojsonFeature, MethodChannel.Result result) {
    final GeoJsonSource source = geoJsonSource(sourceName, "setGeoJsonFeature", result);
    if (source == null) {
      return;
    }
    JsonElement feature;
    try {
      feature = JsonParser.parseString(geojsonFeature);
    } catch (JsonParseException e) {
      feature = null;
    }
    if (!isGeoJsonFeature(feature)) {
      result.error(
          "INVALID_GEOJSON",
          "The feature for source '" + sourceName + "' is not a GeoJSON Feature.",
          null);
      return;
    }

    try {
      final FeatureCollectionText data = parsedSourceData(sourceName);
      // Merged as JSON rather than through the Java Feature, which would turn
      // the ids of the whole source into Strings.
      if (data != null && data.replace(feature)) {
        source.setGeoJson(data.toJson());
      }
    } catch (Exception e) {
      Log.e(TAG, "setGeoJsonFeature: error updating feature in source '" + sourceName + "'", e);
    }
    result.success(null);
  }

  private static boolean isGeoJsonFeature(@Nullable JsonElement json) {
    if (json == null || !json.isJsonObject()) {
      return false;
    }
    final JsonElement type = json.getAsJsonObject().get("type");
    return type != null
        && type.isJsonPrimitive()
        && type.getAsJsonPrimitive().isString()
        && "Feature".equals(type.getAsString());
  }

  private boolean addSymbolLayer(
      String layerName,
      String sourceName,
      String belowLayerId,
      String sourceLayer,
      Float minZoom,
      Float maxZoom,
      PropertyValue[] properties,
      boolean enableInteraction,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addSymbolLayer: style not ready, skipping");
      return false;
    }
    SymbolLayer symbolLayer = new SymbolLayer(layerName, sourceName);
    symbolLayer.setProperties(properties);
    if (sourceLayer != null) {
      symbolLayer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      symbolLayer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      symbolLayer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      symbolLayer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(symbolLayer, belowLayerId);
    } else {
      style.addLayer(symbolLayer);
    }
    if (enableInteraction) {
      interactiveFeatureLayerIds.add(layerName);
    }
    return true;
  }

  private boolean addLineLayer(
      String layerName,
      String sourceName,
      String belowLayerId,
      String sourceLayer,
      Float minZoom,
      Float maxZoom,
      PropertyValue[] properties,
      boolean enableInteraction,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addLineLayer: style not ready, skipping");
      return false;
    }
    LineLayer lineLayer = new LineLayer(layerName, sourceName);
    lineLayer.setProperties(properties);
    if (sourceLayer != null) {
      lineLayer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      lineLayer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      lineLayer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      lineLayer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(lineLayer, belowLayerId);
    } else {
      style.addLayer(lineLayer);
    }
    if (enableInteraction) {
      interactiveFeatureLayerIds.add(layerName);
    }
    return true;
  }

  private boolean addFillLayer(
      String layerName,
      String sourceName,
      String belowLayerId,
      String sourceLayer,
      Float minZoom,
      Float maxZoom,
      PropertyValue[] properties,
      boolean enableInteraction,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addFillLayer: style not ready, skipping");
      return false;
    }
    FillLayer fillLayer = new FillLayer(layerName, sourceName);
    fillLayer.setProperties(properties);
    if (sourceLayer != null) {
      fillLayer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      fillLayer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      fillLayer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      fillLayer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(fillLayer, belowLayerId);
    } else {
      style.addLayer(fillLayer);
    }
    if (enableInteraction) {
      interactiveFeatureLayerIds.add(layerName);
    }
    return true;
  }

  private boolean addFillExtrusionLayer(
          String layerName,
          String sourceName,
          String belowLayerId,
          String sourceLayer,
          Float minZoom,
          Float maxZoom,
          PropertyValue[] properties,
          boolean enableInteraction,
          Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addFillExtrusionLayer: style not ready, skipping");
      return false;
    }
    FillExtrusionLayer fillLayer = new FillExtrusionLayer(layerName, sourceName);
    fillLayer.setProperties(properties);
    if (sourceLayer != null) {
      fillLayer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      fillLayer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      fillLayer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      fillLayer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(fillLayer, belowLayerId);
    } else {
      style.addLayer(fillLayer);
    }
    if (enableInteraction) {
      interactiveFeatureLayerIds.add(layerName);
    }
    return true;
  }

  private boolean addCircleLayer(
      String layerName,
      String sourceName,
      String belowLayerId,
      String sourceLayer,
      Float minZoom,
      Float maxZoom,
      PropertyValue[] properties,
      boolean enableInteraction,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addCircleLayer: style not ready, skipping");
      return false;
    }
    CircleLayer circleLayer = new CircleLayer(layerName, sourceName);
    circleLayer.setProperties(properties);
    if (sourceLayer != null) {
      circleLayer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      circleLayer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      circleLayer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      circleLayer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(circleLayer, belowLayerId);
    } else {
      style.addLayer(circleLayer);
    }
    if (enableInteraction) {
      interactiveFeatureLayerIds.add(layerName);
    }
    return true;
  }

  /**
   * Parses {@code filter}, the JSON text of an expression or a boolean, into a layer filter. Null
   * and the text {@code null} mean no filter.
   *
   * @throws IllegalArgumentException, saying why, for text that is not JSON or not a filter.
   */
  @Nullable
  static Expression parseFilter(@Nullable String filter) {
    if (filter == null) {
      return null;
    }
    JsonElement json = PigeonConvert.parseFilterJson(filter);
    if (json.isJsonNull()) {
      return null;
    }
    return toFilterExpression(json);
  }

  /**
   * Converts {@code json}, an expression array or a boolean, into a filter expression with exact
   * numbers. Whether the engine accepts it is not checked here.
   *
   * @throws IllegalArgumentException for any other value, or an array that does not start with the
   *     name of an operator.
   */
  static Expression toFilterExpression(JsonElement json) {
    if (json.isJsonArray()) {
      JsonArray array = json.getAsJsonArray();
      boolean namesOperator =
          array.size() > 0
              && array.get(0).isJsonPrimitive()
              && array.get(0).getAsJsonPrimitive().isString();
      if (!namesOperator) {
        throw new IllegalArgumentException("An expression starts with the name of its operator.");
      }
    } else if (!json.isJsonPrimitive() || !json.getAsJsonPrimitive().isBoolean()) {
      throw new IllegalArgumentException("A filter is an expression array or a boolean.");
    }
    // Hand the engine the JSON as plain values. Expression.Converter would
    // turn every number into a float, so an id like 123456789 became 123456792.
    Object value = jsonToValue(json);
    final Object[] array = value instanceof Object[] ? (Object[]) value : new Object[] {"literal", value};
    return new Expression("literal") {
      @NonNull
      @Override
      public Object[] toArray() {
        return array;
      }
    };
  }

  private static Object jsonToValue(JsonElement json) {
    if (json.isJsonArray()) {
      JsonArray array = json.getAsJsonArray();
      Object[] values = new Object[array.size()];
      for (int i = 0; i < values.length; i++) {
        values[i] = jsonToValue(array.get(i));
      }
      return values;
    }
    if (json.isJsonObject()) {
      Map<String, Object> values = new HashMap<>();
      for (Map.Entry<String, JsonElement> entry : json.getAsJsonObject().entrySet()) {
        values.put(entry.getKey(), jsonToValue(entry.getValue()));
      }
      return values;
    }
    if (json.isJsonNull()) {
      return null;
    }
    JsonPrimitive primitive = json.getAsJsonPrimitive();
    if (primitive.isBoolean()) {
      return primitive.getAsBoolean();
    }
    if (primitive.isNumber()) {
      return primitive.getAsDouble();
    }
    return primitive.getAsString();
  }

  private static boolean isFilterable(Layer layer) {
    return layer instanceof CircleLayer
        || layer instanceof FillExtrusionLayer
        || layer instanceof FillLayer
        || layer instanceof HeatmapLayer
        || layer instanceof LineLayer
        || layer instanceof SymbolLayer;
  }

  private static void setLayerFilter(Layer layer, Expression filter) {
    if (layer instanceof CircleLayer) {
      ((CircleLayer) layer).setFilter(filter);
    } else if (layer instanceof FillExtrusionLayer) {
      ((FillExtrusionLayer) layer).setFilter(filter);
    } else if (layer instanceof FillLayer) {
      ((FillLayer) layer).setFilter(filter);
    } else if (layer instanceof HeatmapLayer) {
      ((HeatmapLayer) layer).setFilter(filter);
    } else if (layer instanceof LineLayer) {
      ((LineLayer) layer).setFilter(filter);
    } else if (layer instanceof SymbolLayer) {
      ((SymbolLayer) layer).setFilter(filter);
    }
  }

  private static final String FILTER_ERROR_PREFIX = "Error setting filter: ";
  private static final String PROPERTY_ERROR_PREFIX = "Error setting property: ";

  /**
   * Runs {@code action} and returns why the engine rejected a filter meanwhile, or null. The engine
   * does not throw for an invalid filter: it logs the reason and keeps the old filter.
   */
  private static String captureFilterError(Runnable action) {
    return captureEngineError(FILTER_ERROR_PREFIX, action);
  }

  /** Runs {@code action} and returns what the engine logged after {@code prefix} meanwhile, or null. */
  @Nullable
  private static String captureEngineError(String prefix, Runnable action) {
    try (EngineErrors errors = new EngineErrors(prefix)) {
      action.run();
      return errors.take();
    }
  }

  /** The fields of the SDK logger, read once, or null when this SDK has other ones. */
  @Nullable private static final Field LOGGER_FIELD = loggerField("logger");

  @Nullable private static final Field LOG_LEVEL_FIELD = loggerField("logLevel");

  @Nullable
  private static Field loggerField(String name) {
    try {
      final Field field = Logger.class.getDeclaredField(name);
      field.setAccessible(true);
      return field;
    } catch (ReflectiveOperationException | RuntimeException e) {
      return null;
    }
  }

  /**
   * Records what the engine logs after a prefix, from when it is created until it is closed. The
   * engine logs a rejected filter or property instead of throwing. The SDK logger is swapped for a
   * recording one, which works even when the app silenced logging.
   */
  private static final class EngineErrors implements AutoCloseable {
    @Nullable private final LoggerDefinition previous;
    private final int previousLevel;
    @Nullable private String error;

    EngineErrors(String prefix) {
      LoggerDefinition logger = null;
      int level = 0;
      if (LOGGER_FIELD != null && LOG_LEVEL_FIELD != null) {
        try {
          logger = (LoggerDefinition) LOGGER_FIELD.get(null);
          level = LOG_LEVEL_FIELD.getInt(null);
        } catch (ReflectiveOperationException e) {
          logger = null;
        }
      }
      previous = logger;
      previousLevel = level;
      if (previous == null) {
        return;
      }
      Logger.setLoggerDefinition(
          new ForwardingLogger(previous) {
            @Override
            public void e(String tag, String msg) {
              // The engine prefixes its messages, e.g. "{main}[JNI]: Error setting filter: ...".
              int start = msg == null ? -1 : msg.indexOf(prefix);
              if (error == null && start >= 0) {
                error = msg.substring(start + prefix.length());
              }
              if (previousLevel <= Logger.ERROR) {
                super.e(tag, msg);
              }
            }
          });
      Logger.setVerbosity(Math.min(previousLevel, Logger.ERROR));
    }

    /** What the engine logged since the last take, or null. */
    @Nullable
    String take() {
      final String logged = error;
      error = null;
      return logged;
    }

    @Override
    public void close() {
      if (previous != null) {
        Logger.setLoggerDefinition(previous);
        Logger.setVerbosity(previousLevel);
      }
    }
  }

  /** A logger that passes every message on to {@code target}. */
  private static class ForwardingLogger implements LoggerDefinition {
    private final LoggerDefinition target;

    ForwardingLogger(LoggerDefinition target) {
      this.target = target;
    }

    @Override public void v(String tag, String msg) { target.v(tag, msg); }
    @Override public void v(String tag, String msg, Throwable tr) { target.v(tag, msg, tr); }
    @Override public void d(String tag, String msg) { target.d(tag, msg); }
    @Override public void d(String tag, String msg, Throwable tr) { target.d(tag, msg, tr); }
    @Override public void i(String tag, String msg) { target.i(tag, msg); }
    @Override public void i(String tag, String msg, Throwable tr) { target.i(tag, msg, tr); }
    @Override public void w(String tag, String msg) { target.w(tag, msg); }
    @Override public void w(String tag, String msg, Throwable tr) { target.w(tag, msg, tr); }
    @Override public void e(String tag, String msg) { target.e(tag, msg); }
    @Override public void e(String tag, String msg, Throwable tr) { target.e(tag, msg, tr); }
  }

  /**
   * The filter of {@code layer} as it was written, or null without one: as this API set it, else
   * as the style wrote it. The engine turns a legacy filter into internal operators, such as
   * {@code filter-==}, so only a layer added some other way is read from the engine.
   */
  @Nullable
  private JsonElement layerFilter(Layer layer) throws ReflectiveOperationException {
    JsonElement filter;
    if (layerFilters.containsKey(layer.getId())) {
      filter = layerFilters.get(layer.getId());
    } else {
      final JsonObject loaded = findLoadedLayer(layer.getId());
      if (loaded == null) {
        return getRawFilter(layer);
      }
      filter = loaded.get("filter");
    }
    return filter == null || filter.isJsonNull() ? null : filter;
  }

  /** The filter text of a layer add or of setFilter as JSON, JsonNull for none. */
  private static JsonElement filterJson(@Nullable String filter) {
    return filter == null ? JsonNull.INSTANCE : PigeonConvert.parseFilterJson(filter);
  }

  /**
   * The filter of {@code layer} as the engine holds it, or null without one. Layer.getFilter
   * rounds numbers to floats, so this calls the native getter it wraps. The always-true filter
   * that style#setFilter sets to remove a filter also counts as none.
   */
  private static JsonElement getRawFilter(Layer layer) throws ReflectiveOperationException {
    Method nativeGetFilter = Layer.class.getDeclaredMethod("nativeGetFilter");
    nativeGetFilter.setAccessible(true);
    JsonElement filter = (JsonElement) nativeGetFilter.invoke(layer);
    boolean unfiltered =
        filter == null
            || filter.isJsonNull()
            || (filter.isJsonPrimitive()
                && filter.getAsJsonPrimitive().isBoolean()
                && filter.getAsBoolean());
    return unfiltered ? null : filter;
  }

  private boolean addRasterLayer(
      String layerName,
      String sourceName,
      Float minZoom,
      Float maxZoom,
      String belowLayerId,
      PropertyValue[] properties,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addRasterLayer: style not ready, skipping");
      return false;
    }
    RasterLayer layer = new RasterLayer(layerName, sourceName);
    layer.setProperties(properties);
    if (minZoom != null) {
      layer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      layer.setMaxZoom(maxZoom);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    return true;
  }

  private boolean addHillshadeLayer(
      String layerName,
      String sourceName,
      Float minZoom,
      Float maxZoom,
      String belowLayerId,
      PropertyValue[] properties,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addHillshadeLayer: style not ready, skipping");
      return false;
    }
    HillshadeLayer layer = new HillshadeLayer(layerName, sourceName);
    layer.setProperties(properties);
    if (minZoom != null) {
      layer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      layer.setMaxZoom(maxZoom);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    return true;
  }

  private boolean addColorReliefLayer(
      String layerName,
      String sourceName,
      Float minZoom,
      Float maxZoom,
      String belowLayerId,
      PropertyValue[] properties,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addColorReliefLayer: style not ready, skipping");
      return false;
    }
    ColorReliefLayer layer = new ColorReliefLayer(layerName, sourceName);
    layer.setProperties(properties);
    if (minZoom != null) {
      layer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      layer.setMaxZoom(maxZoom);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    return true;
  }

  private boolean addBackgroundLayer(
      String layerName,
      Float minZoom,
      Float maxZoom,
      String belowLayerId,
      PropertyValue[] properties) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addBackgroundLayer: style not ready, skipping");
      return false;
    }
    BackgroundLayer layer = new BackgroundLayer(layerName);
    layer.setProperties(properties);
    if (minZoom != null) {
      layer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      layer.setMaxZoom(maxZoom);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    return true;
  }



  private boolean addHeatmapLayer(
      String layerName,
      String sourceName,
      String sourceLayer,
      Float minZoom,
      Float maxZoom,
      String belowLayerId,
      PropertyValue[] properties,
      Expression filter) {
    if (style == null || !style.isFullyLoaded()) {
      Log.w(TAG, "addHeatmapLayer: style not ready, skipping");
      return false;
    }
    HeatmapLayer layer = new HeatmapLayer(layerName, sourceName);
    layer.setProperties(properties);
    if (sourceLayer != null) {
      layer.setSourceLayer(sourceLayer);
    }
    if (minZoom != null) {
      layer.setMinZoom(minZoom);
    }
    if (maxZoom != null) {
      layer.setMaxZoom(maxZoom);
    }
    if (filter != null) {
      layer.setFilter(filter);
    }
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    return true;
  }

  /**
   * Half the side, in dp, of the square around a touch where taps and drags look for a feature.
   * iOS uses the same value in points.
   */
  private static final float FEATURE_HIT_TOLERANCE_DP = 8f;

  /**
   * Returns the interactive feature nearest to {@code point}, looking up to {@link
   * #FEATURE_HIT_TOLERANCE_DP} around it. Nearness is measured to what the feature draws: the
   * square around the point grows one dp at a time and the first feature it touches wins. When
   * several features are reached at the same distance, the top-most layer wins. With {@code
   * draggableOnly}, features that cannot be dragged are left out, so they never hide one that can.
   * A touch inside a polygon hole reaches the polygon only at its ring edges, see {@link
   * PolygonHitTest}.
   */
  private Pair<Feature, String> firstFeatureOnLayers(PointF point, boolean draggableOnly) {
    if (style == null) return null;
    if (!style.isFullyLoaded()) {
        Log.d(TAG, "firstFeatureOnLayers: style not fully loaded yet");
        return null;
    }
    
    final List<Layer> layers;
    try {
      layers = style.getLayers();
    } catch (IllegalStateException ex) {
      // Style object is stale (a new style is loading/has loaded). Skip querying.
      Log.w(TAG, "firstFeatureOnLayers: Style.getLayers() failed: " + ex.getMessage());
      return null;
    }
    final List<String> layersInOrder = new ArrayList<String>();
    for (Layer layer : layers) {
      String id = layer.getId();
      if (interactiveFeatureLayerIds.contains(id)) layersInOrder.add(id);
    }
    Collections.reverse(layersInOrder);

    final LatLng touch = mapLibreMap.getProjection().fromScreenLocation(point);
    final PolygonHitTest holes =
        new PolygonHitTest(
            touch.getLongitude(), touch.getLatitude(), mapLibreMap.getCameraPosition().zoom);

    // One query over the whole area keeps only the layers with something in reach.
    final List<String> candidateLayers = new ArrayList<String>();
    Pair<Feature, String> onlyHit = null;
    int hits = 0;
    for (String id : layersInOrder) {
      List<Feature> features =
          featuresIn(point, FEATURE_HIT_TOLERANCE_DP, id, draggableOnly, holes);
      if (!features.isEmpty()) {
        candidateLayers.add(id);
        hits += features.size();
        onlyHit = new Pair<Feature, String>(features.get(0), id);
      }
    }
    if (hits <= 1) {
      return onlyHit;
    }

    for (int radiusDp = 1; radiusDp <= FEATURE_HIT_TOLERANCE_DP; radiusDp++) {
      for (String id : candidateLayers) {
        List<Feature> features = featuresIn(point, radiusDp, id, draggableOnly, holes);
        if (!features.isEmpty()) {
          return new Pair<Feature, String>(features.get(0), id);
        }
      }
    }
    return null;
  }

  private List<Feature> featuresIn(
      PointF point,
      float radiusDp,
      String layerId,
      boolean draggableOnly,
      PolygonHitTest holes) {
    List<Feature> features = mapLibreMap.queryRenderedFeatures(hitRect(point, radiusDp), layerId);
    List<Feature> hits = new ArrayList<Feature>();
    for (Feature feature : features) {
      if (draggableOnly && !isDraggable(feature)) continue;
      if (holes.keeps(feature, radiusDp)) hits.add(feature);
    }
    return hits;
  }

  private RectF hitRect(PointF point, float radiusDp) {
    float radius = radiusDp * density;
    return new RectF(point.x - radius, point.y - radius, point.x + radius, point.y + radius);
  }

  /**
   * Answers LAYER_ALREADY_EXISTS when the style already holds a layer with the id a call adds. The
   * SDK would throw a generic error instead.
   *
   * @return true when the call has been answered with an error.
   */
  @Override
  public boolean rejectDuplicateLayerId(String layerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded() || style.getLayer(layerId) == null) {
      return false;
    }
    result.error(
        "LAYER_ALREADY_EXISTS",
        "Layer already exists",
        "Layer with id " + layerId + " already exists.");
    return true;
  }

  /**
   * Answers SOURCE_ALREADY_EXISTS when the style already holds a source with the id a call adds.
   * The SDK would throw a generic error or silently skip the add instead.
   *
   * @return true when the call has been answered with an error.
   */
  @Override
  public boolean rejectDuplicateSourceId(String sourceId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded() || style.getSource(sourceId) == null) {
      return false;
    }
    result.error(
        "SOURCE_ALREADY_EXISTS",
        "Source already exists",
        "Source with id " + sourceId + " already exists.");
    return true;
  }

  /**
   * The camera update of a {@link #cameraMove}, {@link #cameraAnimate} or {@link #cameraEase}
   * call, or null after answering INVALID_ARGUMENT when the SDK cannot build it, such as for a
   * latitude beyond the poles.
   */
  @Nullable
  private CameraUpdate toCameraUpdate(PgCameraUpdate update, MethodChannel.Result result) {
    final String nonFinite = PigeonConvert.nonFiniteReason(update);
    if (nonFinite != null) {
      result.error(StyleChecks.INVALID_ARGUMENT, nonFinite, null);
      return null;
    }
    try {
      return PigeonConvert.toCameraUpdate(update, mapLibreMap, density);
    } catch (RuntimeException e) {
      result.error(
          StyleChecks.INVALID_ARGUMENT, "Cannot interpret " + update + " as CameraUpdate.", null);
      return null;
    }
  }

  /**
   * Answers INVALID_ARGUMENT for a coordinate that is NaN or infinite, which MapLibre cannot place.
   *
   * @return true when the call has been answered with an error.
   */
  private static boolean rejectNonFinite(boolean finite, MethodChannel.Result result) {
    if (!finite) {
      result.error(StyleChecks.INVALID_ARGUMENT, StyleChecks.NON_FINITE_COORDINATES, null);
    }
    return !finite;
  }

  private static void replyLayerNotFound(MethodChannel.Result result, String layerId) {
    result.error("LAYER_NOT_FOUND_ERROR", "Layer not found", "Layer with id " + layerId + " not found.");
  }

  private static void replyStyleNotReady(MethodChannel.Result result) {
    result.error(StyleChecks.STYLE_NOT_READY, StyleChecks.STYLE_NOT_READY_MESSAGE, null);
  }

  private static void replySourceNotFound(MethodChannel.Result result, String sourceId) {
    result.error(
        "SOURCE_NOT_FOUND", "Source '" + sourceId + "' does not exist in the current style.", null);
  }

  /**
   * Answers, in this order, STYLE_NOT_READY without a style, SOURCE_NOT_FOUND without the source
   * {@code sourceId}, UNSUPPORTED_SOURCE_TYPE when a layer of {@code layerType} cannot draw that
   * source, and SOURCE_LAYER_REQUIRED for a vector source without {@code sourceLayer}. The engine
   * would add the layer and draw nothing.
   *
   * @return true when the call has been answered with an error.
   */
  private boolean rejectLayerAdd(
      String layerId,
      String layerType,
      String sourceId,
      @Nullable String sourceLayer,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return true;
    }
    final Source source = style.getSource(sourceId);
    if (source == null) {
      replySourceNotFound(result, sourceId);
      return true;
    }
    final String sourceType = StyleChecks.sourceType(source);
    if (sourceType != null && !StyleChecks.canDraw(layerType, sourceType)) {
      result.error(
          StyleChecks.UNSUPPORTED_SOURCE_TYPE,
          StyleChecks.incompatibleSource(layerId, layerType, sourceId, sourceType),
          null);
      return true;
    }
    if (source instanceof VectorSource && (sourceLayer == null || sourceLayer.isEmpty())) {
      result.error(
          StyleChecks.SOURCE_LAYER_REQUIRED,
          StyleChecks.sourceLayerRequired(layerId, sourceId),
          null);
      return true;
    }
    return false;
  }

  /**
   * {@code properties} converted for a layer of {@code layerType}, or null after answering
   * INVALID_EXPRESSION or INVALID_ARGUMENT, and logging a warning, when the engine rejects one of
   * them. They are tried in name order on a layer outside the style, so a failed call changes
   * nothing.
   */
  @Nullable
  private PropertyValue[] checkedLayerProperties(
      String layerId,
      String layerType,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    final PropertyValue[] values;
    try {
      values = interpretLayerProperties(layerType, properties);
    } catch (RuntimeException e) {
      rejectUnconvertibleProperty(layerId, layerType, properties, result, e);
      return null;
    }
    final Layer check = propertyCheckLayer(layerType);
    if (check == null) {
      return values;
    }
    final PropertyValue<?>[] byName = values.clone();
    Arrays.sort(byName, (a, b) -> a.name.compareTo(b.name));
    try (EngineErrors errors = new EngineErrors(PROPERTY_ERROR_PREFIX)) {
      for (PropertyValue<?> value : byName) {
        if (value.value == null) {
          // Null resets the property, which the engine always takes.
          continue;
        }
        final Object raw = properties.get(value.name);
        String reason = StyleChecks.hexColorError(value.name, raw);
        if (reason == null) {
          check.setProperties(value);
          final String logged = errors.take();
          reason = logged == null ? null : StyleChecks.propertyReason(logged, value.name);
        }
        if (reason != null) {
          replyInvalidProperty(layerId, value.name, raw, reason, result);
          return null;
        }
      }
    }
    return values;
  }

  /**
   * Answers for the first of {@code properties}, in name order, that the SDK cannot build an
   * expression from, such as an empty array. Throws {@code failure} again when none fails alone.
   */
  private static void rejectUnconvertibleProperty(
      String layerId,
      String layerType,
      Map<String, Object> properties,
      MethodChannel.Result result,
      RuntimeException failure) {
    final List<String> names = new ArrayList<>(properties.keySet());
    Collections.sort(names);
    for (String name : names) {
      final Object value = properties.get(name);
      try {
        interpretLayerProperties(layerType, Collections.singletonMap(name, value));
      } catch (RuntimeException e) {
        replyInvalidProperty(
            layerId, name, value, e.getMessage() != null ? e.getMessage() : e.toString(), result);
        return;
      }
    }
    throw failure;
  }

  private static void replyInvalidProperty(
      String layerId,
      String name,
      @Nullable Object value,
      String reason,
      MethodChannel.Result result) {
    final String message = StyleChecks.invalidProperty(layerId, name, value, reason);
    Log.w(TAG, message);
    result.error(StyleChecks.invalidPropertyCode(value), message, reason);
  }

  private static final String PROPERTY_CHECK_ID = "maplibre-gl-property-check";

  /** A layer of {@code layerType} that is never added to a style, or null for an unknown type. */
  @Nullable
  private Layer propertyCheckLayer(String layerType) {
    Layer layer = propertyCheckLayers.get(layerType);
    if (layer != null) {
      return layer;
    }
    switch (layerType) {
      case "symbol":
        layer = new SymbolLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "line":
        layer = new LineLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "fill":
        layer = new FillLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "fill-extrusion":
        layer = new FillExtrusionLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "circle":
        layer = new CircleLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "heatmap":
        layer = new HeatmapLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "raster":
        layer = new RasterLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "hillshade":
        layer = new HillshadeLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "color-relief":
        layer = new ColorReliefLayer(PROPERTY_CHECK_ID, PROPERTY_CHECK_ID);
        break;
      case "background":
        layer = new BackgroundLayer(PROPERTY_CHECK_ID);
        break;
      default:
        return null;
    }
    propertyCheckLayers.put(layerType, layer);
    return layer;
  }

  /** Converts {@code properties} into property values for a layer of {@code layerType}. */
  private static PropertyValue[] interpretLayerProperties(
      String layerType, Map<String, Object> properties) {
    switch (layerType) {
      case "symbol":
        return LayerPropertyConverter.interpretSymbolLayerProperties(properties);
      case "line":
        return LayerPropertyConverter.interpretLineLayerProperties(properties);
      case "fill":
        return LayerPropertyConverter.interpretFillLayerProperties(properties);
      case "fill-extrusion":
        return LayerPropertyConverter.interpretFillExtrusionLayerProperties(properties);
      case "circle":
        return LayerPropertyConverter.interpretCircleLayerProperties(properties);
      case "heatmap":
        return LayerPropertyConverter.interpretHeatmapLayerProperties(properties);
      case "raster":
        return LayerPropertyConverter.interpretRasterLayerProperties(properties);
      case "hillshade":
        return LayerPropertyConverter.interpretHillshadeLayerProperties(properties);
      case "color-relief":
        return LayerPropertyConverter.interpretColorReliefLayerProperties(properties);
      case "background":
        return LayerPropertyConverter.interpretBackgroundLayerProperties(properties);
      default:
        return new PropertyValue[] {};
    }
  }

  /**
   * Answers INVALID_EXPRESSION for the filter of a layer add that is not JSON, not a filter, or one
   * the engine rejects, which the engine would otherwise drop silently.
   *
   * @return true when the call has been answered with an error.
   */
  private boolean rejectInvalidLayerFilter(@Nullable String filter, MethodChannel.Result result) {
    final Expression expression;
    try {
      expression = parseFilter(filter);
    } catch (IllegalArgumentException e) {
      replyInvalidFilter(result, e.getMessage());
      return true;
    }
    final String error = expression == null ? null : queryFilterError(expression);
    if (error != null) {
      replyInvalidFilter(result, error);
      return true;
    }
    return false;
  }

  @Override
  public boolean isMapReady() {
    return mapLibreMap != null;
  }

  // -- Map --------------------------------------------------------------------

  @Override
  public void mapWaitForMap(MethodChannel.Result result) {
    if (mapLibreMap != null) {
      result.success(null);
      return;
    }
    mapReadyResult = result;
  }

  @Override
  public void mapUpdate(PgMapOptions options, MethodChannel.Result result) {
    PigeonConvert.applyMapOptions(options, this, density);
    result.success(Convert.toPgCameraPosition(getCameraPosition()));
  }

  // Dart-driven pause/resume. Only flips MapView state when it's actually out
  // of sync with the request, so we never double-call onPause/onResume against
  // the natural Activity lifecycle (which the lifecycle observer handles).
  @Override
  public void mapPause(MethodChannel.Result result) {
    userPaused = true;
    if (!disposed && mapView != null && mapViewResumed) {
      mapView.onPause();
      mapViewResumed = false;
      stopListeningForLocationUpdates();
    }
    stopLocationComponentWhileUserPaused();
    result.success(null);
  }

  @Override
  public void mapResume(MethodChannel.Result result) {
    userPaused = false;
    if (!disposed
        && mapView != null
        && !mapViewResumed
        && boundLifecycle != null
        && boundLifecycle.getCurrentState().isAtLeast(Lifecycle.State.RESUMED)) {
      mapView.onResume();
      mapViewResumed = true;
      if (locationComponent != null && mapViewStarted) {
        locationComponent.onStart();
      }
      if (myLocationEnabled) {
        startListeningForLocationUpdates();
      }
    }
    result.success(null);
  }

  @Override
  public void mapMatchMapLanguageWithDeviceDefault(MethodChannel.Result result) {
    try {
      final Locale deviceLocale = Locale.getDefault();
      MapLibreMapUtils.setMapLanguage(mapLibreMap, deviceLocale.getLanguage());

      result.success(null);
    } catch (RuntimeException exception) {
      Log.d(TAG, exception.toString());
      result.error("LOCALIZATION_ERROR", exception.toString(), null);
    }
  }

  @Override
  public void mapSetMapLanguage(String language, MethodChannel.Result result) {
    try {
      MapLibreMapUtils.setMapLanguage(mapLibreMap, language);

      result.success(null);
    } catch (RuntimeException exception) {
      Log.d(TAG, exception.toString());
      result.error("LOCALIZATION_ERROR", exception.toString(), null);
    }
  }

  @Override
  public void mapSetTelemetryEnabled(boolean enabled, MethodChannel.Result result) {
    result.success(null);
  }

  @Override
  public void mapGetTelemetryEnabled(MethodChannel.Result result) {
    result.success(false);
  }

  @Override
  public void mapSetMaximumFps(long fps, MethodChannel.Result result) {
    final int maximumFps = Convert.toIntExact(fps);
    if (mapView != null) {
      mapView.setMaximumFps(maximumFps);
    }
    result.success(null);
  }

  @Override
  public void mapForceOnlineMode(MethodChannel.Result result) {
    // Force online mode by setting connectivity to true
    if (mapView != null) {
      ConnectivityReceiver.instance(mapView.getContext()).setConnected(true);
    }
    result.success(null);
  }

  @Override
  public void mapSetCustomHeaders(
      Map<String, String> headers, List<String> filter, MethodChannel.Result result) {
    MapLibreHttpRequestUtil.setCustomHeaders(headers, filter, result);
  }

  @Override
  public void mapGetCustomHeaders(MethodChannel.Result result) {
    result.success(MapLibreHttpRequestUtil.getCustomHeaders());
  }

  @Override
  public void mapInvalidateAmbientCache(MethodChannel.Result result) {
    OfflineManager fileSource = OfflineManager.Companion.getInstance(context);

    fileSource.invalidateAmbientCache(
        new OfflineManager.FileSourceCallback() {
          @Override
          public void onSuccess() {
            result.success(null);
          }

          @Override
          public void onError(@NonNull String message) {
            result.error("AMBIENT_CACHE_ERROR", message, null);
          }
        });
  }

  @Override
  public void mapClearAmbientCache(MethodChannel.Result result) {
    OfflineManager fileSource = OfflineManager.Companion.getInstance(context);

    fileSource.clearAmbientCache(
        new OfflineManager.FileSourceCallback() {
          @Override
          public void onSuccess() {
            result.success(null);
          }

          @Override
          public void onError(@NonNull String message) {
            result.error("AMBIENT_CACHE_ERROR", message, null);
          }
        });
  }

  @Override
  public void mapTakeSnapshot(
      @Nullable Long width, @Nullable Long height, MethodChannel.Result result) {
    Style currentStyle = mapLibreMap.getStyle();
    if (currentStyle == null) {
      result.error("STYLE_NOT_READY", "Map style is not loaded", null);
      return;
    }
    // A style set as JSON has no URI, and a snapshotter given an empty one
    // never calls back, so hand it the JSON instead.
    String styleUrl = currentStyle.getUri();
    Style.Builder snapshotStyle =
        styleUrl == null || styleUrl.isEmpty()
            ? new Style.Builder().fromJson(currentStyle.getJson())
            : new Style.Builder().fromUri(styleUrl);
    // The snapshotter takes a size in logical pixels, like iOS and web, and renders it at the
    // screen's density, so the default shows what the map shows.
    int snapshotWidth =
        width != null ? Convert.toIntExact(width) : Math.round(mapView.getWidth() / density);
    int snapshotHeight =
        height != null ? Convert.toIntExact(height) : Math.round(mapView.getHeight() / density);

    MapSnapshotter.Options options = new MapSnapshotter.Options(snapshotWidth, snapshotHeight)
            .withPixelRatio(density)
            .withStyleBuilder(snapshotStyle)
            .withCameraPosition(mapLibreMap.getCameraPosition());
    cancelSnapshot(SNAPSHOT_ERROR, SNAPSHOT_SUPERSEDED);
    final MapSnapshotter snapshotter = new MapSnapshotter(context, options);
    activeSnapshotter = snapshotter;
    activeSnapshotResult = result;
    snapshotter.start(
        snapshot -> {
          if (finishSnapshot(snapshotter)) {
            Bitmap bitmap = snapshot.getBitmap();
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream);
            result.success(stream.toByteArray());
          }
        },
        error -> {
          if (finishSnapshot(snapshotter)) {
            result.error(SNAPSHOT_ERROR, error, null);
          }
        });
  }

  private static final String SNAPSHOT_ERROR = "SNAPSHOT_ERROR";
  private static final String SNAPSHOT_SUPERSEDED = "A newer takeSnapshot call cancelled this one.";

  /**
   * Forgets {@code snapshotter} once it has finished. False when it no longer runs for a call,
   * which cancelSnapshot has answered.
   */
  private boolean finishSnapshot(MapSnapshotter snapshotter) {
    if (activeSnapshotter != snapshotter) {
      return false;
    }
    activeSnapshotter = null;
    activeSnapshotResult = null;
    return true;
  }

  /** Stops the running snapshot, if any, and fails its call with {@code code}. */
  private void cancelSnapshot(String code, String message) {
    if (activeSnapshotter == null) {
      return;
    }
    final MethodChannel.Result waiting = activeSnapshotResult;
    activeSnapshotter.cancel();
    activeSnapshotter = null;
    activeSnapshotResult = null;
    waiting.error(code, message, null);
  }

  // -- Camera -----------------------------------------------------------------

  @Override
  public void cameraMove(PgCameraUpdate cameraUpdate, MethodChannel.Result result) {
    final CameraUpdate update = toCameraUpdate(cameraUpdate, result);
    if (update == null) {
      return;
    }
    mapLibreMap.moveCamera(update, answerWhenDone(result));
  }

  @Override
  public void cameraAnimate(
      PgCameraUpdate cameraUpdate, @Nullable Long duration, MethodChannel.Result result) {
    final CameraUpdate update = toCameraUpdate(cameraUpdate, result);
    if (update == null) {
      return;
    }
    final Integer durationMs = duration == null ? null : Convert.toIntExact(duration);
    if (durationMs != null && durationMs == 0) {
      // The SDK rejects a zero duration, where iOS and web jump to the camera at once. So does
      // this, with the camera events of a moveCamera.
      mapLibreMap.moveCamera(update, answerWhenDone(result));
    } else if (durationMs != null) {
      mapLibreMap.animateCamera(update, durationMs, answerWhenDone(result));
    } else {
      mapLibreMap.animateCamera(update, answerWhenDone(result));
    }
  }

  @Override
  public void cameraEase(
      PgCameraUpdate cameraUpdate,
      @Nullable Long duration,
      @Nullable PgCameraAnimationInterpolation interpolation,
      MethodChannel.Result result) {
    final CameraUpdate update = toCameraUpdate(cameraUpdate, result);
    if (update == null) {
      return;
    }
    final Integer durationMs = duration == null ? null : Convert.toIntExact(duration);

    // MapLibre Android's easeCamera only exposes a boolean:
    //   false = linear (constant velocity)
    //   true  = default ease-in/ease-out
    // Custom timing curves (easeOut, fastOutLinearIn) are not supported
    // natively, so any value but linear falls back to eased, and so does none.
    // This cross-platform caveat is documented on CameraAnimationInterpolation.
    final boolean easingInterpolator = interpolation != PgCameraAnimationInterpolation.LINEAR;

    if (durationMs != null && durationMs > 0) {
      mapLibreMap.easeCamera(update, durationMs, easingInterpolator, answerWhenDone(result));
    } else {
      mapLibreMap.easeCamera(update, answerWhenDone(result));
    }
  }

  /** Answers {@code result} true once the camera arrives and false when the move is cut short. */
  private static MapLibreMap.CancelableCallback answerWhenDone(MethodChannel.Result result) {
    return new MapLibreMap.CancelableCallback() {
      @Override
      public void onFinish() {
        result.success(true);
      }

      @Override
      public void onCancel() {
        result.success(false);
      }
    };
  }

  @Override
  public void mapQueryCameraPosition(MethodChannel.Result result) {
    result.success(Convert.toPgCameraPosition(mapLibreMap.getCameraPosition()));
  }

  @Override
  public void mapUpdateContentInsets(
      PgEdgeInsets insets, boolean animated, MethodChannel.Result result) {
    final CameraUpdate cameraUpdate =
        CameraUpdateFactory.paddingTo(
            Convert.toPixels(insets.getLeft(), density),
            Convert.toPixels(insets.getTop(), density),
            Convert.toPixels(insets.getRight(), density),
            Convert.toPixels(insets.getBottom(), density));

    if (animated) {
      mapLibreMap.animateCamera(cameraUpdate, answerWhenDone(result));
    } else {
      mapLibreMap.moveCamera(cameraUpdate, answerWhenDone(result));
    }
  }

  @Override
  public void mapSetCameraBounds(
      double west,
      double north,
      double south,
      double east,
      long padding,
      MethodChannel.Result result) {
    if (rejectNonFinite(
        StyleChecks.isFinite(north, east) && StyleChecks.isFinite(south, west), result)) {
      return;
    }
    if (Math.abs(north) > 90 || Math.abs(south) > 90) {
      result.error(StyleChecks.INVALID_ARGUMENT, StyleChecks.LATITUDE_OUT_OF_RANGE, null);
      return;
    }
    if (padding < Integer.MIN_VALUE || padding > Integer.MAX_VALUE) {
      result.error(StyleChecks.INVALID_ARGUMENT, StyleChecks.paddingOutOfRange(padding), null);
      return;
    }
    final int logicalPadding = (int) padding;

    LatLng locationOne = new LatLng(north, east);
    LatLng locationTwo = new LatLng(south, west);
    LatLngBounds latLngBounds = new LatLngBounds.Builder()
            .include(locationOne) // Northeast
            .include(locationTwo) // Southwest
            .build();
    // Padding is in logical pixels, like every other camera input.
    mapLibreMap.easeCamera(CameraUpdateFactory.newLatLngBounds(latLngBounds,
            (int) (logicalPadding * density)), 200);
    // Replies once the move is started, as iOS and web do.
    result.success(null);
  }

  // -- Location ---------------------------------------------------------------

  @Override
  public void mapUpdateMyLocationTrackingMode(
      PgMyLocationTrackingMode mode, MethodChannel.Result result) {
    setMyLocationTrackingMode(mode.getRaw());
    result.success(null);
  }

  @Override
  public void locationComponentGetLastLocation(MethodChannel.Result result) {
    Log.e(TAG, "location component: getLastLocation");
    if (this.myLocationEnabled
        && manualLocationSource
        && locationComponent != null
        && locationComponent.isLocationComponentActivated()) {
      // Manual mode has no location engine; read the last forced location.
      Location lastLocation = locationComponent.getLastKnownLocation();
      if (lastLocation != null) {
        result.success(new PgLatLng(lastLocation.getLatitude(), lastLocation.getLongitude()));
      } else {
        result.error("LOCATION_UNAVAILABLE",
            "Last location is not available", null);
      }
    } else if (this.myLocationEnabled
        && locationComponent != null
        && locationComponent.isLocationComponentActivated()
        && locationComponent.getLocationEngine() != null) {
      mapLibreMap.getLocationComponent().getLocationEngine().getLastLocation(
          new LocationEngineCallback<LocationEngineResult>() {
            @Override
            public void onSuccess(LocationEngineResult locationEngineResult) {
              Location lastLocation = locationEngineResult.getLastLocation();
              if (lastLocation != null) {
                result.success(
                    new PgLatLng(lastLocation.getLatitude(), lastLocation.getLongitude()));
              } else {
                result.error("LOCATION_UNAVAILABLE",
                    "Last location is not available", null);
              }
            }

            @Override
            public void onFailure(@NonNull Exception exception) {
              result.error("LOCATION_ENGINE_FAILURE",
                  "Failed to get last location: " + exception.getMessage(), null);
            }
          });
    } else {
      result.error("LOCATION_DISABLED",
          "Location is disabled or location component is unavailable", null);
    }
  }

  // Pitches the camera through the location component instead of the regular
  // camera API. MapLibreMap#animateCamera and friends notify the SDK's
  // developer-animation listeners, which the location component answers by
  // dropping to CameraMode.NONE, so a plain camera call would end tracking and
  // report a dismissal. LocationComponent#tiltWhileTracking feeds the same
  // animator that drives tracking, so the camera mode is left alone.
  @Override
  public void locationComponentSetTrackingCameraOptions(
      double tilt, @Nullable Long duration, MethodChannel.Result result) {
    if (locationComponent == null || !locationComponent.isLocationComponentActivated()) {
      result.error(
          "LOCATION_COMPONENT_NOT_READY",
          "The location component is not ready. Ensure the map was created with "
              + "myLocationEnabled: true.",
          null);
      return;
    }
    if (locationComponent.getCameraMode() == CameraMode.NONE) {
      result.error(
          "TRACKING_NOT_ACTIVE",
          "A tracking mode other than MyLocationTrackingMode.none must be active "
              + "before a tracking camera option can be applied.",
          null);
      return;
    }
    final MapLibreMap.CancelableCallback callback =
        new MapLibreMap.CancelableCallback() {
          @Override
          public void onCancel() {
            // Either superseded by a newer tracking-camera animation, or refused
            // because the camera mode was still transitioning. The tilt is not
            // guaranteed to have been applied, so report that rather than success.
            result.success(false);
          }

          @Override
          public void onFinish() {
            result.success(true);
          }
        };
    if (duration != null) {
      locationComponent.tiltWhileTracking(tilt, duration, callback);
    } else {
      // Three-argument overload only; the two-argument one takes no callback, and
      // the SDK's own default duration is not public.
      locationComponent.tiltWhileTracking(tilt, DEFAULT_TRACKING_TILT_DURATION_MS, callback);
    }
  }

  @Override
  public void locationComponentSetManualLocation(
      PgManualLocationUpdate update, MethodChannel.Result result) {
    if (!manualLocationSource) {
      result.error(
          "MANUAL_LOCATION_SOURCE_DISABLED",
          "Manual locations require locationSource: ManualLocationSource().",
          null);
      return;
    }
    // What is unknown stays unset on the Location.
    final Location location = new Location("ManualLocationSource");
    location.setLatitude(update.getPosition().getLatitude());
    location.setLongitude(update.getPosition().getLongitude());
    final Double altitude = update.getAltitude();
    if (altitude != null) {
      location.setAltitude(altitude);
    }
    final Double bearing = update.getBearing();
    if (bearing != null) {
      location.setBearing(bearing.floatValue());
    }
    final Double speed = update.getSpeed();
    if (speed != null) {
      location.setSpeed(speed.floatValue());
    }
    final Double horizontalAccuracy = update.getHorizontalAccuracy();
    if (horizontalAccuracy != null) {
      location.setAccuracy(horizontalAccuracy.floatValue());
    }
    final Double verticalAccuracy = update.getVerticalAccuracy();
    if (verticalAccuracy != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      location.setVerticalAccuracyMeters(verticalAccuracy.floatValue());
    }
    location.setTime(update.getTimestamp());
    // With the location off, or the component not built yet, the puck shows it once it is on.
    pendingManualLocation.offer(location, isPuckVisible(), this::showManualLocation);
    result.success(null);
  }

  private boolean isPuckVisible() {
    return myLocationEnabled
        && locationComponent != null
        && locationComponent.isLocationComponentActivated()
        && locationComponent.isLocationComponentEnabled();
  }

  private void showManualLocation(Location location) {
    locationComponent.forceLocationUpdate(location);
    // Keep map#onUserLocationUpdated firing, mirroring the engine path.
    onUserLocationUpdate(location);
  }

  // -- Queries ----------------------------------------------------------------

  @Override
  public void mapGetVisibleRegion(MethodChannel.Result result) {
    final LatLngBounds bounds = mapLibreMap.getProjection().getVisibleRegion().latLngBounds;
    result.success(
        new PgLatLngBounds(
            new PgLatLng(bounds.getLatSouth(), bounds.getLonWest()),
            new PgLatLng(bounds.getLatNorth(), bounds.getLonEast())));
  }

  // The SDK measures the map view in physical pixels and Dart in logical pixels, like iOS and
  // web. Every screen point that crosses between them goes through these two.

  /** The physical pixel of the logical point ({@code x}, {@code y}) of the map view. */
  private PointF toPixel(double x, double y) {
    return new PointF(
        Convert.toFractionalPixels(x, density), Convert.toFractionalPixels(y, density));
  }

  /** The logical point of the physical {@code pixel} of the map view. */
  private PgScreenPoint toScreenPoint(PointF pixel) {
    return new PgScreenPoint(
        Convert.toLogicalPixels(pixel.x, density), Convert.toLogicalPixels(pixel.y, density));
  }

  @Override
  public void mapToScreenLocation(double latitude, double longitude, MethodChannel.Result result) {
    if (rejectNonFinite(StyleChecks.isFinite(latitude, longitude), result)) {
      return;
    }
    PointF pointf =
        mapLibreMap.getProjection().toScreenLocation(new LatLng(latitude, longitude));
    result.success(toScreenPoint(pointf));
  }

  @Override
  public void mapToScreenLocationBatch(double[] coordinates, MethodChannel.Result result) {
    for (int i = 0; i + 1 < coordinates.length; i += 2) {
      if (rejectNonFinite(StyleChecks.isFinite(coordinates[i], coordinates[i + 1]), result)) {
        return;
      }
    }
    double[] reply = new double[coordinates.length];

    for (int i = 0; i < coordinates.length; i += 2) {
      PointF pointf =
          mapLibreMap
              .getProjection()
              .toScreenLocation(new LatLng(coordinates[i], coordinates[i + 1]));
      reply[i] = Convert.toLogicalPixels(pointf.x, density);
      reply[i + 1] = Convert.toLogicalPixels(pointf.y, density);
    }

    result.success(reply);
  }

  @Override
  public void mapToLatLng(double x, double y, MethodChannel.Result result) {
    if (!StyleChecks.isFinite(x, y)) {
      result.error(StyleChecks.INVALID_ARGUMENT, StyleChecks.NON_FINITE_SCREEN_POINT, null);
      return;
    }
    LatLng latlng = mapLibreMap.getProjection().fromScreenLocation(toPixel(x, y));
    result.success(new PgLatLng(latlng.getLatitude(), latlng.getLongitude()));
  }

  @Override
  public void mapGetMetersPerPixelAtLatitude(double latitude, MethodChannel.Result result) {
    result.success(mapLibreMap.getProjection().getMetersPerPixelAtLatitude(latitude));
  }

  @Override
  public void mapQueryRenderedFeaturesAtPoint(
      double x,
      double y,
      List<String> layerIds,
      @Nullable String filter,
      MethodChannel.Result result) {
    final String[] layers = layerIds.toArray(new String[0]);
    final PointF pixel = toPixel(x, y);
    answerFeatures(
        filter,
        result,
        expression -> mapLibreMap.queryRenderedFeatures(pixel, expression, layers));
  }

  @Override
  public void mapQueryRenderedFeaturesInRect(
      double left,
      double top,
      double right,
      double bottom,
      List<String> layerIds,
      @Nullable String filter,
      MethodChannel.Result result) {
    final String[] layers = layerIds.toArray(new String[0]);
    final RectF rectF =
        new RectF(
            Convert.toFractionalPixels(left, density),
            Convert.toFractionalPixels(top, density),
            Convert.toFractionalPixels(right, density),
            Convert.toFractionalPixels(bottom, density));
    answerFeatures(
        filter,
        result,
        expression -> mapLibreMap.queryRenderedFeatures(rectF, expression, layers));
  }

  @Override
  public void mapQuerySourceFeatures(
      String sourceId,
      @Nullable String sourceLayerId,
      @Nullable String filter,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }

    final Source source = style.getSource(sourceId);
    answerFeatures(
        filter,
        result,
        expression -> {
          if (source instanceof GeoJsonSource) {
            return ((GeoJsonSource) source).querySourceFeatures(expression);
          } else if (source instanceof CustomGeometrySource) {
            return ((CustomGeometrySource) source).querySourceFeatures(expression);
          } else if (source instanceof VectorSource && sourceLayerId != null) {
            return ((VectorSource) source)
                .querySourceFeatures(new String[] {sourceLayerId}, expression);
          }
          return Collections.emptyList();
        });
  }

  /** A feature query, run with the expression of its filter, or null without one. */
  private interface FeatureQuery {
    List<Feature> run(@Nullable Expression filter);
  }

  /**
   * Answers the features {@code query} finds with {@code filter}, the JSON text of an expression
   * (see {@link PigeonConvert#toQueryFilter}). Answers INVALID_EXPRESSION, without running the
   * query, for a filter that is not JSON, not an expression, or one the engine rejects: the engine
   * would only log the problem and query anyway, which can crash the app.
   */
  private void answerFeatures(
      @Nullable String filter, MethodChannel.Result result, FeatureQuery query) {
    final Expression expression;
    try {
      expression = PigeonConvert.toQueryFilter(filter);
    } catch (IllegalArgumentException e) {
      replyInvalidFilter(result, e.getMessage());
      return;
    }
    if (expression != null) {
      final String error = queryFilterError(expression);
      if (error != null) {
        replyInvalidFilter(result, error);
        return;
      }
    }
    result.success(featuresReply(query.run(expression)));
  }

  /**
   * Why the engine rejects {@code filter} for a query, or null when it accepts it. Queries and
   * layers read filters the same way, so the check runs on a layer that is never added to a style.
   */
  @Nullable
  private String queryFilterError(Expression filter) {
    if (queryFilterCheck == null) {
      queryFilterCheck = new CircleLayer(QUERY_FILTER_CHECK_ID, QUERY_FILTER_CHECK_ID);
    }
    final CircleLayer layer = queryFilterCheck;
    return captureFilterError(() -> layer.setFilter(filter));
  }

  private static final String QUERY_FILTER_CHECK_ID = "maplibre-gl-query-filter-check";

  private static void replyInvalidFilter(MethodChannel.Result result, String reason) {
    result.error(StyleChecks.INVALID_EXPRESSION, "Invalid filter: " + reason, reason);
  }

  // -- Sources ----------------------------------------------------------------

  @Override
  public void mapEditGeoJsonSource(String id, String data, MethodChannel.Result result) {
    boolean ret = false;
    final Style style = mapLibreMap.getStyle();
    if (style != null) {
      try {
        GeoJsonSource source = style.getSourceAs(id);
        if (source != null) {
          source.setGeoJson(data);
          // Kept for setGeoJsonFeature.
          addedFeaturesByLayer.put(id, data);
          ret = true;
        }
      } catch (Exception e) {
        Log.e(TAG, "editGeoJsonSource: error updating source '" + id + "'", e);
      }
    }
    result.success(ret);
  }

  @Override
  public void mapEditGeoJsonUrl(String id, String url, MethodChannel.Result result) {
    boolean ret = false;
    final Style style = mapLibreMap.getStyle();
    if (style != null) {
      try {
        GeoJsonSource source = style.getSourceAs(id);
        if (source != null) {
          source.setUrl(url);
          // setGeoJsonFeature cannot change data it does not hold.
          addedFeaturesByLayer.remove(id);
          ret = true;
        }
      } catch (Exception e) {
        Log.e(TAG, "editGeoJsonUrl: error updating source '" + id + "'", e);
      }
    }
    result.success(ret);
  }

  @Override
  public void sourceAddGeoJson(String sourceId, String geojson, MethodChannel.Result result) {
    addGeoJsonSource(sourceId, geojson, result);
  }

  @Override
  public void sourceSetGeoJson(String sourceId, String geojson, MethodChannel.Result result) {
    setGeoJsonSource(sourceId, geojson, result);
  }

  @Override
  public void sourceSetFeature(
      String sourceId, String geojsonFeature, MethodChannel.Result result) {
    setGeoJsonFeature(sourceId, geojsonFeature, result);
  }

  @Override
  public void sourceSetFeatureState(
      String sourceId,
      String featureId,
      Map<String, Object> state,
      @Nullable String sourceLayer,
      MethodChannel.Result result) {
    final Source source = getFeatureStateCapableSource(sourceId, sourceLayer, result);
    if (source == null) {
      return;
    }
    // Nulls are kept: a null value overwrites the key, as on iOS and web,
    // where the default Gson would drop it and leave the old value in place.
    // A NaN or an infinity has no JSON form, and Gson refuses it.
    final JsonObject stateJson;
    try {
      stateJson = new GsonBuilder().serializeNulls().create().toJsonTree(state).getAsJsonObject();
    } catch (IllegalArgumentException | JsonParseException e) {
      result.error(
          StyleChecks.INVALID_ARGUMENT,
          "The state for feature '"
              + featureId
              + "' on source '"
              + sourceId
              + "' is not valid JSON: it holds a non-finite number, or a value of a type JSON cannot carry.",
          null);
      return;
    }
    final boolean applied =
        source instanceof VectorSource
            ? ((VectorSource) source).setFeatureState(sourceLayer, featureId, stateJson)
            : ((GeoJsonSource) source).setFeatureState(featureId, stateJson);
    if (applied) {
      result.success(null);
    } else {
      // The SDK setters return false instead of throwing; surfacing that
      // as an error keeps a rejected call from looking like a success.
      result.error(
          "FEATURE_STATE_NOT_APPLIED",
          "setFeatureState for feature '"
              + featureId
              + "' on source '"
              + sourceId
              + "' was rejected by the SDK. This usually means the source is no longer attached to the map.",
          null);
    }
  }

  @Override
  public void sourceRemoveFeatureState(
      String sourceId,
      @Nullable String featureId,
      @Nullable String stateKey,
      @Nullable String sourceLayer,
      MethodChannel.Result result) {
    // A stateKey lives inside one feature's state, so without a featureId
    // there is nothing the SDK could remove it from.
    if (featureId == null && stateKey != null) {
      result.error(
          StyleChecks.INVALID_ARGUMENT,
          "removeFeatureState with a 'stateKey' also requires the 'featureId' that owns the key.",
          null);
      return;
    }
    final Source source = getFeatureStateCapableSource(sourceId, sourceLayer, result);
    if (source == null) {
      return;
    }
    // Which arguments are present picks the operation, matching web:
    // both drop one key, featureId alone drops that feature's whole
    // state, neither resets the whole source (or source layer).
    final boolean applied;
    if (source instanceof VectorSource) {
      final VectorSource vectorSource = (VectorSource) source;
      if (featureId == null) {
        applied = vectorSource.resetFeatureStates(sourceLayer);
      } else if (stateKey == null) {
        applied = vectorSource.removeFeatureState(sourceLayer, featureId);
      } else {
        applied = vectorSource.removeFeatureState(sourceLayer, featureId, stateKey);
      }
    } else {
      final GeoJsonSource geoJsonSource = (GeoJsonSource) source;
      if (featureId == null) {
        applied = geoJsonSource.resetFeatureStates();
      } else if (stateKey == null) {
        applied = geoJsonSource.removeFeatureState(featureId);
      } else {
        applied = geoJsonSource.removeFeatureState(featureId, stateKey);
      }
    }
    if (applied) {
      result.success(null);
    } else {
      result.error(
          "FEATURE_STATE_NOT_APPLIED",
          "removeFeatureState on source '"
              + sourceId
              + "' was rejected by the SDK. This usually means the source is no longer attached to the map.",
          null);
    }
  }

  @Override
  public void sourceGetFeatureState(
      String sourceId,
      String featureId,
      @Nullable String sourceLayer,
      MethodChannel.Result result) {
    final Source source = getFeatureStateCapableSource(sourceId, sourceLayer, result);
    if (source == null) {
      return;
    }
    final JsonObject stateJson =
        source instanceof VectorSource
            ? ((VectorSource) source).getFeatureState(sourceLayer, featureId)
            : ((GeoJsonSource) source).getFeatureState(featureId);
    // Serialized as a JSON string so nested values survive the channel
    // intact, like styleGetLayerProperties. A null state must stay null
    // rather than become an empty map: the Dart return type is nullable
    // and callers distinguish "no state" from an empty state.
    result.success(stateJson == null ? null : stateJson.toString());
  }

  @Override
  public void sourceGetClusterExpansionZoom(
      String sourceId, long clusterId, MethodChannel.Result result) {
    final GeoJsonSource source =
        getClusterCapableSource(sourceId, "getClusterExpansionZoom", result);
    if (source == null) {
      return;
    }
    if (!hasCluster(source, clusterId)) {
      clusterNotFound(result, sourceId, clusterId);
      return;
    }
    result.success(source.getClusterExpansionZoom(clusterFeature(clusterId)));
  }

  @Override
  public void sourceGetClusterChildren(
      String sourceId, long clusterId, MethodChannel.Result result) {
    final GeoJsonSource source =
        getClusterCapableSource(sourceId, "getClusterChildren", result);
    if (source == null) {
      return;
    }
    if (!hasCluster(source, clusterId)) {
      clusterNotFound(result, sourceId, clusterId);
      return;
    }
    result.success(featuresReply(source.getClusterChildren(clusterFeature(clusterId))));
  }

  @Override
  public void sourceGetClusterLeaves(
      String sourceId, long clusterId, long limit, long offset, MethodChannel.Result result) {
    final GeoJsonSource source =
        getClusterCapableSource(sourceId, "getClusterLeaves", result);
    if (source == null) {
      return;
    }
    if (!hasCluster(source, clusterId)) {
      clusterNotFound(result, sourceId, clusterId);
      return;
    }
    result.success(
        featuresReply(source.getClusterLeaves(clusterFeature(clusterId), limit, offset)));
  }

  @Override
  public void styleAddSource(
      String sourceId, Map<String, Object> properties, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    final Object type = properties.get("type");
    if (!(type instanceof String)) {
      result.error(
          StyleChecks.UNSUPPORTED_SOURCE_TYPE, "Source '" + sourceId + "' has no type.", null);
      return;
    }
    if ("video".equals(type)) {
      // MapLibre Native has no video source.
      result.error(StyleChecks.UNSUPPORTED_SOURCE_TYPE, StyleChecks.videoSource(sourceId), null);
      return;
    }
    if (!SourcePropertyConverter.isSupportedType((String) type)) {
      result.error(
          StyleChecks.UNSUPPORTED_SOURCE_TYPE,
          "Source '" + sourceId + "' has the type '" + type + "', which this platform does not"
              + " support.",
          null);
      return;
    }
    final Source source =
        "image".equals(type) && !StyleChecks.isImageSource(properties)
            ? null
            : SourcePropertyConverter.buildSource(sourceId, (String) type, properties);
    if (source == null) {
      result.error(
          StyleChecks.INVALID_ARGUMENT,
          StyleChecks.unbuildableSource(sourceId, (String) type),
          null);
      return;
    }
    style.addSource(source);
    // setGeoJsonFeature edits only data this API was given as GeoJSON.
    addedFeaturesByLayer.remove(sourceId);
    if (source instanceof ImageSource) {
      imageSourceCoordinates.put(
          sourceId, SourcePropertyConverter.buildLatLngQuad(properties.get("coordinates")));
    } else {
      imageSourceCoordinates.remove(sourceId);
    }
    result.success(null);
  }

  @Override
  public void styleRemoveSource(String sourceId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    // The engine keeps a source a layer still uses, and what is known about it with it.
    if (style.removeSource(sourceId)) {
      imageSourceCoordinates.remove(sourceId);
      addedFeaturesByLayer.remove(sourceId);
    }
    result.success(null);
  }

  @Override
  public void styleAddImageSource(
      String imageSourceId,
      byte[] bytes,
      long length,
      PgLatLngQuad coordinates,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    if (rejectNonFinite(PigeonConvert.isFinite(coordinates), result)) {
      return;
    }
    Bitmap addSourceBitmap =
        BitmapFactory.decodeByteArray(bytes, 0, Convert.toIntExact(length));
    if (addSourceBitmap == null) {
      result.error("INVALID_IMAGE", "Failed to decode image bytes.", null);
      return;
    }
    final LatLngQuad quad = PigeonConvert.toLatLngQuad(coordinates);
    style.addSource(new ImageSource(imageSourceId, quad, addSourceBitmap));
    imageSourceCoordinates.put(imageSourceId, quad);
    addedFeaturesByLayer.remove(imageSourceId);
    result.success(null);
  }

  @Override
  public void styleUpdateImageSource(
      String imageSourceId,
      @Nullable byte[] bytes,
      @Nullable Long length,
      @Nullable PgLatLngQuad coordinates,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    final Source source = style.getSource(imageSourceId);
    if (!(source instanceof ImageSource)) {
      result.error("SOURCE_NOT_FOUND", "Image source " + imageSourceId + " not found.", null);
      return;
    }
    final ImageSource imageSource = (ImageSource) source;
    if (coordinates != null
        && rejectNonFinite(PigeonConvert.isFinite(coordinates), result)) {
      return;
    }
    // Decoded first, so a call that fails changes nothing.
    Bitmap updateBitmap = null;
    if (bytes != null) {
      updateBitmap = BitmapFactory.decodeByteArray(bytes, 0, Convert.toIntExact(length));
      if (updateBitmap == null) {
        result.error("INVALID_IMAGE", "Failed to decode image bytes.", null);
        return;
      }
    }
    if (coordinates != null) {
      final LatLngQuad quad = PigeonConvert.toLatLngQuad(coordinates);
      imageSource.setCoordinates(quad);
      imageSourceCoordinates.put(imageSourceId, quad);
    }
    if (updateBitmap != null) {
      imageSource.setImage(updateBitmap);
    }
    result.success(null);
  }

  @Override
  public void styleGetSourceIds(MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    List<String> sourceIds = new ArrayList<>();
    for (Source source : style.getSources()) {
      sourceIds.add(source.getId());
    }
    result.success(sourceIds);
  }

  @Override
  public void styleGetSourceProperties(String sourceId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    result.success(getSourceProperties(sourceId));
  }

  // -- Layers -----------------------------------------------------------------

  @Override
  public void symbolLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "symbol", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "symbol", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addSymbolLayer(
        layerId,
        sourceId,
        belowLayerId,
        sourceLayer,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        propertyValues,
        enableInteraction,
        filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void lineLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "line", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "line", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addLineLayer(
        layerId,
        sourceId,
        belowLayerId,
        sourceLayer,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        propertyValues,
        enableInteraction,
        filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void fillLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "fill", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "fill", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addFillLayer(
        layerId,
        sourceId,
        belowLayerId,
        sourceLayer,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        propertyValues,
        enableInteraction,
        filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void fillExtrusionLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "fill-extrusion", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "fill-extrusion", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addFillExtrusionLayer(
            layerId,
            sourceId,
            belowLayerId,
            sourceLayer,
            minzoom != null ? minzoom.floatValue() : null,
            maxzoom != null ? maxzoom.floatValue() : null,
            propertyValues,
            enableInteraction,
            filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void circleLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      boolean enableInteraction,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "circle", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "circle", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addCircleLayer(
        layerId,
        sourceId,
        belowLayerId,
        sourceLayer,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        propertyValues,
        enableInteraction,
        filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void rasterLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "raster", sourceId, null, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "raster", properties, result);
    if (propertyValues == null) {
      return;
    }
    if (!addRasterLayer(
        layerId,
        sourceId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        propertyValues,
        null)) {
      replyStyleNotReady(result);
      return;
    }
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void hillshadeLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "hillshade", sourceId, null, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "hillshade", properties, result);
    if (propertyValues == null) {
      return;
    }
    if (!addHillshadeLayer(
        layerId,
        sourceId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        propertyValues,
        null)) {
      replyStyleNotReady(result);
      return;
    }
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void colorReliefLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "color-relief", sourceId, null, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "color-relief", properties, result);
    if (propertyValues == null) {
      return;
    }
    if (!addColorReliefLayer(
        layerId,
        sourceId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        propertyValues,
        null)) {
      replyStyleNotReady(result);
      return;
    }
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void backgroundLayerAdd(
      String layerId,
      @Nullable String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "background", properties, result);
    if (propertyValues == null) {
      return;
    }
    if (!addBackgroundLayer(
        layerId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        propertyValues)) {
      replyStyleNotReady(result);
      return;
    }
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void heatmapLayerAdd(
      String sourceId,
      String layerId,
      @Nullable String belowLayerId,
      @Nullable String sourceLayer,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      @Nullable String filter,
      Map<String, Object> properties,
      MethodChannel.Result result) {
    if (rejectLayerAdd(layerId, "heatmap", sourceId, sourceLayer, result)) {
      return;
    }
    if (rejectInvalidLayerFilter(filter, result)) {
      return;
    }
    final PropertyValue[] propertyValues =
        checkedLayerProperties(layerId, "heatmap", properties, result);
    if (propertyValues == null) {
      return;
    }

    Expression filterExpression = parseFilter(filter);

    if (!addHeatmapLayer(
        layerId,
        sourceId,
        sourceLayer,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        propertyValues,
        filterExpression)) {
      replyStyleNotReady(result);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    updateLocationComponentLayer();

    result.success(null);
  }

  @Override
  public void layerSetProperties(
      String layerId, Map<String, Object> properties, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    final Layer layer = style.getLayer(layerId);
    if (layer == null) {
      replyLayerNotFound(result, layerId);
      return;
    }
    final String type = LayerPropertyConverter.layerType(layer);
    if (type == null) {
      result.error("UNSUPPORTED_LAYER_TYPE", "Layer type not supported", null);
      return;
    }
    final PropertyValue[] values = checkedLayerProperties(layerId, type, properties, result);
    if (values == null) {
      return;
    }
    layer.setProperties(values);
    result.success(null);
  }

  @Override
  public void layerSetVisibility(String layerId, boolean visible, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    Layer layer = style.getLayer(layerId);
    if (layer == null) {
      replyLayerNotFound(result, layerId);
      return;
    }

    layer.setProperties(PropertyFactory.visibility(visible ? Property.VISIBLE : Property.NONE));
    result.success(null);
  }

  @Override
  public void layerSetVisibilityBatch(
      List<String> layerIds, boolean visible, MethodChannel.Result result) {
    if (layerIds.isEmpty()) {
      result.success(new ArrayList<String>());
      return;
    }
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    // Unknown ids are skipped and returned, as on iOS and web.
    final String visibility = visible ? Property.VISIBLE : Property.NONE;
    final List<String> missingLayerIds = new ArrayList<>();
    for (String layerId : layerIds) {
      final Layer layer = style.getLayer(layerId);
      if (layer == null) {
        if (!missingLayerIds.contains(layerId)) {
          missingLayerIds.add(layerId);
        }
        continue;
      }
      layer.setProperties(PropertyFactory.visibility(visibility));
    }
    result.success(missingLayerIds);
  }

  @Override
  public void layerSetZoomRange(
      String layerId, double minzoom, double maxzoom, MethodChannel.Result result) {
    // Checked here because MapLibre takes any range, and iOS and web
    // reject the same values.
    if (!(minzoom >= 0 && maxzoom <= 24 && minzoom <= maxzoom)) {
      result.error(
          StyleChecks.INVALID_ARGUMENT,
          "Invalid zoom range [" + minzoom + ", " + maxzoom + "]: both must be within 0 and 24, "
              + "with minzoom not above maxzoom.",
          null);
      return;
    }
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    final Layer layer = style.getLayer(layerId);
    if (layer == null) {
      replyLayerNotFound(result, layerId);
      return;
    }
    layer.setMinZoom((float) minzoom);
    layer.setMaxZoom((float) maxzoom);
    result.success(null);
  }

  @Override
  public void layerGetVisibility(String layerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    Layer layer = style.getLayer(layerId);
    if (layer == null) {
      // Documented contract: null tells the caller there is no such layer.
      result.success(null);
      return;
    }
    result.success(!Property.NONE.equals(layer.getVisibility().getValue()));
  }

  @Override
  public void styleAddLayer(
      String imageLayerId,
      String imageSourceId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      MethodChannel.Result result) {
    if (rejectLayerAdd(imageLayerId, "raster", imageSourceId, null, result)) {
      return;
    }
    if (!addRasterLayer(
        imageLayerId,
        imageSourceId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        null,
        new PropertyValue[] {},
        null)) {
      replyStyleNotReady(result);
      return;
    }
    result.success(null);
  }

  @Override
  public void styleAddLayerBelow(
      String imageLayerId,
      String imageSourceId,
      String belowLayerId,
      @Nullable Double minzoom,
      @Nullable Double maxzoom,
      MethodChannel.Result result) {
    if (rejectLayerAdd(imageLayerId, "raster", imageSourceId, null, result)) {
      return;
    }
    if (!addRasterLayer(
        imageLayerId,
        imageSourceId,
        minzoom != null ? minzoom.floatValue() : null,
        maxzoom != null ? maxzoom.floatValue() : null,
        belowLayerId,
        new PropertyValue[] {},
        null)) {
      replyStyleNotReady(result);
      return;
    }
    result.success(null);
  }

  @Override
  public void styleRemoveLayer(String layerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    if (style.getLayer(layerId) == null) {
      replyLayerNotFound(result, layerId);
      return;
    }
    style.removeLayer(layerId);
    interactiveFeatureLayerIds.remove(layerId);
    layerFilters.remove(layerId);

    result.success(null);
  }

  @Override
  public void styleMoveLayer(
      String layerId, @Nullable String belowLayerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    Layer layer = style.getLayer(layerId);
    // Both layers are checked before anything moves: a missing anchor found
    // after the removal would lose the layer.
    if (layer == null) {
      replyLayerNotFound(result, layerId);
      return;
    }
    if (belowLayerId != null && style.getLayer(belowLayerId) == null) {
      replyLayerNotFound(result, belowLayerId);
      return;
    }
    if (layerId.equals(belowLayerId)) {
      result.success(null);
      return;
    }
    style.removeLayer(layer);
    if (belowLayerId != null) {
      style.addLayerBelow(layer, belowLayerId);
    } else {
      style.addLayer(layer);
    }
    result.success(null);
  }

  @Override
  public void styleSetFilter(
      String layerId, @Nullable String filter, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    Layer layer = style.getLayer(layerId);
    if (layer == null) {
      result.error(
          "LAYER_NOT_FOUND_ERROR", "Layer not found", "Layer with id " + layerId + " not found.");
      return;
    }

    if (!isFilterable(layer)) {
      result.error(
          "INVALID_LAYER_TYPE",
          "Invalid layer type",
          String.format("Layer '%s' does not support filtering.", layerId));
      return;
    }

    Expression parsed;
    try {
      parsed = parseFilter(filter);
    } catch (RuntimeException e) {
      result.error(StyleChecks.INVALID_EXPRESSION, "Invalid filter: " + e.getMessage(), e.getMessage());
      return;
    }
    // The SDK takes no null filter, so a null filter becomes the
    // always-true one, which is what an unfiltered layer has.
    final Expression expression = parsed != null ? parsed : Expression.literal(true);

    String error = captureFilterError(() -> setLayerFilter(layer, expression));
    if (error != null) {
      result.error(StyleChecks.INVALID_EXPRESSION, "Invalid filter: " + error, error);
      return;
    }
    layerFilters.put(layerId, filterJson(filter));
    result.success(null);
  }

  @Override
  public void styleGetFilter(String layerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    Layer layer = style.getLayer(layerId);
    if (layer == null) {
      result.error(
          "LAYER_NOT_FOUND_ERROR", "Layer not found", "Layer with id " + layerId + " not found.");
      return;
    }

    if (!isFilterable(layer)) {
      result.error(
              "INVALID_LAYER_TYPE",
              "Invalid layer type",
              String.format("Layer '%s' does not support filtering.", layerId));
      return;
    }

    JsonElement filter;
    try {
      filter = layerFilter(layer);
    } catch (ReflectiveOperationException e) {
      result.error("INTERNAL_ERROR", "Could not read the filter", e.toString());
      return;
    }
    result.success(filter == null ? null : new Gson().toJson(filter));
  }

  @Override
  public void mapSetLayerFilter(String id, String filter, MethodChannel.Result result) {
    // styleSetFilter as a boolean: false for any error, such as no style or layer, a layer that
    // takes no filter, or a filter the engine rejects.
    styleSetFilter(
        id,
        filter,
        new MethodChannel.Result() {
          @Override
          public void success(@Nullable Object value) {
            result.success(true);
          }

          @Override
          public void error(
              @NonNull String code, @Nullable String message, @Nullable Object details) {
            result.success(false);
          }

          @Override
          public void notImplemented() {
            result.success(false);
          }
        });
  }

  @Override
  public void styleGetLayerIds(MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    List<String> layerIds = new ArrayList<>();
    for (Layer layer : style.getLayers()) {
      layerIds.add(layer.getId());
    }
    result.success(layerIds);
  }

  @Override
  public void styleGetLayerProperties(String layerId, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    result.success(getLayerProperties(layerId));
  }

  // -- Style ------------------------------------------------------------------

  @Override
  public void styleAddImage(
      String name,
      byte[] bytes,
      long length,
      boolean sdf,
      @Nullable Double pixelRatio,
      MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    BitmapFactory.Options options = new BitmapFactory.Options();
    options.inScaled = false;
    options.inDensity = 0;
    options.inTargetDensity = 0;
    Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, Convert.toIntExact(length), options);
    if (bitmap == null) {
      result.error("INVALID_IMAGE", "Failed to decode image bytes.", null);
      return;
    }
    // MapLibre reads the image's pixel ratio from the bitmap density, which is the screen's unless
    // the caller gives one.
    if (pixelRatio != null) {
      bitmap.setDensity(
          Math.max(1, (int) Math.round(pixelRatio * DisplayMetrics.DENSITY_DEFAULT)));
    }
    style.addImage(name, bitmap, sdf);
    result.success(null);
  }

  @Override
  public void styleSetLight(Map<String, Object> lightProperties, MethodChannel.Result result) {
    if (style == null || !style.isFullyLoaded()) {
      replyStyleNotReady(result);
      return;
    }
    // Every LightProperties field is dynamic, so anything can arrive here. The
    // values are checked rather than cast: MapLibre Native takes constants only,
    // and an expression is a List, which would fail the call as a bare
    // ClassCastException. All fields are checked before any is applied, so a
    // rejected call changes nothing.
    final String constantsOnly =
        " MapLibre Native takes constant light values only, not expressions.";
    final Object anchor = lightProperties.get("anchor");
    if (anchor != null && !(anchor instanceof String)) {
      result.error(
          StyleChecks.INVALID_ARGUMENT, "Invalid 'anchor' in 'light'." + constantsOnly, null);
      return;
    }
    final Object position = lightProperties.get("position");
    final List<?> positionValues = position instanceof List ? (List<?>) position : null;
    if (position != null
        && (positionValues == null
            || positionValues.size() != 3
            || !(positionValues.get(0) instanceof Number)
            || !(positionValues.get(1) instanceof Number)
            || !(positionValues.get(2) instanceof Number))) {
      result.error(
          StyleChecks.INVALID_ARGUMENT,
          "Invalid 'position' in 'light'. Expected three numbers, [radial, azimuthal,"
              + " polar]."
              + constantsOnly,
          null);
      return;
    }
    final Object color = lightProperties.get("color");
    if (color != null && !(color instanceof String)) {
      result.error(StyleChecks.INVALID_ARGUMENT, "Invalid 'color' in 'light'." + constantsOnly, null);
      return;
    }
    final Object intensity = lightProperties.get("intensity");
    if (intensity != null && !(intensity instanceof Number)) {
      result.error(
          StyleChecks.INVALID_ARGUMENT, "Invalid 'intensity' in 'light'." + constantsOnly, null);
      return;
    }

    final Light light = style.getLight();
    if (anchor != null) {
      light.setAnchor((String) anchor);
    }
    if (positionValues != null) {
      light.setPosition(
          new Position(
              ((Number) positionValues.get(0)).floatValue(),
              ((Number) positionValues.get(1)).floatValue(),
              ((Number) positionValues.get(2)).floatValue()));
    }
    if (color != null) {
      light.setColor((String) color);
    }
    if (intensity != null) {
      light.setIntensity(((Number) intensity).floatValue());
    }
    result.success(null);
  }

  @Override
  public void styleSetStyle(String styleString, MethodChannel.Result result) {
    // A style JSON, URL, path or asset name.
    setStyleString(styleString);
    result.success(null);
  }

  @Override
  public void mapGetStyle(MethodChannel.Result result) {
    String json = null;
    final Style style = mapLibreMap.getStyle();
    if (style != null) {
      try {
        json = style.getJson();
      } catch (Exception e) {
        // A style still loading has no JSON yet.
      }
    }
    result.success(json);
  }

  @Override
  public void onCameraMoveStarted(int reason) {
    final boolean isGesture = reason == MapLibreMap.OnCameraMoveStartedListener.REASON_API_GESTURE;
    flutterApi.cameraOnMoveStarted(isGesture, PigeonReplies.IGNORE);
  }

  @Override
  public void onCameraMove() {
    if (!trackCameraPosition) {
      return;
    }
    flutterApi.cameraOnMove(
        Convert.toPgCameraPosition(mapLibreMap.getCameraPosition()), PigeonReplies.IGNORE);
  }

  @Override
  public void onCameraIdle() {
    flutterApi.cameraOnIdle(
        trackCameraPosition
            ? Convert.toPgCameraPosition(mapLibreMap.getCameraPosition())
            : null,
        PigeonReplies.IGNORE);
  }

  @Override
  public void onCameraTrackingChanged(int currentMode) {
    final PgMyLocationTrackingMode mode;
    switch (currentMode) {
        case CameraMode.NONE:
            mode = PgMyLocationTrackingMode.NONE;
            break;
        case CameraMode.TRACKING:
            mode = PgMyLocationTrackingMode.TRACKING;
            break;
        case CameraMode.TRACKING_COMPASS:
            mode = PgMyLocationTrackingMode.TRACKING_COMPASS;
            break;
        case CameraMode.TRACKING_GPS:
            mode = PgMyLocationTrackingMode.TRACKING_GPS;
            break;
        default:
            Log.e(TAG, "Unable to map " + currentMode + " to a tracking mode");
            return;
    }

    flutterApi.mapOnCameraTrackingChanged(mode, PigeonReplies.IGNORE);
  }

  @Override
  public void onCameraTrackingDismissed() {
    this.myLocationTrackingMode = 0;
    flutterApi.mapOnCameraTrackingDismissed(PigeonReplies.IGNORE);
  }

  @Override
  public void onDidBecomeIdle() {
    flutterApi.mapOnIdle(PigeonReplies.IGNORE);
  }

  @Override
  public boolean onMapClick(@NonNull LatLng point) {
    // MapLibre confirms a single tap only after the double-tap timeout. A tap tapDetector already
    // reported on touch-up is not reported again; any other tap is, even while double-tap zoom
    // is off, so a tap the two detectors judge differently arrives late rather than never.
    if (tapReportedOnTouchUp) {
      tapReportedOnTouchUp = false;
      return true;
    }
    reportTap(mapLibreMap.getProjection().toScreenLocation(point), point);
    return true;
  }

  /**
   * Whether taps are reported on touch-up by {@link #tapDetector} rather than from {@link
   * #onMapClick}. True while a double tap does not zoom, which in MapLibre takes both zoom and
   * double-tap gestures: a single tap then needs no confirmation that a second tap is not coming,
   * and iOS reports it on touch-up in that case too.
   */
  private boolean reportsTapsOnTouchUp() {
    if (mapLibreMap == null) {
      return false;
    }
    final UiSettings uiSettings = mapLibreMap.getUiSettings();
    return !(uiSettings.isZoomGesturesEnabled() && uiSettings.isDoubleTapGesturesEnabled());
  }

  /** Reports a tap at {@code pointf}: the feature under it, if any, and the map click. */
  private void reportTap(PointF pointf, LatLng point) {
    Pair<Feature, String> featureLayerPair = firstFeatureOnLayers(pointf, false);
    final PgScreenPoint screenPoint = toScreenPoint(pointf);
    final PgLatLng latLng = new PgLatLng(point.getLatitude(), point.getLongitude());
    if (featureLayerPair != null && featureLayerPair.first != null) {
      flutterApi.featureOnTap(
          new PgFeatureTap(
              featureLayerPair.first.id(), screenPoint, latLng, featureLayerPair.second),
          PigeonReplies.IGNORE);
      // Fire map#onMapClick only if featureTapsTriggersMapClick is true
      if (featureTapsTriggersMapClick) {
        flutterApi.mapOnMapClick(screenPoint, latLng, PigeonReplies.IGNORE);
      }
    } else {
      // Always fire map#onMapClick when no feature is tapped
      flutterApi.mapOnMapClick(screenPoint, latLng, PigeonReplies.IGNORE);
    }
  }

  @Override
  public boolean onMapLongClick(@NonNull LatLng point) {
    PointF pointf = mapLibreMap.getProjection().toScreenLocation(point);
    flutterApi.mapOnMapLongClick(
        toScreenPoint(pointf),
        new PgLatLng(point.getLatitude(), point.getLongitude()),
        PigeonReplies.IGNORE);
    return true;
  }

  @Override
  public void dispose() {
    if (disposed) {
      return;
    }
    disposed = true;
    cancelSnapshot("MAP_DISPOSED", "The map was disposed before the snapshot was ready.");
    MapLibreMapHostApi.Companion.setUp(messenger, null, String.valueOf(id));
    // A mapWaitForMap call parked while the map was still being built is only ever
    // answered by onMapReady, which will not fire now. Answer it here, or the Dart
    // side keeps awaiting initPlatform: onMapCreated never fires and everything
    // waiting on the controller waits forever. Only dispose() does this; a MapView
    // torn down for an activity recreation is rebuilt and does reach onMapReady.
    if (mapReadyResult != null) {
      mapReadyResult.error(
          "MAP_DISPOSED", "The map was disposed before it finished being created", null);
      mapReadyResult = null;
    }
    // destroyMapViewIfNecessary drives the full pause -> stop -> destroy sequence,
    // gated by the mapViewResumed/Started/Created flags so each step fires at most
    // once. No manual onPause/onStop dance needed here.
    destroyMapViewIfNecessary();
    unregisterFromLifecycle();

    try {
      applicationContext.unregisterComponentCallbacks(this);
    } catch (Exception e) {
      // Ignore if already unregistered
    }
  }

  /**
   * Destroy the {@link MapView} and clean up listeners.
   *
   * <p>It's very important to call {@code mapViewContainer.removeView(mapView)} to make
   * sure that {@link TextureView#onDetachedFromWindowInternal()} is called, which
   * releases the underlying surface. This is required due to a FlutterEngine change
   * introduced between Flutter 2.10.5 and 3.10.0 where {@code removeView} is no longer
   * called on a PlatformView automatically.
   *
   * <p>The teardown drives the MapView lifecycle backwards using the
   * {@code mapViewResumed/Started/Created} flags, so each step fires at most once
   * regardless of whether dispose, lifecycle-onDestroy, or a manual detach got here
   * first. Before destroying, MapLibre's internal state is persisted into
   * {@link #savedMapViewState} so a subsequent {@link #recreateMapViewIfNecessary()}
   * can restore it.
   *
   * <p>For more information see:
   * <a href="https://github.com/flutter/flutter/issues/107297">Flutter issue</a>,
   * <a href="https://github.com/flutter/engine/commit/8dc7cd1b1a33b5da561ac859cdcc49705ad1e598">the
   * Flutter Engine commit that introduced the issue</a>, and
   * <a href="https://github.com/maplibre/flutter-maplibre-gl/issues/182">the
   * MapLibre tracking issue</a>.
   */
  private void destroyMapViewIfNecessary() {
    if (mapView == null) {
      return;
    }

    // MapView.onDestroy tears the map down without ending a running camera animation, so the
    // animateCamera or easeCamera call waiting for it would never complete. Cancelling it first
    // answers that call with false, as on iOS and web; onDestroy below drops the camera events the
    // cancel queues.
    if (mapLibreMap != null && mapViewCreated) {
      mapLibreMap.cancelTransitions();
    }

    if (locationComponent != null) {
      locationComponent.setLocationComponentEnabled(false);
    }
    stopListeningForLocationUpdates();

    // Persist MapView state so it can be restored when a new MapView is created
    // (e.g. across "Don't keep activities" or rotation).
    if (mapViewCreated) {
      try {
        mapView.onSaveInstanceState(savedMapViewState);
      } catch (Exception e) {
        Log.w(TAG, "mapView.onSaveInstanceState failed", e);
      }
    }

    mapViewContainer.removeView(mapView);

    if (mapViewResumed) {
      mapView.onPause();
      mapViewResumed = false;
    }
    if (mapViewStarted) {
      mapView.onStop();
      mapViewStarted = false;
    }
    if (mapViewCreated) {
      mapView.onDestroy();
      mapViewCreated = false;
    }

    mapLibreMap = null;
    style = null;
    locationComponent = null;
    mapView = null;
  }

  // -- Lifecycle observer ----------------------------------------------------
  //
  // Each transition below mutates the MapView at most once per instance. Jetpack's
  // Lifecycle.addObserver replays missed events synchronously when we subscribe to a
  // fresh activity Lifecycle, and without the guards that replay would re-call
  // onCreate / onStart / onResume on an already initialized MapView.

  @Override
  public void onCreate(@NonNull LifecycleOwner owner) {
    if (disposed || mapView == null || mapViewCreated) {
      return;
    }
    // savedMapViewState is empty on first launch and populated on subsequent
    // recreations via destroyMapViewIfNecessary().
    mapView.onCreate(savedMapViewState);
    mapViewCreated = true;
  }

  @Override
  public void onStart(@NonNull LifecycleOwner owner) {
    if (disposed || mapView == null || mapViewStarted) {
      return;
    }
    mapView.onStart();
    mapViewStarted = true;
    // MapView.onStart starts the location component's engine again.
    stopLocationComponentWhileUserPaused();
  }

  @Override
  public void onResume(@NonNull LifecycleOwner owner) {
    if (disposed || mapView == null || mapViewResumed) {
      return;
    }
    if (userPaused) {
      // Dart has explicitly paused rendering. Stay paused until resumeMap() is
      // called, even though the host activity is in the foreground.
      return;
    }
    mapView.onResume();
    mapViewResumed = true;
    if (myLocationEnabled) {
      startListeningForLocationUpdates();
    }
    // Force a repaint to fix invisible map when returning from background.
    // The runnable is dispatched after the message loop drains, by which time
    // dispose() may have nulled mapView (e.g. a map hosted in a Dialog or
    // BottomSheet that is dismissed mid-resume). Re-check disposed/mapView
    // inside the runnable to mirror the guard at the top of onResume.
    mapView.post(new Runnable() {
      @Override
      public void run() {
        if (disposed || mapView == null) {
          return;
        }
        mapView.invalidate();
      }
    });
  }

  @Override
  public void onPause(@NonNull LifecycleOwner owner) {
    if (disposed || mapView == null || !mapViewResumed) {
      return;
    }
    mapView.onPause();
    mapViewResumed = false;
    // The location component stops its own updates with the MapView, but not the listener that
    // forwards positions to Dart: without this the GPS stays on in the background (#1094).
    // onResume starts it again.
    stopListeningForLocationUpdates();
  }

  @Override
  public void onStop(@NonNull LifecycleOwner owner) {
    if (disposed || mapView == null || !mapViewStarted) {
      return;
    }
    mapView.onStop();
    mapViewStarted = false;
  }

  @Override
  public void onDestroy(@NonNull LifecycleOwner owner) {
    if (owner.getLifecycle() != boundLifecycle) {
      // Stale callback from an old activity (e.g. after config change where we already
      // rebound to the new lifecycle). Ignore it: destroying now would kill the live map.
      return;
    }
    unregisterFromLifecycle();
    if (disposed) {
      return;
    }
    saveCameraPosition();
    destroyMapViewIfNecessary();
  }

  @Override
  public void onConfigurationChanged(@NonNull Configuration newConfig) {
    this.density = context.getResources().getDisplayMetrics().density;
  }

  @Override
  public void onLowMemory() {
    if (disposed || mapView == null) {
      return;
    }
    Log.w(TAG, "onLowMemory has been called, telling MapView to reduce memory usage.");
    // Forward low memory event to MapView
    mapView.onLowMemory();
  }

  @Override
  public void onTrimMemory(int level) {
    // Lifecycle methods already handle resource management
  }

  // MapLibreMapOptionsSink methods

  @Override
  public void setCameraTargetBounds(LatLngBounds bounds) {
    this.bounds = bounds;
    if (mapLibreMap != null) {
      mapLibreMap.setLatLngBoundsForCameraTarget(bounds);
    }
  }

  @Override
  public void setLocationEngineProperties(@NotNull LocationEngineRequest locationEngineRequest) {
    myLocationEngineFactory.initLocationComponent(context, locationComponent, locationEngineRequest);
  }

  @Override
  public void setLocationSource(@NotNull String token) {
    // The token -> behavior mapping lives here, native-side. Any value other
    // than "manual" (e.g. "platform"/unknown) resolves to the default engine.
    // Applied at component activation; runtime changes do not re-activate it.
    this.manualLocationSource = "manual".equals(token);
  }

  @Override
  public void setCompassEnabled(boolean compassEnabled) {
    mapLibreMap.getUiSettings().setCompassEnabled(compassEnabled);
  }

  @Override
  public void setTrackCameraPosition(boolean trackCameraPosition) {
    this.trackCameraPosition = trackCameraPosition;
  }

  @Override
  public void setRotateGesturesEnabled(boolean rotateGesturesEnabled) {
    mapLibreMap.getUiSettings().setRotateGesturesEnabled(rotateGesturesEnabled);
  }

  @Override
  public void setScrollGesturesEnabled(boolean scrollGesturesEnabled) {
    mapLibreMap.getUiSettings().setScrollGesturesEnabled(scrollGesturesEnabled);
  }

  @Override
  public void setPanInertia(int panInertia) {
    this.panInertia = panInertia;
    applyPanInertia();
  }

  /**
   * Applies {@link #panInertia} to the fling that follows a pan. The SDK glides for {@code
   * velocity / 10.5 + baseTime} ms (dp/s, untilted map) and skips flings slower than the
   * threshold:
   *
   * <ul>
   *   <li>none (0): fling animation off.
   *   <li>short (1): base time 0 ms, threshold 1000 dp/s, about half the glide of normal at a
   *       typical 2000 dp/s.
   *   <li>normal (2): SDK defaults, base time 150 ms and threshold 1000 dp/s.
   * </ul>
   */
  private void applyPanInertia() {
    if (panInertia == null || mapLibreMap == null) {
      return;
    }
    final UiSettings uiSettings = mapLibreMap.getUiSettings();
    uiSettings.setFlingVelocityAnimationEnabled(panInertia != 0);
    uiSettings.setFlingAnimationBaseTime(
        panInertia == 1 ? 0 : MapLibreConstants.ANIMATION_DURATION_FLING_BASE);
    uiSettings.setFlingThreshold(MapLibreConstants.VELOCITY_THRESHOLD_IGNORE_FLING);
  }

  @Override
  public void setTiltGesturesEnabled(boolean tiltGesturesEnabled) {
    mapLibreMap.getUiSettings().setTiltGesturesEnabled(tiltGesturesEnabled);
  }

  @Override
  public void setMinMaxZoomPreference(Float min, Float max) {
    mapLibreMap.setMinZoomPreference(min != null ? min : MapLibreConstants.MINIMUM_ZOOM);
    mapLibreMap.setMaxZoomPreference(max != null ? max : MapLibreConstants.MAXIMUM_ZOOM);
  }

  @Override
  public void setZoomGesturesEnabled(boolean zoomGesturesEnabled) {
    mapLibreMap.getUiSettings().setZoomGesturesEnabled(zoomGesturesEnabled);
  }

  @Override
  public void setDoubleClickZoomEnabled(boolean doubleClickZoomEnabled) {
    mapLibreMap.getUiSettings().setDoubleTapGesturesEnabled(doubleClickZoomEnabled);
  }

  @Override
  public void setMyLocationEnabled(boolean myLocationEnabled) {
    if (this.myLocationEnabled == myLocationEnabled) {
      return;
    }
    this.myLocationEnabled = myLocationEnabled;
    if (mapLibreMap != null) {
      updateMyLocationEnabled();
    }
  }

  @Override
  public void setMyLocationTrackingMode(int myLocationTrackingMode) {
    if (mapLibreMap != null) {
      // ensure that location is trackable
      updateMyLocationEnabled();
    }
    if (this.myLocationTrackingMode == myLocationTrackingMode) {
      return;
    }
    this.myLocationTrackingMode = myLocationTrackingMode;
    if (mapLibreMap != null && locationComponent != null) {
      updateMyLocationTrackingMode();
    }
  }

  @Override
  public void setMyLocationStyle(@NonNull LocationPuckStyle puckStyle) {
    myLocationStyle = puckStyle;
    if (locationComponent != null && locationComponent.isLocationComponentActivated()) {
      // Restyle in place: buildLocationComponentOptions reads the new colors and
      // keeps the puck above the topmost layer, as when a layer is added.
      locationComponent.applyStyle(buildLocationComponentOptions(style));
    }
  }

  @Override
  public void setMyLocationRenderMode(int myLocationRenderMode) {
    if (this.myLocationRenderMode == myLocationRenderMode) {
      return;
    }
    this.myLocationRenderMode = myLocationRenderMode;
    if (mapLibreMap != null && locationComponent != null) {
      updateMyLocationRenderMode();
    }
  }

  @Override
  public void setLogoEnabled(boolean logoEnabled) {
    mapLibreMap.getUiSettings().setLogoEnabled(logoEnabled);
  }

  @Override
  public void setLogoViewGravity(int gravity) {
    switch (gravity) {
      case 0:
        mapLibreMap.getUiSettings().setLogoGravity(Gravity.TOP | Gravity.START);
        break;
      case 1:
        mapLibreMap.getUiSettings().setLogoGravity(Gravity.TOP | Gravity.END);
        break;
      default:
      case 2:
        mapLibreMap.getUiSettings().setLogoGravity(Gravity.BOTTOM | Gravity.START);
        break;
      case 3:
        mapLibreMap.getUiSettings().setLogoGravity(Gravity.BOTTOM | Gravity.END);
        break;
    }
  }

  public void setLogoViewMargins(int x, int y) {
    mapLibreMap.getUiSettings().setLogoMargins(x, 0, 0, y);
  }

  @Override
  public void setCompassGravity(int gravity) {
    switch (gravity) {
      case 0:
        mapLibreMap.getUiSettings().setCompassGravity(Gravity.TOP | Gravity.START);
        break;
      default:
      case 1:
        mapLibreMap.getUiSettings().setCompassGravity(Gravity.TOP | Gravity.END);
        break;
      case 2:
        mapLibreMap.getUiSettings().setCompassGravity(Gravity.BOTTOM | Gravity.START);
        break;
      case 3:
        mapLibreMap.getUiSettings().setCompassGravity(Gravity.BOTTOM | Gravity.END);
        break;
    }
  }

  @Override
  public void setCompassViewMargins(int x, int y) {
    switch (mapLibreMap.getUiSettings().getCompassGravity()) {
      case Gravity.TOP | Gravity.START:
        mapLibreMap.getUiSettings().setCompassMargins(x, y, 0, 0);
        break;
      default:
      case Gravity.TOP | Gravity.END:
        mapLibreMap.getUiSettings().setCompassMargins(0, y, x, 0);
        break;
      case Gravity.BOTTOM | Gravity.START:
        mapLibreMap.getUiSettings().setCompassMargins(x, 0, 0, y);
        break;
      case Gravity.BOTTOM | Gravity.END:
        mapLibreMap.getUiSettings().setCompassMargins(0, 0, x, y);
        break;
    }
  }

  @Override
  public void setAttributionEnabled(boolean attributionEnabled) {
    mapLibreMap.getUiSettings().setAttributionEnabled(attributionEnabled);
  }

  @Override
  public void setAttributionButtonGravity(int gravity) {
    switch (gravity) {
      case 0:
        mapLibreMap.getUiSettings().setAttributionGravity(Gravity.TOP | Gravity.START);
        break;
      default:
      case 1:
        mapLibreMap.getUiSettings().setAttributionGravity(Gravity.TOP | Gravity.END);
        break;
      case 2:
        mapLibreMap.getUiSettings().setAttributionGravity(Gravity.BOTTOM | Gravity.START);
        break;
      case 3:
        mapLibreMap.getUiSettings().setAttributionGravity(Gravity.BOTTOM | Gravity.END);
        break;
    }
  }

  @Override
  public void setAttributionButtonMargins(int x, int y) {
    switch (mapLibreMap.getUiSettings().getAttributionGravity()) {
      case Gravity.TOP | Gravity.START:
        mapLibreMap.getUiSettings().setAttributionMargins(x, y, 0, 0);
        break;
      default:
      case Gravity.TOP | Gravity.END:
        mapLibreMap.getUiSettings().setAttributionMargins(0, y, x, 0);
        break;
      case Gravity.BOTTOM | Gravity.START:
        mapLibreMap.getUiSettings().setAttributionMargins(x, 0, 0, y);
        break;
      case Gravity.BOTTOM | Gravity.END:
        mapLibreMap.getUiSettings().setAttributionMargins(0, 0, x, y);
        break;
    }
  }

  @Override
  public void setAttributionButtonColor(int color) {
    attributionButtonColor = color;
    if (mapLibreMap != null) {
      mapLibreMap.getUiSettings().setAttributionTintColor(color);
    }
  }

  @Override
  public void setForegroundLoadColor(int color) {
    // foregroundLoadColor is only useful during initial map creation
    // not for runtime updates, so this is a no-op
  }

  @Override
  public void setTranslucentTextureSurface(boolean translucentTextureSurface) {
    // translucentTextureSurface is only useful during initial map creation
    // not for runtime updates, so this is a no-op
  }

  @Override
  public void setFeatureTapsTriggersMapClick(boolean triggers) {
    this.featureTapsTriggersMapClick = triggers;
  }

  @Override
  public void setSymbolPlacementTransitionsEnabled(boolean enabled) {
    this.symbolPlacementTransitionsEnabled = enabled;
    if (style != null && style.isFullyLoaded()) {
      applyPlacementTransitions(style);
      // With transitions off nothing asks MapLibre for another frame once
      // placement is done (no fade is running), so data placed while they were
      // off can stay undrawn until the map next moves. One frame now draws it.
      mapLibreMap.triggerRepaint();
    }
  }

  /**
   * Turns MapLibre's placement transitions on or off for [style], keeping the style's own
   * transition duration and delay.
   *
   * <p>With them on, placement runs at most every 300 ms and fades symbols in: a symbol whose data
   * just changed can be drawn, hidden by the next placement and faded back in. With them off,
   * placement runs every frame and symbols change in the frame their data arrives.
   *
   * <p>The style is left alone while they are on and were never turned off, since writing its
   * transition back is not a no-op: a style that sets none reads back as 0 ms, and an explicit 0
   * turns off the symbol fade that MapLibre otherwise runs for 300 ms. For the same reason, turning
   * them back on for such a style restores its paint transitions exactly but leaves symbols
   * without a fade until the next style load.
   */
  private void applyPlacementTransitions(@NonNull Style style) {
    if (!symbolPlacementTransitionsEnabled) {
      if (transitionBeforePlacementOff != null) return; // already off
      final TransitionOptions current = style.getTransition();
      transitionBeforePlacementOff = current;
      style.setTransition(
          new TransitionOptions(current.getDuration(), current.getDelay(), false));
    } else {
      final TransitionOptions saved = transitionBeforePlacementOff;
      if (saved == null) return; // never turned off
      transitionBeforePlacementOff = null;
      style.setTransition(new TransitionOptions(saved.getDuration(), saved.getDelay(), true));
    }
  }

  private void updateMyLocationEnabled() {
    if (this.locationComponent == null && mapLibreMap.getStyle() != null && myLocationEnabled) {
      enableLocationComponent(mapLibreMap.getStyle());
    }

    // Only while the MapView is resumed: paused from Dart or by the activity, onResume and
    // mapResume start the listener when the map comes back (#1094).
    if (myLocationEnabled && mapViewResumed) {
      startListeningForLocationUpdates();
    } else {
      stopListeningForLocationUpdates();
    }

    if (locationComponent != null) {
      locationComponent.setLocationComponentEnabled(myLocationEnabled);
    }
    stopLocationComponentWhileUserPaused();
    if (isPuckVisible()) {
      pendingManualLocation.flush(this::showManualLocation);
    }
  }

  /**
   * The location component runs its own location engine from MapView.onStart to onStop, so
   * pausing the MapView alone leaves the GPS on. While Dart has paused the map, stop the
   * component as the activity's onStop would; mapResume starts it again (#1094).
   */
  private void stopLocationComponentWhileUserPaused() {
    if (userPaused && locationComponent != null) {
      locationComponent.onStop();
    }
  }

  private void startListeningForLocationUpdates() {
    if (locationEngineCallback == null
        && locationComponent != null
        && locationComponent.isLocationComponentActivated()
        && locationComponent.getLocationEngine() != null) {
      locationEngineCallback =
          new LocationEngineCallback<LocationEngineResult>() {
            @Override
            public void onSuccess(LocationEngineResult result) {
              onUserLocationUpdate(result.getLastLocation());
            }

            @Override
            public void onFailure(@NonNull Exception exception) {}
          };
      locationComponent
          .getLocationEngine()
          .requestLocationUpdates(
              locationComponent.getLocationEngineRequest(), locationEngineCallback, null);
    }
  }

  private void stopListeningForLocationUpdates() {
    if (locationEngineCallback != null
        && locationComponent != null
        && locationComponent.isLocationComponentActivated()
        && locationComponent.getLocationEngine() != null) {
      locationComponent.getLocationEngine().removeLocationUpdates(locationEngineCallback);
      locationEngineCallback = null;
    }
  }

  private void updateMyLocationTrackingMode() {
    int[] cameraModes =
        new int[] {
          CameraMode.NONE, CameraMode.TRACKING, CameraMode.TRACKING_COMPASS, CameraMode.TRACKING_GPS
        };
    locationComponent.setCameraMode(cameraModes[this.myLocationTrackingMode]);
  }

  private void updateMyLocationRenderMode() {
    int[] renderModes = new int[] {RenderMode.NORMAL, RenderMode.COMPASS, RenderMode.GPS};
    locationComponent.setRenderMode(renderModes[this.myLocationRenderMode]);
  }

  private boolean hasLocationPermission() {
    return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
            == PackageManager.PERMISSION_GRANTED
        || checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
            == PackageManager.PERMISSION_GRANTED;
  }

  private int checkSelfPermission(String permission) {
    if (permission == null) {
      throw new IllegalArgumentException("permission is null");
    }
    return context.checkPermission(
        permission, android.os.Process.myPid(), android.os.Process.myUid());
  }

  // The gestures manager for feature drags. Without a move threshold any move, even one of zero
  // pixels, turned a tap into a drag.
  private static AndroidGesturesManager createDragGesturesManager(Context context) {
    final AndroidGesturesManager manager = new AndroidGesturesManager(context, false);
    manager
        .getMoveGestureDetector()
        .setMoveThreshold(ViewConfiguration.get(context).getScaledTouchSlop());
    return manager;
  }

  // Every touch on the map passes through here before the map's own gesture detector sees it.
  private boolean onMapTouch(View view, MotionEvent event) {
    if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
      tapReportedOnTouchUp = false;
    }
    tapDetector.onTouchEvent(event);
    return androidGesturesManager != null && onDragTouch(view, event);
  }

  private boolean onDragTouch(View view, MotionEvent event) {
    final int action = event.getActionMasked();
    if (action == MotionEvent.ACTION_DOWN) {
      dragOwnsGesture = false;
      // A stream that never got its up or cancel must not leave its candidate to this gesture.
      forgetDragCandidate();
      rememberDragCandidate(new PointF(event.getX(), event.getY()));
    } else if (event.getPointerCount() > 1 && !dragOwnsGesture) {
      // A second finger before the drag started: a pinch, the map's to handle.
      forgetDragCandidate();
    } else if (action == MotionEvent.ACTION_POINTER_DOWN && dragOwnsGesture) {
      // A second finger during a drag ends it, and the map takes over the gesture so it can pinch.
      if (draggedFeature != null) {
        endDragAtLastPosition();
      }
      dragOwnsGesture = false;
      handGestureToMap(view, event);
    }

    final boolean ownedBefore = dragOwnsGesture;
    androidGesturesManager.onTouchEvent(event);
    if (!ownedBefore && dragOwnsGesture) {
      // The map saw the finger come down; without a cancel its long press fires in the middle of
      // the drag, since it never sees the moves.
      final MotionEvent cancel = MotionEvent.obtain(event);
      cancel.setAction(MotionEvent.ACTION_CANCEL);
      view.onTouchEvent(cancel);
      cancel.recycle();
    }

    // Once a drag has started the gesture is the drag's until it ends. Before that,
    // within the touch slop, a touch on a draggable feature may still be a tap: the map gets the
    // down and the up, not the tremble in between.
    final boolean consumed =
        dragOwnsGesture || (dragCandidate != null && action == MotionEvent.ACTION_MOVE);
    if (action == MotionEvent.ACTION_UP || action == MotionEvent.ACTION_CANCEL) {
      dragOwnsGesture = false;
      forgetDragCandidate();
    }
    return consumed;
  }

  // The map got a cancel when the drag started, so it needs a fresh down for the finger that was
  // dragging. The second finger's own down (this event) then reaches the map as usual.
  private static void handGestureToMap(View view, MotionEvent event) {
    final int kept = event.getActionIndex() == 0 ? 1 : 0;
    final MotionEvent.PointerProperties[] properties = {new MotionEvent.PointerProperties()};
    final MotionEvent.PointerCoords[] coords = {new MotionEvent.PointerCoords()};
    event.getPointerProperties(kept, properties[0]);
    event.getPointerCoords(kept, coords[0]);
    final MotionEvent down =
        MotionEvent.obtain(
            event.getEventTime(),
            event.getEventTime(),
            MotionEvent.ACTION_DOWN,
            1,
            properties,
            coords,
            event.getMetaState(),
            event.getButtonState(),
            event.getXPrecision(),
            event.getYPrecision(),
            event.getDeviceId(),
            event.getEdgeFlags(),
            event.getSource(),
            event.getFlags());
    view.onTouchEvent(down);
    down.recycle();
  }

  // The feature is looked up where the finger came down, where the user aimed: the move detector
  // only reports the gesture once the finger has left the touch slop.
  private void rememberDragCandidate(PointF point) {
    Pair<Feature, String> featureLayerPair = firstFeatureOnLayers(point, true);
    if (featureLayerPair != null
        && featureLayerPair.first != null
        && isDraggable(featureLayerPair.first)) {
      dragCandidate = featureLayerPair.first;
    }
  }

  private void forgetDragCandidate() {
    dragCandidate = null;
  }

  boolean onMoveBegin(MoveGestureDetector detector) {
    // Called on every move until it returns true; move end is not called unless it did.
    if (dragCandidate == null || detector.getPointersCount() != 1) {
      return false;
    }
    // Like iOS, the drag starts where the finger left the touch slop: origin and current are that
    // point and the start event has a zero delta. The drag events after it carry the movement.
    final PointF start = detector.getFocalPoint();
    startDragging(dragCandidate, mapLibreMap.getProjection().fromScreenLocation(start));
    forgetDragCandidate();
    dragOwnsGesture = true;
    invokeFeatureDrag(start, "start");
    return true;
  }

  private void invokeFeatureDrag(PointF pointf, String eventType) {
    invokeFeatureDrag(pointf, mapLibreMap.getProjection().fromScreenLocation(pointf), eventType);
  }

  private void invokeFeatureDrag(PointF pointf, LatLng current, String eventType) {
    final PgFeatureDrag drag =
        new PgFeatureDrag(
            draggedFeature.id(),
            toScreenPoint(pointf),
            new PgLatLng(dragOrigin.getLatitude(), dragOrigin.getLongitude()),
            new PgLatLng(current.getLatitude(), current.getLongitude()),
            new PgLatLng(
                current.getLatitude() - dragPrevious.getLatitude(),
                current.getLongitude() - dragPrevious.getLongitude()),
            eventType);
    dragPrevious = current;
    flutterApi.featureOnDrag(drag, PigeonReplies.IGNORE);
  }

  boolean onMove(MoveGestureDetector detector) {
    if (draggedFeature != null) {
      if (detector.getPointersCount() > 1) {
        // A second finger ends the drag (onDragTouch normally ends it first, on the finger's
        // down). Without this the listeners never saw an "end", and onMoveEnd threw on the
        // cleared feature.
        endDragAtLastPosition();
        return true;
      }
      PointF pointf = detector.getFocalPoint();
      invokeFeatureDrag(pointf, "drag");
      return false;
    }
    return true;
  }

  // Ends the drag where the feature was last dragged to, with a zero delta: with a second finger
  // down the focal point is the midpoint of the two fingers, not where the feature is.
  private void endDragAtLastPosition() {
    invokeFeatureDrag(
        mapLibreMap.getProjection().toScreenLocation(dragPrevious), dragPrevious, "end");
    stopDragging();
  }

  void onMoveEnd(MoveGestureDetector detector) {
    if (draggedFeature == null) {
      // the drag already ended when a second finger came down
      return;
    }
    PointF pointf = detector.getFocalPoint();
    invokeFeatureDrag(pointf, "end");
    stopDragging();
  }

  private static boolean isDraggable(@NonNull Feature feature) {
    return feature.hasNonNullValueForProperty("draggable")
        ? feature.getBooleanProperty("draggable")
        : false;
  }

  boolean startDragging(@NonNull Feature feature, @NonNull LatLng origin) {
    if (isDraggable(feature)) {
      draggedFeature = feature;
      dragPrevious = origin;
      dragOrigin = origin;
      return true;
    }
    return false;
  }

  void stopDragging() {
    draggedFeature = null;
    dragOrigin = null;
    dragPrevious = null;
  }

  private class MoveGestureListener implements MoveGestureDetector.OnMoveGestureListener {

    @Override
    public boolean onMoveBegin(MoveGestureDetector detector) {
      return MapLibreMapController.this.onMoveBegin(detector);
    }

    @Override
    public boolean onMove(MoveGestureDetector detector, float distanceX, float distanceY) {
      return MapLibreMapController.this.onMove(detector);
    }

    @Override
    public void onMoveEnd(MoveGestureDetector detector, float velocityX, float velocityY) {
      MapLibreMapController.this.onMoveEnd(detector);
    }
  }
}
