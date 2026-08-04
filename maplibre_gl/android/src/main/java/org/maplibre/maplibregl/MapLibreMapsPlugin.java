// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package org.maplibre.maplibregl;

import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.lifecycle.Lifecycle;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.lifecycle.HiddenLifecycleReference;
import io.flutter.plugin.common.MethodChannel;
import org.maplibre.android.log.Logger;

/**
 * Plugin for controlling a set of MapLibreMap views to be shown as overlays on top of the Flutter
 * view. The overlay should be hidden during transformations or while Flutter is rendering on top of
 * the map. A Texture drawn using MapLibreMap bitmap snapshots can then be shown instead of the
 * overlay.
 */
public class MapLibreMapsPlugin implements FlutterPlugin, ActivityAware {

  static FlutterAssets flutterAssets;
  private Lifecycle lifecycle;
  private Context context;
  private MapLibreMapFactory mapFactory;

  public MapLibreMapsPlugin() {
    // no-op
  }

  // New Plugin APIs

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    flutterAssets = binding.getFlutterAssets();

    // Reduce MapLibre SDK logging verbosity to prevent spam from HTTP requests
    // INFO level includes informational messages, warnings, and errors while suppressing verbose HTTP logs
    Logger.setVerbosity(Logger.INFO);

    MethodChannel methodChannel =
        new MethodChannel(binding.getBinaryMessenger(), "plugins.flutter.io/maplibre_gl");
    methodChannel.setMethodCallHandler(new GlobalMethodHandler(binding));

    binding
        .getPlatformViewRegistry()
        .registerViewFactory(
            "plugins.flutter.io/maplibre_gl",
            mapFactory =
                new MapLibreMapFactory(
                    binding.getBinaryMessenger(),
                    new LifecycleProvider() {
                      @Nullable
                      @Override
                      public Lifecycle getLifecycle() {
                        return lifecycle;
                      }

                      @Nullable
                      @Override
                      public Context getContext() {
                        return context;
                      }
                    }));
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    // no-op
  }

  /**
   * Called by Flutter when the plugin is attached to a host {@link android.app.Activity}.
   * Fires on first launch and after the activity has been recreated (e.g. with
   * "Don't keep activities"). Refreshes the lifecycle/context references exposed
   * via {@link LifecycleProvider} and notifies live controllers so they can
   * rebuild their {@link org.maplibre.android.maps.MapView} against the new
   * activity context.
   */
  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    context = binding.getActivity();
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding);
    if (mapFactory != null) {
      mapFactory.onActivityAttached();
    }
  }

  /**
   * Called by Flutter when the host activity is about to be destroyed and recreated
   * for a configuration change (e.g. rotation). We deliberately do NOT broadcast a
   * detach to controllers here: the new activity will arrive shortly via
   * {@link #onReattachedToActivityForConfigChanges} and the controllers will rebuild
   * then. The old activity's natural {@code Lifecycle.onDestroy} will still tear
   * down the {@code MapView}; persisted state (camera + MapLibre instance state)
   * is carried across by the controller itself.
   */
  @Override
  public void onDetachedFromActivityForConfigChanges() {
    lifecycle = null;
    context = null;
  }

  /**
   * Called by Flutter after a configuration-change-driven activity recreation has
   * produced a new {@link android.app.Activity}. Refreshes lifecycle/context and
   * fans out a rebound notification to controllers, which rebuild their
   * {@code MapView} against the new activity and restore camera + MapLibre state.
   */
  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    context = binding.getActivity();
    lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding);
    if (mapFactory != null) {
      mapFactory.onActivityRebound();
    }
  }

  /**
   * Called by Flutter when the plugin is being fully detached from the host
   * activity (no config change is in progress — e.g. "Don't keep activities" has
   * been triggered, or the activity is finishing). Notifies controllers to save
   * what state they can and tear down their {@code MapView}. The state is held
   * in the controllers themselves and will be restored on the next attach.
   */
  @Override
  public void onDetachedFromActivity() {
    if (mapFactory != null) {
      mapFactory.onActivityDetached();
    }
    lifecycle = null;
    context = null;
  }


  /**
   * Late-binding accessor for the host activity {@link Lifecycle} and {@link Context}.
   *
   * <p>The plugin instance returned by {@link io.flutter.embedding.engine.plugins.activity.ActivityAware}
   * callbacks can outlive any single activity, so controllers must NOT cache these
   * values across activity recreation — they should fetch them through this provider
   * whenever they (re)attach. Both methods return {@code null} when the plugin is
   * not currently attached to an activity.
   */
  interface LifecycleProvider {
    @Nullable
    Lifecycle getLifecycle();

    @Nullable
    Context getContext();
  }

  /** Provides a static method for extracting lifecycle objects from Flutter plugin bindings. */
  public static class FlutterLifecycleAdapter {

    /**
     * Returns the lifecycle object for the activity a plugin is bound to.
     *
     * <p>Returns null if the Flutter engine version does not include the lifecycle extraction code.
     * (this probably means the Flutter engine version is too old).
     */
    @NonNull
    public static Lifecycle getActivityLifecycle(
        @NonNull ActivityPluginBinding activityPluginBinding) {
      HiddenLifecycleReference reference =
          (HiddenLifecycleReference) activityPluginBinding.getLifecycle();
      return reference.getLifecycle();
    }
  }
}
