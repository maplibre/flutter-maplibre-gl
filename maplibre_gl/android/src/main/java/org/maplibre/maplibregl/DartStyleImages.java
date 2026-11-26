package org.maplibre.maplibregl;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/** Images supplied by Dart belong to the current style, rather than to individual tiles. */
final class DartStyleImages {
  private final Set<String> registered = ConcurrentHashMap.newKeySet();

  /** Returns whether this call introduced the registration, for failed-add rollback. */
  boolean register(String imageId) {
    return registered.add(imageId);
  }

  boolean canRemoveUnused(String imageId) {
    return !registered.contains(imageId);
  }

  void unregister(String imageId) {
    registered.remove(imageId);
  }

  void clear() {
    registered.clear();
  }
}
