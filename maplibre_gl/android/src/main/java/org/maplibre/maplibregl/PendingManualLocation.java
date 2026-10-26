package org.maplibre.maplibregl;

import androidx.annotation.Nullable;

/**
 * Keeps the last manual location while the puck is hidden, so the puck appears there once
 * myLocationEnabled shows it. Only the newest location is kept.
 */
final class PendingManualLocation<T> {
  /** Shows a location. Not java.util.function.Consumer, which needs API 24. */
  interface Show<T> {
    void show(T location);
  }

  @Nullable private T pending;

  /** Shows {@code location} if the puck is {@code visible}, and keeps it for later otherwise. */
  void offer(T location, boolean visible, Show<T> show) {
    if (visible) {
      pending = null;
      show.show(location);
    } else {
      pending = location;
    }
  }

  /** Shows the location kept while the puck was hidden, if any. */
  void flush(Show<T> show) {
    final T location = pending;
    if (location != null) {
      pending = null;
      show.show(location);
    }
  }
}
