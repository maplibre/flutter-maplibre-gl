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

  private static void rebuildClient() {
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

    // Apply header interceptor
    if (currentHeaders != null) {
      builder.addNetworkInterceptor(
          chain -> {
            Request.Builder reqBuilder = chain.request().newBuilder();
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
            return chain.proceed(reqBuilder.build());
          });
    }

    HttpRequestUtil.setOkHttpClient(builder.build());
  }
}
