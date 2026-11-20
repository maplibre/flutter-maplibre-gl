package org.maplibre.maplibregl;

import androidx.annotation.NonNull;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.List;
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

  /**
   * The layer for the styleAddMeshLayer arguments, see pigeons/messages.dart.
   *
   * @throws IllegalArgumentException when a mesh or an instance does not have the shape the
   *     message describes.
   */
  static CustomLayer create(
      @NonNull String layerId,
      @NonNull List<PgMeshLayerMesh> meshes,
      @NonNull double[] instances,
      @NonNull double[] light,
      double minZoom,
      double maxZoom) {
    final int count = meshes.size();
    final float[][] positions = new float[count][];
    final float[][] normals = new float[count][];
    final float[][] colors = new float[count][];
    final int[][] indices = new int[count][];
    final boolean[] occluders = new boolean[count];
    for (int i = 0; i < count; i++) {
      final PgMeshLayerMesh mesh = meshes.get(i);
      positions[i] = floats(mesh.getPositions());
      normals[i] = floats(mesh.getNormals());
      colors[i] = floats(mesh.getColors());
      indices[i] = mesh.getIndices();
      occluders[i] = mesh.getOccluder();
      final int vertexCount = positions[i].length / 3;
      if (positions[i].length % 3 != 0
          || normals[i].length != positions[i].length
          || colors[i].length != vertexCount * 4
          || indices[i].length % 3 != 0) {
        throw new IllegalArgumentException(
            "Mesh " + i + ": positions, normals, colors or indices do not match");
      }
      for (int index : indices[i]) {
        if (index < 0 || index >= vertexCount) {
          throw new IllegalArgumentException("Mesh " + i + ": index " + index + " out of range");
        }
      }
    }
    if (instances.length % 6 != 0) {
      throw new IllegalArgumentException("Instances: six values per instance");
    }
    for (int i = 0; i < instances.length; i += 6) {
      if (instances[i] < 0 || instances[i] >= count) {
        throw new IllegalArgumentException("Instance " + i / 6 + ": no mesh " + instances[i]);
      }
    }
    if (light.length != 14) {
      throw new IllegalArgumentException("Light: 14 values");
    }
    final float[] lightValues = new float[14];
    for (int i = 0; i < 14; i++) {
      lightValues[i] = (float) light[i];
    }
    final long host =
        nativeCreate(
            positions, normals, colors, indices, occluders, instances, lightValues, minZoom,
            maxZoom);
    return new CustomLayer(layerId, host);
  }

  /** The 32-bit floats in [bytes], in the byte order of the device as Dart sends them. */
  private static float[] floats(byte[] bytes) {
    if (bytes.length % 4 != 0) {
      throw new IllegalArgumentException("Float data of " + bytes.length + " bytes");
    }
    final float[] values = new float[bytes.length / 4];
    ByteBuffer.wrap(bytes).order(ByteOrder.nativeOrder()).asFloatBuffer().get(values);
    return values;
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
