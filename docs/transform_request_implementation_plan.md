# Implementation Plan - Implementing `transformRequest` in `flutter-maplibre-gl`

This document details the plan to implement the `transformRequest` request interception/modification callback in the MapLibre Flutter SDK. This will match the parity of MapLibre GL JS's `transformRequest` functionality, allowing developers to intercept, modify URLs, and add custom headers dynamically for all map resource requests (tiles, styles, sprites, glyphs, etc.).

## Goal

Provide a unified cross-platform API in Dart:
```dart
typedef TransformRequestCallback = FutureOr<RequestParameters> Function(
  String url,
  ResourceType resourceType,
);
```
Which intercepts all network requests made by the MapLibre engine (on Web, Android, and iOS) and runs them through the Dart callback to dynamically transform the request URL and headers.

---

## User Review Required

> [!IMPORTANT]
> **Performance Considerations on Mobile**
> Intercepting every single tile request (which can be 50-100 requests during rapid panning) and routing it via Flutter's `MethodChannel` to Dart introduces a small serialization and context-switching overhead (a few milliseconds per request).
> - For static headers (like API keys, static tokens), developers should continue to use `setHttpHeaders` or `setCustomHeaders` which run entirely on the native side.
> - `transformRequest` should be reserved for dynamic use cases (like signing URLs, rotating tokens, or rewriting URLs dynamically).
> - On Web, this runs natively in JS and has negligible overhead.

---

## Proposed Changes

We will implement this by utilizing:
1. **Web**: Direct integration with MapLibre GL JS's `transformRequest` option using `JSPromise`.
2. **Android**: Interception inside `MapLibreCustomHttpInterceptor` (OkHttp Interceptor) running on background network threads, blocking synchronously to await Dart's response via the MethodChannel.
3. **iOS**: Interception inside `MapLibreHeadersProtocol` (custom `URLProtocol`) running on background network threads, blocking synchronously to await Dart's response via the MethodChannel.

By executing the native-to-Dart communication from **background threads** on Android/iOS, we prevent blocking the main/UI thread, ensuring a **completely deadlock-free** implementation.

---

### `maplibre_gl_platform_interface`

This component defines the shared platform types and interface methods.

#### [NEW] [resource_type.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl_platform_interface/lib/src/resource_type.dart)
Define the `ResourceType` enum to identify the kind of resource requested:
```dart
enum ResourceType {
  unknown,
  style,
  source,
  tile,
  glyphs,
  spriteImage,
  spriteJSON,
  image,
}
```

#### [NEW] [request_parameters.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl_platform_interface/lib/src/request_parameters.dart)
Define the target structure returned by the transform callback:
```dart
class RequestParameters {
  final String url;
  final Map<String, String>? headers;

  RequestParameters({required this.url, this.headers});

  Map<String, dynamic> toMap() => {
    'url': url,
    if (headers != null) 'headers': headers,
  };
}
```

#### [MODIFY] [maplibre_gl_platform_interface.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl_platform_interface/lib/src/maplibre_gl_platform_interface.dart)
- Export `resource_type.dart` and `request_parameters.dart`.
- Add `TransformRequestCallback` typedef:
  ```dart
  typedef TransformRequestCallback = FutureOr<RequestParameters> Function(
    String url,
    ResourceType resourceType,
  );
  ```
- Add `transformRequest` property/callback setter to `MapLibrePlatform`.

#### [MODIFY] [method_channel_maplibre_gl.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl_platform_interface/lib/src/method_channel_maplibre_gl.dart)
- Implement `transformRequest` property.
- Update `_handleMethodCall` to handle `'map#transformRequest'`:
  ```dart
  case 'map#transformRequest':
    final String url = call.arguments['url'];
    final int kind = call.arguments['resourceType'];
    final resourceType = ResourceType.values[kind];
    if (transformRequest != null) {
      final result = await transformRequest!(url, resourceType);
      return result.toMap();
    }
    return {'url': url};
  ```

---

### `maplibre_gl` (Main Dart SDK)

#### [MODIFY] [maplibre_map.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl/lib/src/maplibre_map.dart)
- Add `transformRequest` callback to `MapLibreMap` widget constructor.
- Update `_MapLibreMapState.build()` to pass `'transformRequestEnabled': widget.transformRequest != null` inside `creationParams`.
- In `onPlatformViewCreated()`, register the widget's callback on the controller:
  ```dart
  if (widget.transformRequest != null) {
    controller.transformRequest = widget.transformRequest;
  }
  ```

#### [MODIFY] [controller.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl/lib/src/controller.dart)
- Expose the `transformRequest` setter/getter in `MaplibreMapController` which forwards to `_maplibrePlatform.transformRequest`.

---

### `maplibre_gl_web` (Web Platform Implementation)

#### [MODIFY] [maplibre_web_gl_platform.dart](file:///Users/sharemap/Documents/sharemap/flutter-maplibre-gl/maplibre_gl_web/lib/src/maplibre_web_gl_platform.dart)
- Read `_creationParams['transformRequestEnabled']`.
- If true, construct a `transformRequest` JS callback:
  ```dart
  JSFunction? jsTransformRequest;
  if (_creationParams['transformRequestEnabled'] == true) {
    jsTransformRequest = ((JSString url, JSString resourceType) {
      final type = _parseResourceType(resourceType.toDart);
      final dartFuture = _executeTransformRequest(url.toDart, type);
      return dartFuture.toJS;
    }).toJS;
  }
  ```
- Pass it to `MapOptions` during `MapLibreMap` construction.
- Implement helper method to convert Dart output to JS:
  ```dart
  Future<JSAny?> _executeTransformRequest(String url, ResourceType type) async {
    if (transformRequest != null) {
      final params = await transformRequest!(url, type);
      final jsParams = createJsObject() as JSObjectExt;
      jsParams['url'] = params.url.toJS;
      if (params.headers != null) {
        final jsHeaders = createJsObject() as JSObjectExt;
        for (final entry in params.headers!.entries) {
          jsHeaders[entry.key] = entry.value.toJS;
        }
        jsParams['headers'] = jsHeaders;
      }
      return jsParams;
    }
    final jsParams = createJsObject() as JSObjectExt;
    jsParams['url'] = url.toJS;
    return jsParams;
  }
  ```

---

### Android implementation

#### [MODIFY] `MapLibreMapController.java`
- Read `transformRequestEnabled` from `creationParams`.
- If true, configure the `MapLibreCustomHttpInterceptor` with a reference to the `methodChannel`.

#### [MODIFY] `MapLibreCustomHttpInterceptor.java`
- Add support to trigger `map#transformRequest` method calls back to Dart.
- Since OkHttp runs on background thread pools, use a `CountDownLatch` and `Handler(Looper.getMainLooper())` to post the method call onto the main thread, block the background thread, and resume once Dart returns:
  ```java
  // In interceptor loop:
  if (transformRequestEnabled) {
      final CountDownLatch latch = new CountDownLatch(1);
      final Map<String, Object> resultRef = new HashMap<>();
      final Map<String, Object> args = new HashMap<>();
      args.put("url", url);
      args.put("resourceType", inferResourceType(url));

      new Handler(Looper.getMainLooper()).post(() -> {
          methodChannel.invokeMethod("map#transformRequest", args, new MethodChannel.Result() {
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
          // ignore or handle
      }

      if (resultRef.containsKey("url")) {
          // modify okhttp request url and headers based on resultRef
      }
  }
  ```
- Implement `inferResourceType(String url)` matching standard URL heuristics.

---

### iOS implementation

#### [MODIFY] `MapLibreMapController.swift`
- Expose the method channel instance to the custom URLProtocol `MapLibreHeadersProtocol`.

#### [MODIFY] `MapLibreHeadersProtocol.swift`
- In `startLoading()`, if `transformRequestEnabled` is true:
  - Call the main thread asynchronously to invoke `map#transformRequest` on Dart side.
  - Block the background thread using a `DispatchSemaphore`.
  - Once returned, update the request URL and headers dynamically before beginning the `URLSessionDataTask`.
  ```swift
  let semaphore = DispatchSemaphore(value: 0)
  var transformedUrl: String = originalUrl
  var transformedHeaders: [String: String]? = nil

  DispatchQueue.main.async {
      channel.invokeMethod("map#transformRequest", arguments: [
          "url": originalUrl,
          "resourceType": self.inferResourceType(originalUrl)
      ]) { result in
          if let dict = result as? [String: Any] {
              transformedUrl = dict["url"] as? String ?? originalUrl
              transformedHeaders = dict["headers"] as? [String: String]
          }
          semaphore.signal()
      }
  }
  _ = semaphore.wait(timeout: .distantFuture)

  // Use transformedUrl & transformedHeaders to perform loading...
  ```
- Implement `inferResourceType` matching the URL path heuristic.

---

## Verification Plan

### Automated Tests
- Run Melos web and io tests:
  ```bash
  melos run test
  ```
- Create a unit/widget test in `maplibre_gl/test` verifying that `transformRequest` executes and modifies requests correctly.

### Manual Verification
- Implement a test page in the `maplibre_gl_example` app containing a `transformRequest` callback.
- Verify that custom auth headers or URL rewrites are successfully applied to requests (e.g. by intercepting with an HTTP proxy or checking map loading behavior).

---

## How to Use / Usage Examples

After these changes, developers can specify a `transformRequest` callback when creating the `MapLibreMap` widget.

### Example 1: Basic URL Rewriting (e.g., replacing HTTP with HTTPS)
```dart
MapLibreMap(
  initialCameraPosition: CameraPosition(target: LatLng(0, 0), zoom: 3),
  transformRequest: (url, resourceType) {
    if (url.startsWith("http://my-secure-server.com")) {
      return RequestParameters(
        url: url.replaceFirst("http://", "https://"),
      );
    }
    return RequestParameters(url: url);
  },
)
```

### Example 2: Adding Dynamic Authentication Tokens (e.g., Authorization Headers)
```dart
MapLibreMap(
  initialCameraPosition: CameraPosition(target: LatLng(0, 0), zoom: 3),
  transformRequest: (url, resourceType) async {
    // Only intercept requests to our specific tile provider
    if (url.contains("tiles.myprovider.com")) {
      final token = await MyAuthService.getFreshToken();
      return RequestParameters(
        url: url,
        headers: {
          "Authorization": "Bearer $token",
          "X-Client-Version": "1.0.0",
        },
      );
    }
    // Return original url unchanged for other requests
    return RequestParameters(url: url);
  },
)
```

### Example 3: Filtering by Resource Type
```dart
MapLibreMap(
  initialCameraPosition: CameraPosition(target: LatLng(0, 0), zoom: 3),
  transformRequest: (url, resourceType) {
    if (resourceType == ResourceType.tile) {
      // Modify tile URL parameters dynamically
      return RequestParameters(url: "$url?highDpi=true");
    } else if (resourceType == ResourceType.style) {
      // Append style version query parameters
      return RequestParameters(url: "$url?v=2");
    }
    return RequestParameters(url: url);
  },
)
```

