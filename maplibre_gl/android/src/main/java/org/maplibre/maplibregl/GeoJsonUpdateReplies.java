package org.maplibre.maplibregl;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Holds the reply to each GeoJSON data change until the engine applies the data.
 *
 * <p>{@code GeoJsonSource.setGeoJson} converts the data on a background thread and applies it
 * later on the main thread. The map then sends {@code onSourceChanged} for the source. A reply
 * sent before that lets the app see an idle map that still shows the old data.
 *
 * <p>The engine converts one change of a source at a time. The changes that come while a
 * conversion runs wait, and the engine keeps only the last of them: when the conversion ends, it
 * applies that data and then converts the last waiting change. This class follows the same rule.
 * The replies to the waiting changes go when the engine applies the last of them.
 *
 * <p>Each reply runs at most once. The caller must also run it after a timeout, because the
 * engine sends no event for data it cannot read.
 */
final class GeoJsonUpdateReplies {
  private static final class SourceState {
    boolean converting;
    boolean waiting;
    List<Runnable> forConversion = new ArrayList<>();
    List<Runnable> forWaiting = new ArrayList<>();
  }

  private final Map<String, SourceState> sources = new HashMap<>();

  /** Holds {@code reply} for the data change that the caller just gave the engine. */
  void add(String sourceId, Runnable reply) {
    SourceState state = sources.get(sourceId);
    if (state == null) {
      state = new SourceState();
      sources.put(sourceId, state);
    }
    if (state.converting) {
      state.waiting = true;
      state.forWaiting.add(reply);
    } else {
      state.converting = true;
      state.forConversion.add(reply);
    }
  }

  /** The engine applied data to {@code sourceId}: runs the replies of that data. */
  void applied(String sourceId) {
    final SourceState state = sources.get(sourceId);
    if (state == null) {
      return;
    }
    final List<Runnable> replies = state.forConversion;
    state.forConversion = state.forWaiting;
    state.forWaiting = new ArrayList<>();
    state.converting = state.waiting;
    state.waiting = false;
    if (!state.converting) {
      sources.remove(sourceId);
    }
    runAll(replies);
  }

  /**
   * Runs every reply of {@code sourceId} now, and forgets the source. For a source that the
   * engine no longer has: it never applies the data, so it sends no event.
   */
  void release(String sourceId) {
    final SourceState state = sources.remove(sourceId);
    if (state != null) {
      runAll(state.forConversion);
      runAll(state.forWaiting);
    }
  }

  /** Runs every reply now, and forgets all sources. For a style or map that is gone. */
  void releaseAll() {
    final List<String> ids = new ArrayList<>(sources.keySet());
    for (String id : ids) {
      release(id);
    }
  }

  /** Whether a reply of {@code sourceId} waits. */
  boolean isWaiting(String sourceId) {
    return sources.containsKey(sourceId);
  }

  private static void runAll(List<Runnable> replies) {
    for (Runnable reply : replies) {
      reply.run();
    }
  }
}
