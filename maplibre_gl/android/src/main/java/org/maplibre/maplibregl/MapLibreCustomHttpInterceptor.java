package org.maplibre.maplibregl;

import org.maplibre.android.module.http.HttpRequestUtil;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;
import java.util.HashMap;
import java.util.List;
import java.util.ArrayList;
import java.util.regex.Pattern;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import android.util.Log;

public class MapLibreCustomHttpInterceptor {
  private static final String TAG = "MapLibreCustomHttpInterceptor";
  public static final HashMap<String, String> CustomHeaders = new HashMap<>();
  public static final List<String> Filter = new ArrayList<>();

  public static void setCustomHeaders(Map<String, String> headers, List<String> filter, MethodChannel.Result result) {
    CustomHeaders.clear();
    Filter.clear();

    for (Map.Entry<String, String> entry : headers.entrySet()) {
      CustomHeaders.put(entry.getKey(), entry.getValue());
      Log.d(TAG, "Setting " + entry.getKey() + " to " + entry.getValue());
    }

    for (String pattern : filter) {
      Filter.add(pattern);
    }

    HttpRequestUtil.setOkHttpClient(getOkHttpClient().build());
    result.success(null);
  }

  private static OkHttpClient.Builder getOkHttpClient() {
    try {
      return new OkHttpClient.Builder()
          .addNetworkInterceptor(
              chain -> {
                Request.Builder builder = chain.request().newBuilder();
                String url = chain.request().url().toString();

                // Check if URL matches any filter pattern
                boolean shouldApplyHeaders = Filter.isEmpty();
                for (String pattern : Filter) {
                  if (Pattern.matches(pattern, url)) {
                    shouldApplyHeaders = true;
                    break;
                  }
                }

                if (shouldApplyHeaders) {
                  for (Map.Entry<String, String> header : CustomHeaders.entrySet()) {
                    if (header.getKey() == null || header.getKey().trim().isEmpty()) {
                      continue;
                    }
                    if (header.getValue() == null || header.getValue().trim().isEmpty()) {
                      builder.removeHeader(header.getKey());
                    } else {
                      builder.header(header.getKey(), header.getValue());
                    }
                  }
                }

                return chain.proceed(builder.build());
              });
    } catch (Exception e) {
      Log.e(TAG, "Error creating HTTP client: " + e.getMessage());
      throw new RuntimeException(e);
    }
  }
}

