package org.maplibre.maplibregl;

import android.content.Context;

import androidx.annotation.NonNull;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;

/**
 * Platform-view factory for {@code plugins.flutter.io/maplibre_gl}.
 *
 * <p>Beyond the standard {@link PlatformViewFactory} responsibilities, this class
 * keeps a weak registry of every {@link MapLibreMapController} it has produced so
 * that the plugin can broadcast Flutter {@code ActivityAware} events to all live
 * controllers when the host activity is attached, detached, or recreated.
 *
 * <h2>Thread-safety</h2>
 * The registry is a {@link WeakHashMap} wrapper (not thread-safe), but all
 * accessors ({@link #create}, the broadcast methods, and dispose-driven removals)
 * run on the Flutter platform thread (the Android main thread), so no external
 * synchronization is required. {@link ArrayList} snapshots are taken before
 * iteration to defend against re-entrant mutations (e.g. a controller disposing
 * itself in response to a lifecycle callback).
 */
public class MapLibreMapFactory extends PlatformViewFactory {

  private final BinaryMessenger messenger;
  private final MapLibreMapsPlugin.LifecycleProvider lifecycleProvider;
  /**
   * Weakly-referenced registry of all controllers produced by this factory. Used
   * to fan out activity attach/detach/rebound notifications. Entries vanish
   * automatically when the controller is garbage-collected.
   */
  private final Set<MapLibreMapController> controllers =
      Collections.newSetFromMap(new WeakHashMap<MapLibreMapController, Boolean>());

  public MapLibreMapFactory(
      BinaryMessenger messenger, MapLibreMapsPlugin.LifecycleProvider lifecycleProvider) {
    // Dart encodes the creation params with the codec of the map messages.
    super(MapLibreMapHostApi.Companion.getCodec());
    this.messenger = messenger;
    this.lifecycleProvider = lifecycleProvider;
  }

  @NonNull
  @Override
  public PlatformView create(Context context, int id, Object args) {
    final MapLibreMapBuilder builder = new MapLibreMapBuilder();
    configure(builder, args, context.getResources().getDisplayMetrics().density);

    final MapLibreMapController controller =
        builder.build(id, context, messenger, lifecycleProvider);
    controllers.add(controller);
    return controller;
  }

  /**
   * Hands {@code builder} the creation params of a map, {@code args}, which Dart sends as a {@link
   * PgCreationParams}. The margins in the options become physical pixels at {@code density}.
   *
   * @throws IllegalArgumentException when {@code args} is not a {@link PgCreationParams}.
   */
  static void configure(MapLibreMapBuilder builder, Object args, float density) {
    if (!(args instanceof PgCreationParams)) {
      throw new IllegalArgumentException(
          "The creation params of a map are a PgCreationParams, not " + args + ".");
    }
    final PgCreationParams params = (PgCreationParams) args;
    PigeonConvert.applyMapOptions(params.getOptions(), builder, density);
    final PgCameraPosition initialCameraPosition = params.getInitialCameraPosition();
    if (initialCameraPosition != null) {
      builder.setInitialCameraPosition(PigeonConvert.toCameraPosition(initialCameraPosition));
    }
    builder.setDragEnabled(params.getDragEnabled());
    final String styleString = params.getStyleString();
    if (styleString != null) {
      builder.setStyleString(styleString);
    }
    // Not a map option: how Flutter composes the view, which the map has to know before it builds
    // its MapView, so it is set every time.
    builder.setUseHybridComposition(params.getUseHybridComposition());
  }

  /**
   * Notify every live controller that the plugin has (re)attached to an activity.
   * Triggered from {@link MapLibreMapsPlugin#onAttachedToActivity}.
   */
  void onActivityAttached() {
    for (MapLibreMapController controller : new ArrayList<>(controllers)) {
      controller.onActivityAttached();
    }
  }

  /**
   * Notify every live controller that the plugin is being fully detached from the
   * activity (no config change in progress). Controllers will save what state they
   * can and tear down the native {@link io.flutter.plugin.platform.PlatformView} resources.
   * Triggered from {@link MapLibreMapsPlugin#onDetachedFromActivity}.
   */
  void onActivityDetached() {
    for (MapLibreMapController controller : new ArrayList<>(controllers)) {
      controller.onActivityDetached();
    }
  }

  /**
   * Notify every live controller that the host activity has been swapped due to a
   * configuration change (e.g. rotation). In Flutter's standard ordering the old
   * activity has already destroyed each controller's map view by the time this
   * fires; controllers will recreate the {@link io.flutter.plugin.platform.PlatformView}
   * against the fresh activity context. Triggered from
   * {@link MapLibreMapsPlugin#onReattachedToActivityForConfigChanges}.
   */
  void onActivityRebound() {
    for (MapLibreMapController controller : new ArrayList<>(controllers)) {
      controller.onActivityRebound();
    }
  }
}
