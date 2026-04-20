package org.maplibre.maplibregl;

import android.content.Context;
import android.os.SystemClock;
import android.util.Log;
import androidx.annotation.NonNull;
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
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

abstract class OfflineManagerUtils {
  private static final String TAG = "OfflineManagerUtils";

  /**
   * Minimum interval between progress events forwarded to Dart. When tiles are
   * served from the local MapLibre cache (e.g. a previously downloaded region
   * was deleted and re-downloaded), the SDK can emit ~1000 status updates per
   * second, flooding the Dart isolate and starving user input (pause/resume
   * taps). Terminal events (completion, error) are always emitted regardless
   * of this throttle.
   */
  private static final long PROGRESS_EMIT_MIN_INTERVAL_MS = 100L;

  /** Holds the state needed to observe and control an in-progress download. */
  static class ActiveDownload {
    final OfflineRegion region;
    final OfflineChannelHandlerImpl channelHandler;
    final AtomicBoolean isComplete;
    long lastProgressEmitMs;
    long lastEmittedCompletedCount;

    ActiveDownload(OfflineRegion region, OfflineChannelHandlerImpl channelHandler, AtomicBoolean isComplete) {
      this.region = region;
      this.channelHandler = channelHandler;
      this.isComplete = isComplete;
      this.lastProgressEmitMs = 0L;
      this.lastEmittedCompletedCount = -1L;
    }
  }

  static final Map<Long, ActiveDownload> activeDownloads = new HashMap<>();

  static void mergeRegions(MethodChannel.Result result, Context context, String path) {
    OfflineManager.Companion.getInstance(context)
        .mergeOfflineRegions(
            path,
            new OfflineManager.MergeOfflineRegionsCallback() {
              public void onMerge(OfflineRegion[] offlineRegions) {
                if (result == null) return;
                List<Map<String, Object>> regionsArgs = new ArrayList<>();
                for (OfflineRegion offlineRegion : offlineRegions) {
                  regionsArgs.add(offlineRegionToMap(offlineRegion));
                }
                String json = new Gson().toJson(regionsArgs);
                result.success(json);
              }

              public void onError(String error) {
                if (result == null) return;
                result.error("mergeOfflineRegions Error", error, null);
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
                result.error("ClearAmbientCacheError", message, null);
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
    }
    activeDownloads.clear();

    OfflineManager.Companion.getInstance(context)
        .resetDatabase(
            new OfflineManager.FileSourceCallback() {
              @Override
              public void onSuccess() {
                result.success(null);
              }

              @Override
              public void onError(@NonNull String message) {
                result.error("ResetDatabaseError", message, null);
              }
            });
  }

  /**
   * Creates and sets an {@link OfflineRegion.OfflineRegionObserver} on the given region.
   * The observer forwards progress, completion, and error events to the channel handler.
   */
  private static void setObserverOnRegion(
      OfflineRegion region, OfflineChannelHandlerImpl channelHandler,
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
              channelHandler.onSuccess();
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
            Log.e(TAG, "onError reason: " + error.getReason());
            Log.e(TAG, "onError message: " + error.getMessage());
            region.setDownloadState(OfflineRegion.STATE_INACTIVE);
            activeDownloads.remove(region.getId());
            isComplete.set(true);
            channelHandler.onError(
                "Downloading error", error.getMessage(), error.getReason());
          }

          @Override
          public void mapboxTileCountLimitExceeded(long limit) {
            Log.e(TAG, "MapLibre tile count limit exceeded: " + limit);
            region.setDownloadState(OfflineRegion.STATE_INACTIVE);
            activeDownloads.remove(region.getId());
            isComplete.set(true);
            channelHandler.onError(
                "mapboxTileCountLimitExceeded",
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
      OfflineChannelHandlerImpl channelHandler) {
    float pixelDensity = context.getResources().getDisplayMetrics().density;
    OfflineRegionDefinition definition = mapToRegionDefinition(definitionMap, pixelDensity);
    String metadata = "{}";
    if (metadataMap != null) {
      metadata = new Gson().toJson(metadataMap);
    }
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
                // Track BEFORE result.success so the Dart side can't race us by
                // invoking pause/resume before this region is registered.
                activeDownloads.put(offlineRegion.getId(),
                    new ActiveDownload(offlineRegion, channelHandler, isComplete));
                setObserverOnRegion(offlineRegion, channelHandler, isComplete, context);
                _offlineRegion.setDownloadState(OfflineRegion.STATE_ACTIVE);

                Map<String, Object> regionData = offlineRegionToMap(offlineRegion);
                result.success(new Gson().toJson(regionData));
                channelHandler.onStart();
              }

              @Override
              public void onError(String error) {
                Log.e(TAG, "Error: " + error);
                _offlineRegion.setDownloadState(OfflineRegion.STATE_INACTIVE);
                channelHandler.onError("mapboxInvalidRegionDefinition", error, null);
                result.error("mapboxInvalidRegionDefinition", error, null);
              }
            });
  }

  static void regionsList(MethodChannel.Result result, Context context) {
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                List<Map<String, Object>> regionsArgs = new ArrayList<>();
                for (OfflineRegion offlineRegion : offlineRegions) {
                  regionsArgs.add(offlineRegionToMap(offlineRegion));
                }
                result.success(new Gson().toJson(regionsArgs));
              }

              @Override
              public void onError(String error) {
                result.error("RegionListError", error, null);
              }
            });
  }

  static void updateRegionMetadata(
      MethodChannel.Result result, Context context, long id, Map<String, Object> metadataMap) {
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                for (OfflineRegion offlineRegion : offlineRegions) {
                  if (offlineRegion.getId() != id) continue;

                  String metadata = "{}";
                  if (metadataMap != null) {
                    metadata = new Gson().toJson(metadataMap);
                  }
                  offlineRegion.updateMetadata(
                      metadata.getBytes(),
                      new OfflineRegion.OfflineRegionUpdateMetadataCallback() {
                        @Override
                        public void onUpdate(byte[] metadataBytes) {
                          Map<String, Object> regionData = offlineRegionToMap(offlineRegion);
                          regionData.put("metadata", metadataBytesToMap(metadataBytes));

                          if (result == null) return;
                          result.success(new Gson().toJson(regionData));
                        }

                        @Override
                        public void onError(String error) {
                          if (result == null) return;
                          result.error("UpdateMetadataError", error, null);
                        }
                      });
                  return;
                }
                if (result == null) return;
                result.error(
                    "UpdateMetadataError",
                    "There is no " + "region with given id to " + "update.",
                    null);
              }

              @Override
              public void onError(String error) {
                if (result == null) return;
                result.error("RegionListError", error, null);
              }
            });
  }

  static void deleteRegion(MethodChannel.Result result, Context context, long id) {
    ActiveDownload active = activeDownloads.remove(id);
    if (active != null) {
      active.isComplete.set(true);
      active.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
    }
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
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
                          result.error("DeleteRegionError", error, null);
                        }
                      });
                  return;
                }
                if (result == null) return;
                result.error(
                    "DeleteRegionError",
                    "There is no " + "region with given id to " + "delete.",
                    null);
              }

              @Override
              public void onError(String error) {
                if (result == null) return;
                result.error("RegionListError", error, null);
              }
            });
  }

  // Pause / Resume / Status

  static void pauseRegion(MethodChannel.Result result, Context context, long id) {
    ActiveDownload download = activeDownloads.get(id);
    if (download != null) {
      download.region.setDownloadState(OfflineRegion.STATE_INACTIVE);
      result.success(null);
    } else {
      findRegionById(context, id, result, "PauseRegionError", foundRegion -> {
        foundRegion.setDownloadState(OfflineRegion.STATE_INACTIVE);
        result.success(null);
      });
    }
  }

  static void resumeRegion(MethodChannel.Result result, Context context, long id) {
    ActiveDownload download = activeDownloads.get(id);
    if (download != null) {
      // Deliver status messages even while inactive so the state-change
      // callback fires after STATE_ACTIVE — some paths rely on this to
      // re-arm internal tile dispatching.
      download.region.setDeliverInactiveMessages(true);
      // Re-set the observer to ensure callbacks fire after resume
      setObserverOnRegion(download.region, download.channelHandler, download.isComplete, context);
      download.region.setDownloadState(OfflineRegion.STATE_ACTIVE);
      result.success(null);
    } else {
      findRegionById(context, id, result, "ResumeRegionError", foundRegion -> {
        // Region was not tracked (e.g. app restarted) — we cannot resume
        // progress events without a channel handler, so return an error.
        result.error(
            "ResumeRegionError",
            "Region is no longer actively tracked. Please restart the download.",
            null);
      });
    }
  }

  private interface RegionCallback {
    void onFound(OfflineRegion region);
  }

  private static void findRegionById(
      Context context, long id, MethodChannel.Result result, String errorCode, RegionCallback callback) {
    OfflineManager.Companion.getInstance(context)
        .listOfflineRegions(
            new OfflineManager.ListOfflineRegionsCallback() {
              @Override
              public void onList(OfflineRegion[] offlineRegions) {
                for (OfflineRegion offlineRegion : offlineRegions) {
                  if (offlineRegion.getId() != id) continue;
                  callback.onFound(offlineRegion);
                  return;
                }
                result.error(errorCode, "There is no region with given id", null);
              }

              @Override
              public void onError(String error) {
                result.error(errorCode, error, null);
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
                for (OfflineRegion offlineRegion : offlineRegions) {
                  if (offlineRegion.getId() != id) continue;
                  fetchAndReturnStatus(result, offlineRegion);
                  return;
                }
                result.error(
                    "GetRegionStatusError", "There is no region with given id", null);
              }

              @Override
              public void onError(String error) {
                result.error("GetRegionStatusError", error, null);
              }
            });
  }

  private static void fetchAndReturnStatus(MethodChannel.Result result, OfflineRegion region) {
    region.getStatus(
        new OfflineRegion.OfflineRegionStatusCallback() {
          @Override
          public void onStatus(OfflineRegionStatus status) {
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
          }

          @Override
          public void onError(String error) {
            result.error("GetRegionStatusError", error, null);
          }
        });
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

  private static Map<String, Object> metadataBytesToMap(byte[] metadataBytes) {
    if (metadataBytes != null) {
      return new Gson().fromJson(new String(metadataBytes), HashMap.class);
    }
    return new HashMap();
  }
}
