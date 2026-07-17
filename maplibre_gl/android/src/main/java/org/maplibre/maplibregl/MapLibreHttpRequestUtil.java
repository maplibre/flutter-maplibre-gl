package org.maplibre.maplibregl;

import org.maplibre.android.module.http.HttpRequestUtil;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;
import okhttp3.Dispatcher;
import okhttp3.OkHttpClient;
import okhttp3.Request;

abstract class MapLibreHttpRequestUtil {

  private static Map<String, String> currentHeaders;
  private static Integer currentMaxRequests;
  private static Integer currentMaxRequestsPerHost;

  public static void setHttpHeaders(Map<String, String> headers, MethodChannel.Result result) {
    currentHeaders = headers;
    try {
      rebuildClient();
      result.success(null);
    } catch (RuntimeException e) {
      result.error("SetHttpHeadersError", e.getMessage(), null);
    }
  }

  public static void setMaxConcurrentRequests(
      Integer maxRequests, Integer maxRequestsPerHost, MethodChannel.Result result) {
    // OkHttp's Dispatcher throws IllegalArgumentException for values < 1.
    // Validate before mutating state so a rejected call doesn't leave the
    // static fields half-updated.
    if (maxRequests != null && maxRequests < 1) {
      result.error(
          "InvalidMaxRequests",
          "maxRequests must be >= 1 (got " + maxRequests + ")",
          null);
      return;
    }
    if (maxRequestsPerHost != null && maxRequestsPerHost < 1) {
      result.error(
          "InvalidMaxRequestsPerHost",
          "maxRequestsPerHost must be >= 1 (got " + maxRequestsPerHost + ")",
          null);
      return;
    }
    currentMaxRequests = maxRequests;
    currentMaxRequestsPerHost = maxRequestsPerHost;
    try {
      rebuildClient();
      result.success(null);
    } catch (RuntimeException e) {
      result.error("SetMaxConcurrentRequestsError", e.getMessage(), null);
    }
  }

  static void rebuildClient() {
    OkHttpClient.Builder builder = new OkHttpClient.Builder();

    // Apply dispatcher configuration
    if (currentMaxRequests != null || currentMaxRequestsPerHost != null) {
      Dispatcher dispatcher = new Dispatcher();
      if (currentMaxRequests != null) {
        dispatcher.setMaxRequests(currentMaxRequests);
      }
      if (currentMaxRequestsPerHost != null) {
        dispatcher.setMaxRequestsPerHost(currentMaxRequestsPerHost);
      }
      builder.dispatcher(dispatcher);
    }

    // Apply network interceptor (handling both transformRequest and global headers)
    builder.addNetworkInterceptor(
        chain -> {
          Request.Builder reqBuilder = chain.request().newBuilder();
          String url = chain.request().url().toString();

          // 1. Check if any active controller has transformRequest enabled
          boolean transformEnabled = false;
          MapLibreMapController targetController = null;
          for (MapLibreMapController controller : MapLibreMapController.activeControllers) {
            if (controller.isTransformRequestEnabled()) {
              transformEnabled = true;
              targetController = controller;
              break;
            }
          }

          if (transformEnabled && targetController != null) {
            final java.util.concurrent.CountDownLatch latch = new java.util.concurrent.CountDownLatch(1);
            final Map<String, Object> resultRef = new java.util.HashMap<>();
            final Map<String, Object> args = new java.util.HashMap<>();
            args.put("url", url);
            args.put("resourceType", inferResourceType(url));

            final MethodChannel channel = targetController.getMethodChannel();
            new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> {
              channel.invokeMethod("map#transformRequest", args, new MethodChannel.Result() {
                @Override
                public void success(Object result) {
                  if (result instanceof Map) {
                    resultRef.putAll((Map<String, Object>) result);
                  }
                  latch.countDown();
                }
                @Override
                public void error(String code, String message, Object details) {
                  latch.countDown();
                }
                @Override
                public void notImplemented() {
                  latch.countDown();
                }
              });
            });

            try {
              latch.await();
            } catch (InterruptedException e) {
              // ignore
            }

            if (resultRef.containsKey("url")) {
              String newUrl = (String) resultRef.get("url");
              if (newUrl != null && !newUrl.isEmpty()) {
                reqBuilder.url(newUrl);
              }
              if (resultRef.containsKey("headers")) {
                Map<String, String> newHeaders = (Map<String, String>) resultRef.get("headers");
                if (newHeaders != null) {
                  for (Map.Entry<String, String> header : newHeaders.entrySet()) {
                    if (header.getKey() == null || header.getKey().trim().isEmpty()) {
                      continue;
                    }
                    if (header.getValue() == null || header.getValue().trim().isEmpty()) {
                      reqBuilder.removeHeader(header.getKey());
                    } else {
                      reqBuilder.header(header.getKey(), header.getValue());
                    }
                  }
                }
              }
            }
          }

          // 2. Apply global headers
          if (currentHeaders != null) {
            for (Map.Entry<String, String> header : currentHeaders.entrySet()) {
              if (header.getKey() == null || header.getKey().trim().isEmpty()) {
                continue;
              }
              if (header.getValue() == null || header.getValue().trim().isEmpty()) {
                reqBuilder.removeHeader(header.getKey());
              } else {
                reqBuilder.header(header.getKey(), header.getValue());
              }
            }
          }

          return chain.proceed(reqBuilder.build());
        });

    HttpRequestUtil.setOkHttpClient(builder.build());
  }

  private static int inferResourceType(String url) {
    if (url == null) {
      return 0; // unknown
    }
    String lower = url.toLowerCase();
    if (lower.contains("/styles/") || lower.endsWith("style.json")) {
      return 1; // style
    }
    if (lower.contains("/sprites/") || lower.contains("sprite")) {
      if (lower.endsWith(".json")) {
        return 6; // spriteJSON
      }
      return 5; // spriteImage
    }
    if (lower.contains("/fonts/") || lower.contains("/glyphs/")) {
      return 4; // glyphs
    }
    if (lower.contains("/tiles/") || lower.contains("/tile/") || lower.endsWith(".pbf") || lower.endsWith(".mvt")) {
      return 3; // tile
    }
    return 0; // unknown
  }
}
