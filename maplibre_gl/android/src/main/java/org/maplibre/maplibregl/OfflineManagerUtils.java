package org.maplibre.maplibregl;

import android.content.Context;
import android.os.SystemClock;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.google.gson.Gson;
import org.maplibre.android.geometry.LatLng;
import org.maplibre.android.geometry.LatLngBounds;
import org.maplibre.android.offline.OfflineManager;
import org.maplibre.android.offline.OfflineRegion;
import org.maplibre.android.offline.OfflineRegionDefinition;
import org.maplibre.android.offline.OfflineRegionError;
import org.maplibre.android.offline.OfflineRegionStatus;
import org.maplibre.android.offline.OfflineTilePyramidRegionDefinition;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicBoolean;

abstract class OfflineManagerUtils {
  private static final String TAG = "OfflineManagerUtils";

  // The error codes of the offline calls and download events, shared with iOS.
  private static final String REGION_NOT_FOUND = "REGION_NOT_FOUND";
  private static final String OFFLINE_DATABASE_ERROR = "OFFLINE_DATABASE_ERROR";
  private static final String AMBIENT_CACHE_ERROR = "AMBIENT_CACHE_ERROR";
  private static final String INVALID_REGION_DEFINITION = "INVALID_REGION_DEFINITION";
  private static final String TILE_COUNT_LIMIT_EXCEEDED = "TILE_COUNT_LIMIT_EXCEEDED";
  private static final String REGION_DELETED = "REGION_DELETED";
  private static final String REGION_REPLACED = "REGION_REPLACED";
  private static final String DATABASE_RESET = "DATABASE_RESET";
  private static final String INVALID_ARGUMENT = "INVALID_ARGUMENT";

  /**
   * Minimum interval between progress events forwarded to Dart. When tiles are
   * served from the local MapLibre cache (e.g. a previously downloaded region
   * was deleted and re-downloaded), the SDK can emit ~1000 status updates per
   * second, flooding the Dart isolate and starving user input (pause/resume
   * taps). Terminal events (completion, error) are always emitted regardless
   * of this throttle.
   */
  private static final long PROGRESS_EMIT_MIN_INTERVAL_MS = 100L;

  /**
   * Holds the state needed to observe and control an in-progress download.
   * {@code channelHandler} is null for a region resumed by resumeUntracked,
   * which nothing on the Dart side listens to.
   */
  static class ActiveDownload {
    final OfflineRegion region;
    @Nullable final OfflineDownloadEvents channelHandler;
    final AtomicBoolean isComplete;
    long lastProgressEmitMs;
    long lastEmittedCompletedCount;

    ActiveDownload(
        OfflineRegion region,
        @Nullable OfflineDownloadEvents channelHandler,
        AtomicBoolean isComplete) {
      this.region = region;
      this.channelHandler = channelHandler;
      this.isComplete = isComplete;
      this.lastProgressEmitMs = 0L;
      this.lastEmittedCompletedCount = -1L;
    }
  }

  static final Map<Long, ActiveDownload> activeDownloads = new HashMap<>();

  /**
   * The regions a resume is looking up, before it starts them. A pause in the meantime takes the
   * region out, so the resume answers without starting a download the pause already stopped.
   * Calls and SDK callbacks all run on the main thread, in the order they arrive.
   */
  static final Set<Long> pendingResumes = new HashSet<>();

  static void mergeRegions(MethodChannel.Result result, Context context, String path) {
    OfflineManager.Companion.getInstance(context)
        .mergeOfflineRegions(
            path,
            new OfflineManager.MergeOfflineRegionsCallback() {
              public void onMerge(OfflineRegion[] offlineRegions) {
                if (result == null) return;
                guard(result, () -> result.success(regionsToJson(offlineRegions)));
              }

              public void onError(String error) {
                if (result == null) return;
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  static void setOfflineTileCountLimit(MethodChannel.Result result, Context context, long limit) {
    OfflineManager.Companion.getInstance(context).setOfflineMapboxTileCountLimit(limit);
    result.success(null);
  }

  static void clearAmbientCache(MethodChannel.Result result, Context context) {
    OfflineManager.Companion.getInstance(context)
        .clearAmbientCache(
            new OfflineManager.FileSourceCallback() {
              @Override
              public void onSuccess() {
                result.success(null);
              }

              @Override
              public void onError(@NonNull String message) {
                result.error(AMBIENT_CACHE_ERROR, message, null);
              }
            });
  }

  static void setMaximumAmbientCacheSize(
      MethodChannel.Result result, Context context, long bytes) {
    OfflineManager.Companion.getInstance(context)
        .setMaximumAmbientCacheSize(
            bytes,
            new OfflineManager.FileSourceCallback() {
              @Override
              public void onSuccess() {
                result.success(null);
              }

              @Override
              public void onError(@NonNull String message) {
                result.error(AMBIENT_CACHE_ERROR, message, null);
              }
            });
  }

  static void resetOfflineDatabase(MethodChannel.Result result, Context context) {
    // Any tracked in-progress downloads are invalidated by the reset.
    for (ActiveDownload ad : activeDownloads.values()) {
      ad.isComplete.set(true);
      try {
        ad.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
      } catch (Throwable ignored) {
        // Region may already be invalid; ignore.
      }
      // Terminate the in-flight download on the Dart side so its stream
      // subscription is cleaned up and the awaiting Future resolves.
      if (ad.channelHandler != null) {
        ad.channelHandler.onError(
            DATABASE_RESET,
            "Offline database was reset before the download completed",
            null);
      }
    }
    activeDownloads.clear();
    pendingResumes.clear();

    OfflineManager.Companion.getInstance(context)
        .resetDatabase(
            new OfflineManager.FileSourceCallback() {
              @Override
              public void onSuccess() {
                result.success(null);
              }

              @Override
              public void onError(@NonNull String message) {
                result.error(OFFLINE_DATABASE_ERROR, message, null);
              }
            });
  }

  /**
   * Creates and sets an {@link OfflineRegion.OfflineRegionObserver} on the given region.
   * The observer forwards progress, completion, and error events to the channel handler,
   * when there is one, and stops the download once it completes either way.
   */
  private static void setObserverOnRegion(
      OfflineRegion region, @Nullable OfflineDownloadEvents channelHandler,
      AtomicBoolean isComplete, Context context) {
    OfflineRegion.OfflineRegionObserver observer =
        new OfflineRegion.OfflineRegionObserver() {
          @Override
          public void onStatusChanged(OfflineRegionStatus status) {
            double progress =
                calculateDownloadingProgress(
                    status.getRequiredResourceCount(),
                    status.getCompletedResourceCount());
            if (status.isComplete()) {
              if (isComplete.get()) return;
              isComplete.set(true);
              region.setDownloadState(OfflineRegion.STATE_INACTIVE);
              activeDownloads.remove(region.getId());
              if (channelHandler != null) {
                channelHandler.onSuccess();
              }
              return;
            }
            if (channelHandler == null) {
              return;
            }
            // Throttle: when tiles come from cache, the SDK fires hundreds of
            // updates per second and floods the Dart isolate, preventing user
            // input (pause taps) from being processed in a timely manner.
            ActiveDownload ad = activeDownloads.get(region.getId());
            long now = SystemClock.uptimeMillis();
            if (ad != null
                && ad.lastProgressEmitMs != 0L
                && now - ad.lastProgressEmitMs < PROGRESS_EMIT_MIN_INTERVAL_MS) {
              return;
            }
            // Drop non-monotonic counts. After pause/resume the SDK may fire
            // a transient onStatusChanged with a stale zero count before it
            // reconciles, which would otherwise make the UI flash back to 0%.
            long completed = status.getCompletedResourceCount();
            if (ad != null
                && ad.lastEmittedCompletedCount >= 0L
                && completed < ad.lastEmittedCompletedCount) {
              return;
            }
            if (ad != null) {
              ad.lastProgressEmitMs = now;
              ad.lastEmittedCompletedCount = completed;
            }
            channelHandler.onProgress(
                progress,
                status.getCompletedResourceCount(),
                status.getRequiredResourceCount(),
                status.getCompletedResourceSize());
          }

          @Override
          public void onError(OfflineRegionError error) {
            // Recoverable: the SDK re-requests what failed once the network is
            // back, so this only reports and the download stays active. Ending
            // it here would lose the whole download to any brief outage.
            // Only the tile count limit below is terminal.
            Log.w(
                TAG,
                "offline download error, the SDK will retry (reason "
                    + error.getReason()
                    + "): "
                    + error.getMessage());
          }

          @Override
          public void mapboxTileCountLimitExceeded(long limit) {
            Log.e(TAG, "MapLibre tile count limit exceeded: " + limit);
            region.setDownloadState(OfflineRegion.STATE_INACTIVE);
            activeDownloads.remove(region.getId());
            isComplete.set(true);
            // A region nobody listens to stops but is kept, as iOS keeps its pack.
            if (channelHandler == null) {
              return;
            }
            channelHandler.onError(
                TILE_COUNT_LIMIT_EXCEEDED,
                "MapLibre tile count limit exceeded: " + limit,
                null);
            deleteRegion(null, context, region.getId());
          }
        };
    region.setObserver(observer);
  }

  static void downloadRegion(
      MethodChannel.Result result,
      Context context,
      Map<String, Object> definitionMap,
      Map<String, Object> metadataMap,
      OfflineDownloadEvents channelHandler) {
    float pixelDensity = context.getResources().getDisplayMetrics().density;
    final OfflineRegionDefinition definition;
    try {
      definition = mapToRegionDefinition(definitionMap, pixelDensity);
    } catch (RuntimeException e) {
      // A key is missing or has the wrong type.
      result.error(
          INVALID_REGION_DEFINITION,
          "The region definition needs bounds, mapStyleUrl, minZoom and maxZoom.",
          null);
      return;
    }
    final String metadata = metadataToJson(metadataMap, result);
    if (metadata == null) {
      return;
    }
    // Downloading the same area twice would otherwise create a second, duplicate
    // region (createOfflineRegion does not deduplicate). Remove any existing
    // region covering the same area first, then create, so a re-download replaces
    // it rather than piling up.
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> {
                  OfflineRegion duplicate = findRegionMatching(offlineRegions, definition);
                  if (duplicate == null) {
                    createRegion(result, context, definition, metadata, channelHandler);
                    return;
                  }
                  // Tear down any in-flight download tracked for the region we're
                  // about to replace, so we don't leak its activeDownloads entry
                  // or leave its Dart subscription waiting forever.
                  releaseDuplicateDownload(duplicate.getId());
                  duplicate.delete(
                      new OfflineRegion.OfflineRegionDeleteCallback() {
                        @Override
                        public void onDelete() {
                          guard(result, () ->
                              createRegion(result, context, definition, metadata, channelHandler));
                        }

                        @Override
                        public void onError(String error) {
                          // Fall back to creating anyway; a stale duplicate is
                          // better than failing the whole download.
                          Log.e(TAG, "Failed to remove duplicate region: " + error);
                          guard(result, () ->
                              createRegion(result, context, definition, metadata, channelHandler));
                        }
                      });
                });
              }

              @Override
              public void onError(String error) {
                // If we can't list regions, still attempt the download.
                Log.e(TAG, "Failed to list regions for dedup: " + error);
                guard(result, () ->
                    createRegion(result, context, definition, metadata, channelHandler));
              }
            });
  }

  /// Compares an existing region's definition against a new one by area
  /// (style, bounds, zoom range and ideograph setting), returning the first
  /// match, if any.
  private static OfflineRegion findRegionMatching(
      OfflineRegion[] regions, OfflineRegionDefinition definition) {
    for (OfflineRegion region : regions) {
      OfflineRegionDefinition existing = region.getDefinition();
      LatLngBounds a = existing.getBounds();
      LatLngBounds b = definition.getBounds();
      boolean sameArea =
          existing.getStyleURL().equals(definition.getStyleURL())
              // A different ideograph setting means different downloaded font
              // data, so the region is not an equivalent duplicate.
              && existing.getIncludeIdeographs() == definition.getIncludeIdeographs()
              && close(existing.getMinZoom(), definition.getMinZoom())
              && close(existing.getMaxZoom(), definition.getMaxZoom())
              && close(a.getLatNorth(), b.getLatNorth())
              && close(a.getLatSouth(), b.getLatSouth())
              && close(a.getLonEast(), b.getLonEast())
              && close(a.getLonWest(), b.getLonWest());
      if (sameArea) {
        return region;
      }
    }
    return null;
  }

  // Coordinates and zoom levels round-trip through JSON as doubles, so compare
  // with a small tolerance rather than requiring exact equality (matching iOS).
  private static boolean close(double a, double b) {
    return Math.abs(a - b) < 1e-9;
  }

  /// Clears any in-flight download tracked for a region that is about to be
  /// replaced by a re-download of the same area, terminating its Dart
  /// subscription so the awaiting Future resolves and no state is leaked.
  private static void releaseDuplicateDownload(long id) {
    ActiveDownload active = activeDownloads.remove(id);
    if (active != null) {
      active.isComplete.set(true);
      active.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
      if (active.channelHandler != null) {
        active.channelHandler.onError(
            REGION_REPLACED,
            "Region was replaced by a new download of the same area",
            null);
      }
    }
  }

  private static void createRegion(
      MethodChannel.Result result,
      Context context,
      OfflineRegionDefinition definition,
      String metadata,
      OfflineDownloadEvents channelHandler) {
    AtomicBoolean isComplete = new AtomicBoolean(false);
    // Download region
    OfflineManager.Companion.getInstance(context)
        .createOfflineRegion(
            definition,
            metadata.getBytes(),
            new OfflineManager.CreateOfflineRegionCallback() {
              private OfflineRegion _offlineRegion;

              @Override
              public void onCreate(OfflineRegion offlineRegion) {
                _offlineRegion = offlineRegion;
                guard(result, () -> {
                  // Track BEFORE result.success so the Dart side can't race us by
                  // invoking pause/resume before this region is registered.
                  activeDownloads.put(offlineRegion.getId(),
                      new ActiveDownload(offlineRegion, channelHandler, isComplete));
                  setObserverOnRegion(offlineRegion, channelHandler, isComplete, context);
                  _offlineRegion.setDownloadState(OfflineRegion.STATE_ACTIVE);

                  Map<String, Object> regionData = offlineRegionToMap(offlineRegion);
                  result.success(new Gson().toJson(regionData));
                  channelHandler.onStart();
                });
              }

              @Override
              public void onError(String error) {
                Log.e(TAG, "Error: " + error);
                // onError can fire before onCreate, leaving _offlineRegion null.
                if (_offlineRegion != null) {
                  _offlineRegion.setDownloadState(OfflineRegion.STATE_INACTIVE);
                }
                channelHandler.onError(INVALID_REGION_DEFINITION, error, null);
                result.error(INVALID_REGION_DEFINITION, error, null);
              }
            });
  }

  static void regionsList(MethodChannel.Result result, Context context) {
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> result.success(regionsToJson(offlineRegions)));
              }

              @Override
              public void onError(String error) {
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  static void updateRegionMetadata(
      MethodChannel.Result result, Context context, long id, Map<String, Object> metadataMap) {
    final String metadata = metadataToJson(metadataMap, result);
    if (metadata == null) {
      return;
    }
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> updateMetadata(result, offlineRegions, id, metadata));
              }

              @Override
              public void onError(String error) {
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  private static void updateMetadata(
      MethodChannel.Result result, OfflineRegion[] offlineRegions, long id, String metadata) {
    for (OfflineRegion offlineRegion : offlineRegions) {
      if (offlineRegion.getId() != id) continue;

      offlineRegion.updateMetadata(
          metadata.getBytes(),
          new OfflineRegion.OfflineRegionUpdateMetadataCallback() {
            @Override
            public void onUpdate(byte[] metadataBytes) {
              guard(result, () -> {
                Map<String, Object> regionData = offlineRegionToMap(offlineRegion);
                regionData.put("metadata", metadataBytesToMap(metadataBytes));
                result.success(new Gson().toJson(regionData));
              });
            }

            @Override
            public void onError(String error) {
              result.error(OFFLINE_DATABASE_ERROR, error, null);
            }
          });
      return;
    }
    regionNotFound(result, id);
  }

  static void deleteRegion(MethodChannel.Result result, Context context, long id) {
    pendingResumes.remove(id);
    ActiveDownload active = activeDownloads.remove(id);
    if (active != null) {
      active.isComplete.set(true);
      active.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
      // Terminate the in-flight download on the Dart side so its stream
      // subscription is cleaned up and the awaiting Future resolves.
      if (active.channelHandler != null) {
        active.channelHandler.onError(
            REGION_DELETED,
            "Region was deleted before the download completed",
            null);
      }
    }
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> deleteListed(result, offlineRegions, id));
              }

              @Override
              public void onError(String error) {
                if (result == null) return;
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  private static void deleteListed(
      @Nullable MethodChannel.Result result, OfflineRegion[] offlineRegions, long id) {
    for (OfflineRegion offlineRegion : offlineRegions) {
      if (offlineRegion.getId() != id) continue;

      offlineRegion.delete(
          new OfflineRegion.OfflineRegionDeleteCallback() {
            @Override
            public void onDelete() {
              if (result == null) return;
              result.success(null);
            }

            @Override
            public void onError(String error) {
              if (result == null) return;
              result.error(OFFLINE_DATABASE_ERROR, error, null);
            }
          });
      return;
    }
    if (result == null) return;
    regionNotFound(result, id);
  }

  // Pause / Resume / Status

  static void pauseRegion(MethodChannel.Result result, Context context, long id) {
    ActiveDownload download = activeDownloads.get(id);
    if (download != null) {
      download.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
      result.success(null);
    } else {
      // A resume still looking the region up must not start it after this pause.
      pendingResumes.remove(id);
      findRegionById(context, id, result, foundRegion -> {
        foundRegion.setDownloadState(OfflineRegion.STATE_INACTIVE);
        result.success(null);
      });
    }
  }

  static void resumeRegion(MethodChannel.Result result, Context context, long id) {
    ActiveDownload download = activeDownloads.get(id);
    if (download != null) {
      // Deliver status messages even while inactive so the state-change
      // callback fires after STATE_ACTIVE: some paths rely on this to
      // re-arm internal tile dispatching.
      download.region.setDeliverInactiveMessages(true);
      // Re-set the observer to ensure callbacks fire after resume
      setObserverOnRegion(download.region, download.channelHandler, download.isComplete, context);
      download.region.setDownloadState(OfflineRegion.STATE_ACTIVE);
      result.success(null);
    } else {
      // No download of this session follows the region: it was paused before
      // the app restarted, merged in, or its download ended.
      pendingResumes.add(id);
      findRegionById(
          context,
          id,
          new ForwardingResult(result) {
            @Override
            public void error(String code, @Nullable String message, @Nullable Object details) {
              pendingResumes.remove(id);
              super.error(code, message, details);
            }
          },
          foundRegion -> resumeUntracked(result, context, foundRegion));
    }
  }

  /**
   * Resumes a region no download of this session follows. As on iOS, it sends
   * no download events: getOfflineRegionStatus reports its progress. It is
   * tracked so that pause, status and delete reach the region object that
   * downloads. A complete region is left as it is.
   */
  private static void resumeUntracked(
      MethodChannel.Result result, Context context, OfflineRegion region) {
    region.getStatus(
        new OfflineRegion.OfflineRegionStatusCallback() {
          @Override
          public void onStatus(OfflineRegionStatus status) {
            guard(result, () -> {
              // Paused while this resume looked the region up, complete, or already
              // started by another resume meanwhile.
              final boolean stillWanted = pendingResumes.remove(region.getId());
              if (!stillWanted
                  || status.isComplete()
                  || activeDownloads.containsKey(region.getId())) {
                result.success(null);
                return;
              }
              AtomicBoolean isComplete = new AtomicBoolean(false);
              activeDownloads.put(region.getId(), new ActiveDownload(region, null, isComplete));
              setObserverOnRegion(region, null, isComplete, context);
              region.setDownloadState(OfflineRegion.STATE_ACTIVE);
              result.success(null);
            });
          }

          @Override
          public void onError(String error) {
            pendingResumes.remove(region.getId());
            result.error(OFFLINE_DATABASE_ERROR, error, null);
          }
        });
  }

  /** Passes every answer on to {@code target}, for a subclass to see them first. */
  private static class ForwardingResult implements MethodChannel.Result {
    private final MethodChannel.Result target;

    ForwardingResult(MethodChannel.Result target) {
      this.target = target;
    }

    @Override
    public void success(@Nullable Object value) {
      target.success(value);
    }

    @Override
    public void error(String code, @Nullable String message, @Nullable Object details) {
      target.error(code, message, details);
    }

    @Override
    public void notImplemented() {
      target.notImplemented();
    }
  }

  private interface RegionCallback {
    void onFound(OfflineRegion region);
  }

  private static void findRegionById(
      Context context, long id, MethodChannel.Result result, RegionCallback callback) {
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> {
                  for (OfflineRegion offlineRegion : offlineRegions) {
                    if (offlineRegion.getId() != id) continue;
                    callback.onFound(offlineRegion);
                    return;
                  }
                  regionNotFound(result, id);
                });
              }

              @Override
              public void onError(String error) {
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  static void getRegionStatus(MethodChannel.Result result, Context context, long id) {
    // Check active downloads first
    ActiveDownload download = activeDownloads.get(id);
    if (download != null) {
      fetchAndReturnStatus(result, download.region);
      return;
    }
    // Fall back to listing all regions
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                guard(result, () -> {
                  for (OfflineRegion offlineRegion : offlineRegions) {
                    if (offlineRegion.getId() != id) continue;
                    fetchAndReturnStatus(result, offlineRegion);
                    return;
                  }
                  regionNotFound(result, id);
                });
              }

              @Override
              public void onError(String error) {
                result.error(OFFLINE_DATABASE_ERROR, error, null);
              }
            });
  }

  private static void fetchAndReturnStatus(MethodChannel.Result result, OfflineRegion region) {
    region.getStatus(
        new OfflineRegion.OfflineRegionStatusCallback() {
          @Override
          public void onStatus(OfflineRegionStatus status) {
            guard(result, () -> {
              double progress =
                  calculateDownloadingProgress(
                      status.getRequiredResourceCount(), status.getCompletedResourceCount());
              Map<String, Object> statusMap = new HashMap<>();
              statusMap.put("completedResourceCount", status.getCompletedResourceCount());
              statusMap.put("requiredResourceCount", status.getRequiredResourceCount());
              statusMap.put("completedResourceSize", status.getCompletedResourceSize());
              statusMap.put("isComplete", status.isComplete());
              statusMap.put("downloadProgress", progress);
              result.success(new Gson().toJson(statusMap));
            });
          }

          @Override
          public void onError(String error) {
            result.error(OFFLINE_DATABASE_ERROR, error, null);
          }
        });
  }

  /** Answers REGION_NOT_FOUND for {@code id}. */
  private static void regionNotFound(MethodChannel.Result result, long id) {
    result.error(REGION_NOT_FOUND, "There is no offline region with id " + id + ".", null);
  }

  private static double calculateDownloadingProgress(
      long requiredResourceCount, long completedResourceCount) {
    return requiredResourceCount > 0
        ? (100.0 * completedResourceCount / requiredResourceCount)
        : 0.0;
  }

  private static OfflineRegionDefinition mapToRegionDefinition(
      Map<String, Object> map, float pixelDensity) {
    for (Map.Entry<String, Object> entry : map.entrySet()) {
      Log.d(TAG, entry.getKey());
      Log.d(TAG, entry.getValue().toString());
    }
    // Create a bounding box for the offline region
    return new OfflineTilePyramidRegionDefinition(
        (String) map.get("mapStyleUrl"),
        listToBounds((List<List<Double>>) map.get("bounds")),
        ((Number) map.get("minZoom")).doubleValue(),
        ((Number) map.get("maxZoom")).doubleValue(),
        pixelDensity,
        (Boolean) map.get("includeIdeographs"));
  }

  private static LatLngBounds listToBounds(List<List<Double>> bounds) {
    return new LatLngBounds.Builder()
        .include(new LatLng(bounds.get(1).get(0), bounds.get(1).get(1))) // Northeast
        .include(new LatLng(bounds.get(0).get(0), bounds.get(0).get(1))) // Southwest
        .build();
  }

  private static Map<String, Object> offlineRegionToMap(OfflineRegion region) {
    Map<String, Object> result = new HashMap();
    result.put("id", region.getId());
    result.put("definition", offlineRegionDefinitionToMap(region.getDefinition()));
    result.put("metadata", metadataBytesToMap(region.getMetadata()));
    return result;
  }

  private static Map<String, Object> offlineRegionDefinitionToMap(
      OfflineRegionDefinition definition) {
    Map<String, Object> result = new HashMap();
    result.put("mapStyleUrl", definition.getStyleURL());
    result.put("bounds", boundsToList(definition.getBounds()));
    result.put("minZoom", definition.getMinZoom());
    result.put("maxZoom", definition.getMaxZoom());
    result.put("includeIdeographs", definition.getIncludeIdeographs());
    return result;
  }

  private static List<List<Double>> boundsToList(LatLngBounds bounds) {
    List<List<Double>> boundsList = new ArrayList<>();
    List<Double> northeast = Arrays.asList(bounds.getLatNorth(), bounds.getLonEast());
    List<Double> southwest = Arrays.asList(bounds.getLatSouth(), bounds.getLonWest());
    boundsList.add(southwest);
    boundsList.add(northeast);
    return boundsList;
  }

  /**
   * The metadata of a region as a map. Metadata that is not a JSON object, such as {@code []} or
   * what another tool wrote into a merged database, reads as an empty map, as on iOS.
   */
  static Map<String, Object> metadataBytesToMap(@Nullable byte[] metadataBytes) {
    if (metadataBytes != null) {
      try {
        // Null for an empty or "null" payload.
        Map<String, Object> metadata =
            new Gson().fromJson(new String(metadataBytes), HashMap.class);
        if (metadata != null) {
          return metadata;
        }
      } catch (RuntimeException e) {
        Log.w(TAG, "Reading offline region metadata that is not a JSON object as empty: " + e);
      }
    }
    return new HashMap<>();
  }

  /**
   * The metadata as JSON, "{}" for none. Answers INVALID_ARGUMENT and returns null for metadata
   * JSON cannot hold, such as a NaN.
   */
  @Nullable
  static String metadataToJson(
      @Nullable Map<String, Object> metadataMap, MethodChannel.Result result) {
    if (metadataMap == null) {
      return "{}";
    }
    try {
      return new Gson().toJson(metadataMap);
    } catch (RuntimeException e) {
      result.error(INVALID_ARGUMENT, "Metadata is not JSON serializable", null);
      return null;
    }
  }

  private static String regionsToJson(OfflineRegion[] offlineRegions) {
    List<Map<String, Object>> regions = new ArrayList<>();
    for (OfflineRegion offlineRegion : offlineRegions) {
      regions.add(offlineRegionToMap(offlineRegion));
    }
    return new Gson().toJson(regions);
  }

  /**
   * Runs the body of an SDK callback that answers {@code result}. What it throws answers code
   * "error" instead of crashing the app, unless the call has already been answered.
   */
  static void guard(@Nullable MethodChannel.Result result, Runnable body) {
    try {
      body.run();
    } catch (RuntimeException e) {
      Log.e(TAG, "An offline callback failed", e);
      if (result != null) {
        result.error("error", e.getMessage(), Log.getStackTraceString(e));
      }
    }
  }
}
