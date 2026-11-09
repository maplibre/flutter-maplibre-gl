package org.maplibre.maplibregl;

import androidx.annotation.NonNull;
import java.util.List;
import java.util.Map;
import org.maplibre.android.style.layers.CustomLayer;

/**
 * Builds the native renderer of a MeshLayer (src/main/cpp/mesh_layer.cpp) and wraps it in a
 * MapLibre CustomLayer, which owns it from then on.
 */
final class MeshLayerHost {
  static {
    System.loadLibrary("maplibregl_mesh_layer");
  }

  private MeshLayerHost() {}

  /** The layer for the "meshLayer#add" arguments: meshes, instances, light, minzoom, maxzoom. */
  @SuppressWarnings("unchecked")
  static CustomLayer create(@NonNull String layerId, @NonNull Map<String, Object> arguments) {
    final List<Map<String, Object>> meshes = (List<Map<String, Object>>) arguments.get("meshes");
    final int count = meshes == null ? 0 : meshes.size();
    final float[][] positions = new float[count][];
    final float[][] normals = new float[count][];
    final float[][] colors = new float[count][];
    final int[][] indices = new int[count][];
    final boolean[] occluders = new boolean[count];
    for (int i = 0; i < count; i++) {
      final Map<String, Object> mesh = meshes.get(i);
      positions[i] = (float[]) mesh.get("positions");
      normals[i] = (float[]) mesh.get("normals");
      colors[i] = (float[]) mesh.get("colors");
      indices[i] = (int[]) mesh.get("indices");
      occluders[i] = Boolean.TRUE.equals(mesh.get("occluder"));
    }
    final double[] instances = (double[]) arguments.get("instances");
    final float[] light = (float[]) arguments.get("light");
    final Number minZoom = (Number) arguments.get("minzoom");
    final Number maxZoom = (Number) arguments.get("maxzoom");
    final long host =
        nativeCreate(
            positions,
            normals,
            colors,
            indices,
            occluders,
            instances == null ? new double[0] : instances,
            light,
            minZoom == null ? 0 : minZoom.doubleValue(),
            maxZoom == null ? 24 : maxZoom.doubleValue());
    return new CustomLayer(layerId, host);
  }

  private static native long nativeCreate(
      float[][] positions,
      float[][] normals,
      float[][] colors,
      int[][] indices,
      boolean[] occluders,
      double[] instances,
      float[] light,
      double minZoom,
      double maxZoom);
}
