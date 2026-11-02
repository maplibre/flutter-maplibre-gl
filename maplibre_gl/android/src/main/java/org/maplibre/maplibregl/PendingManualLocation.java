package org.maplibre.maplibregl;

import androidx.annotation.Nullable;
import java.util.function.Consumer;

/**
 * Keeps the last manual location while the puck is hidden, so the puck appears there once
 * myLocationEnabled shows it. Only the newest location is kept.
 */
final class PendingManualLocation<T> {
  @Nullable private T pending;

  /** Shows {@code location} if the puck is {@code visible}, and keeps it for later otherwise. */
  void offer(T location, boolean visible, Consumer<T> show) {
    if (visible) {
      pending = null;
      show.accept(location);
    } else {
      pending = location;
    }
  }

  /** Shows the location kept while the puck was hidden, if any. */
  void flush(Consumer<T> show) {
    final T location = pending;
    if (location != null) {
      pending = null;
      show.accept(location);
    }
  }
}
