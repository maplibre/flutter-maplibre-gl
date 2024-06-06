package org.maplibre.maplibregl;

import android.content.Context;

import androidx.annotation.NonNull;

import org.maplibre.android.camera.CameraPosition;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.StandardMessageCodec;
import io.flutter.plugin.platform.PlatformView;
import io.flutter.plugin.platform.PlatformViewFactory;
import java.util.Map;

public class MapLibreMapFactory extends PlatformViewFactory {

  private final BinaryMessenger messenger;
  private final MapLibreMapsPlugin.LifecycleProvider lifecycleProvider;

  public MapLibreMapFactory(
      BinaryMessenger messenger, MapLibreMapsPlugin.LifecycleProvider lifecycleProvider) {
    super(StandardMessageCodec.INSTANCE);
    this.messenger = messenger;
    this.lifecycleProvider = lifecycleProvider;
  }

  @NonNull
  @Override
  public PlatformView create(Context context, int id, Object args) {
    Map<String, Object> params = (Map<String, Object>) args;
    final MapLibreMapBuilder builder = new MapLibreMapBuilder();

    Convert.interpretMapLibreMapOptions(params.get("options"), builder, context);
    if (params.containsKey("initialCameraPosition")) {
      CameraPosition position = Convert.toCameraPosition(params.get("initialCameraPosition"));
      builder.setInitialCameraPosition(position);
    }
    if (params.containsKey("dragEnabled")) {
      boolean dragEnabled = Convert.toBoolean(params.get("dragEnabled"));
      builder.setDragEnabled(dragEnabled);
    }
    if(params.containsKey("styleString")) {
      String styleString = Convert.toString(params.get("styleString"));
      builder.setStyleString(styleString);
    }

    return builder.build(id, context, messenger, lifecycleProvider);
  }
}
