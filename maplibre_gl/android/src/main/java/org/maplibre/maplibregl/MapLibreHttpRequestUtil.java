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
    rebuildClient();
    result.success(null);
  }

  public static void setMaxConcurrentRequests(
      Integer maxRequests, Integer maxRequestsPerHost, MethodChannel.Result result) {
    currentMaxRequests = maxRequests;
    currentMaxRequestsPerHost = maxRequestsPerHost;
    rebuildClient();
    result.success(null);
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
