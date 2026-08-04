package org.maplibre.maplibregl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import org.maplibre.android.maps.MapView;

/**
 * Per-frame render statistics collection (benchmark instrumentation).
 *
 * <p>Wraps a {@link MapView.OnDidFinishRenderingFrameListener} and buffers, for every rendered
 * frame, its timestamp plus the CPU encoding/rendering times reported by the map renderer. The SDK
 * invokes render listeners on the UI thread and the method channel drains on the same thread, so no
 * synchronization is needed.
 */
final class FrameStatsRecorder {

  private boolean enabled = false;
  private long startNs = 0;
  private final ArrayList<Long> timestampsUs = new ArrayList<>();
  private final ArrayList<Double> encodingMs = new ArrayList<>();
  private final ArrayList<Double> renderingMs = new ArrayList<>();

  // Encoding/rendering times arrive in seconds (RenderingStats) and are stored as milliseconds.
  private final MapView.OnDidFinishRenderingFrameListener listener =
      (fully, frameEncodingTime, frameRenderingTime) -> {
        if (!enabled) {
          return;
        }
        timestampsUs.add((System.nanoTime() - startNs) / 1000);
        encodingMs.add(frameEncodingTime * 1e3);
        renderingMs.add(frameRenderingTime * 1e3);
      };

  /** Starts or stops collecting; either way the sample buffers are reset. */
  void setEnabled(MapView mapView, boolean newEnabled) {
    timestampsUs.clear();
    encodingMs.clear();
    renderingMs.clear();
    startNs = System.nanoTime();
    if (newEnabled == enabled || mapView == null) {
      return;
    }
    enabled = newEnabled;
    if (newEnabled) {
      mapView.addOnDidFinishRenderingFrameListener(listener);
    } else {
      mapView.removeOnDidFinishRenderingFrameListener(listener);
    }
  }

  /** Drains the collected samples (without stopping the collection). */
  Map<String, Object> take() {
    final int count = timestampsUs.size();
    final long[] outTimestampsUs = new long[count];
    final double[] outEncodingMs = new double[count];
    final double[] outRenderingMs = new double[count];
    for (int i = 0; i < count; i++) {
      outTimestampsUs[i] = timestampsUs.get(i);
      outEncodingMs[i] = encodingMs.get(i);
      outRenderingMs[i] = renderingMs.get(i);
    }
    timestampsUs.clear();
    encodingMs.clear();
    renderingMs.clear();
    final Map<String, Object> reply = new HashMap<>();
    reply.put("clockUs", enabled ? (System.nanoTime() - startNs) / 1000 : 0L);
    reply.put("timestampsUs", outTimestampsUs);
    reply.put("encodingMs", outEncodingMs);
    reply.put("renderingMs", outRenderingMs);
    return reply;
  }

  /** Detaches the listener on controller teardown. */
  void dispose(MapView mapView) {
    if (enabled && mapView != null) {
      mapView.removeOnDidFinishRenderingFrameListener(listener);
    }
    enabled = false;
  }
}
