package org.maplibre.maplibregl;

import org.maplibre.android.module.http.HttpRequestUtil;
import io.flutter.plugin.common.MethodChannel;
import java.util.Map;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLSession;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.security.SecureRandom;
import java.util.HashMap;

abstract class MapLibreHttpRequestUtil {
  private static boolean sslCertificateBypassEnabled = false;
  private static Map<String, String> currentHeaders = new HashMap<>();

  public static void setHttpHeaders(Map<String, String> headers, MethodChannel.Result result) {
    currentHeaders.clear();
    currentHeaders.putAll(headers);
    HttpRequestUtil.setOkHttpClient(getOkHttpClient(headers, result).build());
    result.success(null);
  }

  public static void setSslCertificateBypass(boolean enabled, MethodChannel.Result result) {
    sslCertificateBypassEnabled = enabled;
    // Apply changes immediately by rebuilding the OkHttpClient with the current headers
    HttpRequestUtil.setOkHttpClient(getOkHttpClient(currentHeaders, result).build());
    result.success(null);
  }

  private static OkHttpClient.Builder getOkHttpClient(
      Map<String, String> headers, MethodChannel.Result result) {
    try {
      OkHttpClient.Builder builder = new OkHttpClient.Builder();
      
      if (sslCertificateBypassEnabled) {
        // Create a trust manager that does not validate certificate chains
        final TrustManager[] trustAllCerts = new TrustManager[] {
          new X509TrustManager() {
            @Override
            public void checkClientTrusted(X509Certificate[] chain, String authType) throws CertificateException {
            }

            @Override
            public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException {
            }

            @Override
            public X509Certificate[] getAcceptedIssuers() {
              return new X509Certificate[]{};
            }
          }
        };

        // Install the all-trusting trust manager
        final SSLContext sslContext = SSLContext.getInstance("SSL");
        sslContext.init(null, trustAllCerts, new SecureRandom());
        
        // Create an ssl socket factory with our all-trusting manager
        final HostnameVerifier hostnameVerifier = new HostnameVerifier() {
          @Override
          public boolean verify(String hostname, SSLSession session) {
            return true;
          }
        };

        builder.sslSocketFactory(sslContext.getSocketFactory(), (X509TrustManager)trustAllCerts[0])
              .hostnameVerifier(hostnameVerifier);
      }

      // Add network interceptor for headers
      builder.addNetworkInterceptor(
          chain -> {
            Request.Builder requestBuilder = chain.request().newBuilder();
            for (Map.Entry<String, String> header : headers.entrySet()) {
              if (header.getKey() == null || header.getKey().trim().isEmpty()) {
                continue;
              }
              if (header.getValue() == null || header.getValue().trim().isEmpty()) {
                requestBuilder.removeHeader(header.getKey());
              } else {
                requestBuilder.header(header.getKey(), header.getValue());
              }
            }
            return chain.proceed(requestBuilder.build());
          });
          
      return builder;
    } catch (Exception e) {
      result.error(
          "OK_HTTP_CLIENT_ERROR",
          "An unexcepted error happened during creating http " + "client" + e.getMessage(),
          null);
      throw new RuntimeException(e);
    }
  }
}
