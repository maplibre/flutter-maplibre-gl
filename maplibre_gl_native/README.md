# maplibre_gl_native (EXPERIMENTAL SPIKE)

FFI backend for `maplibre_gl`: the map is driven directly through the
[MapLibre Native C API](https://github.com/maplibre/maplibre-native-ffi) via
`dart:ffi` and rendered into a Flutter `Texture`, replacing the platform-view
plus method-channel architecture. See `docs/rfc-native-ffi-engine.md` for the
full motivation, architecture, and roadmap.

**Do not use this in production.** Android arm64 only, partial API coverage,
pre-1.0 native ABI.

## How it works

```
maplibre_gl (unchanged public API)
  -> MapLibreFfiPlatform + FfiMapView   presentation: widget, gestures,
     (ffi_platform.dart, ffi_map_view)  texture/EGL lifecycle, frame pacing
    -> EngineHost                       message protocol (engine_protocol.dart);
       (engine_host.dart)               LocalEngineHost = direct calls today,
                                        SendPort transport = render isolate next
      -> FfiEngineCore                  owns every native handle; the only file
         (engine_core.dart)             that touches mln.* types
        -> maplibre_native_ffi          Dart bindings (maplibre-native-ffi PR #187)
          -> libmaplibre-native-c.so    C API over the MapLibre Native C++ core
```

The presentation/engine split is phase 2 of the render-isolate plan (see the
RFC's "Performance profiling" section): every command, query, and event
crossing the boundary is isolate-sendable, so moving `FfiEngineCore` to a
dedicated isolate is a transport swap, not a redesign.

Phase 3 ships that transport: `MapLibreGlNative.use(engineIsolate: true)`
runs the engine core on a dedicated isolate (`engine_isolate.dart`,
`IsolateEngineHost`). The engine drives its own frame loop there, so heavy
tile-integration `renderUpdate` calls no longer stall the UI thread; the
widget stops ticking entirely. A `gettid` watchdog logs if the VM ever
migrates the isolate across OS threads (the native handles are thread-affine;
see `upstream_patches/` and the RFC for the rebind insurance plan), and the
bootstrap falls back to the single-isolate engine on failure.

- The only platform channel left is the texture shim (`MapLibreGlNativePlugin`):
  it registers a `SurfaceProducer` texture, wraps its `Surface` in an EGL
  window surface (all in Kotlin via `EGL14`, raw handles passed to Dart), and
  calls `mln_android_init` through ~20 lines of JNI C.
- Dart attaches an OpenGL surface render session to the EGL handles and drives
  the runtime event loop plus rendering from a `Ticker` on the UI isolate,
  mirroring the upstream `examples/android-map` Choreographer loop.
- Gestures (pan, pinch, rotate, two-finger tilt, double-tap zoom,
  tap/long-press events) are implemented in Dart over `GestureDetector` and
  synchronous FFI camera calls.
- HTTP is Dart-owned: a resource provider (`HttpResourceProvider`) intercepts
  every http(s) request (styles, tiles, glyphs, sprites) and serves it with
  `dart:io`'s `HttpClient`, bypassing the library's built-in Rust HTTP/TLS
  stack (rustls-platform-verifier rejected valid certificates with
  "invalid peer certificate: Revoked" on some devices). This is also the seam
  where `setHttpHeaders` support will land.
- Render backend is auto-detected: the bundled `libmaplibre-native-c.so` is
  compiled for one backend (OpenGL/EGL or **Vulkan**), the Dart side queries
  it (`mln_supported_render_backend_mask`) and the platform bridge prepares
  the matching surface. For Vulkan (the default the MapLibre Android SDK
  itself moved to), the shim bootstraps instance/device/queue and wraps the
  SurfaceProducer window in a `VkSurfaceKHR`; no EGL is involved and the
  engine stops sharing the GLES driver path with Flutter's compositor.

## Building the native library

Pinned upstream state (update together):

- Repo: `maplibre/maplibre-native-ffi`, branch `dart` (PR #187),
  commit `9b2934e8feab7259a45b1def192ca1c13e8f603b`.
- Clone location assumed by the `maplibre_native_ffi` path dependency:
  `../maplibre-native-ffi` (sibling of this repository's checkout).

The pinned tree needs the local patches in `upstream_patches/` before
building; apply them **in order**. All are proposed for upstreaming (see
`docs/upstream-native-ffi-proposals.md`):

1. `0001-dart-shim-prefix-route-match.patch`: trailing-`*` prefix matching for
   Dart resource-provider routes (the pinned code matches exact URLs only,
   which makes intercepting tile/glyph/sprite URL families impossible).
2. `0002-runtime-rebind-thread.patch`: `mln_runtime_rebind_thread`, required
   because the Dart VM may migrate an isolate across OS threads while every
   native handle is owner-thread affine.
3. `0003-render-session-replace-surface.patch`:
   `mln_render_session_release_surface` and
   `mln_render_session_replace_surface`, which swap the native surface of a
   live render session while keeping the renderer and its GPU resources.
   Without it every surface recreation (Android rotation/resize) tears the
   session down and visibly re-renders the map from scratch.
4. `0004-map-copy-style-json.patch`: `mln_map_copy_style_json`, which copies
   the current style as a full style-spec JSON document (the C API only had
   the setter). Needed by the `getStyle()` platform method.
5. `0005-location-indicator-lat-lng-order.patch`: bug fix.
   `mln_map_set_location_indicator_location` built the `location` property
   in GeoJSON order `[lng, lat, altitude]`, but the location-indicator
   style-spec property is `[latitude, longitude, altitude]`; the puck
   rendered at swapped coordinates (invisible unless at Null Island).
6. `0006-canonicalize-url-before-custom-provider.patch`: bug fix. Scheme-alias
   URLs (`maplibre://tiles` in the demotiles style) were matched against
   custom-provider routes BEFORE canonicalization, so they never matched the
   provider's `http(s)://*` routes and silently fell through to the built-in
   Rust HTTP client (which fails TLS verification on some devices, see the
   proposals doc). The patch applies the same per-kind URL normalization that
   `OnlineFileSource::request` performs, before provider dispatch.
7. `0007-style-transition-options.patch`:
   `mln_map_set_style_transition_options` (+ Dart wrapper), exposing
   `mbgl::style::TransitionOptions` incl. `enablePlacementTransitions`, which
   the Android SDK exposes as `Style.setTransition`. The backend disables
   placement cross-fade for the duration of a feature drag so per-move symbol
   updates apply instantly instead of trailing by the ~300ms fade.
8. `0008-map-set-gesture-in-progress.patch`:
   `mln_map_set_gesture_in_progress` (+ Dart wrapper), exposing
   `mbgl::Map::setGestureInProgress`. The platform SDKs bracket every touch
   gesture with it; the gesture handler mirrors that (set on the first
   pointer down, cleared on the last pointer up).

```sh
git clone --recurse-submodules https://github.com/maplibre/maplibre-native-ffi.git
cd maplibre-native-ffi
git switch dart
git submodule update --init --recursive
for p in <this package>/upstream_patches/0*.patch; do git apply "$p"; done

# Toolchain (installs pinned cmake/ninja/rust/... into mise's own dirs)
brew install mise
mise trust --all
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.1.13356709"
export MISE_ENV=android-arm64-egl
mise install
mise x -- rustup target add aarch64-linux-android

# Build (arm64-v8a). Pick the render backend via MISE_ENV:
#   android-arm64-vulkan  -> Vulkan (recommended, what the spike ships)
#   android-arm64-egl     -> OpenGL ES/EGL (fallback for older devices)
mise run //:build

# Generate the ffigen bindings (maplibre_native_c.g.dart is gitignored
# upstream and must be generated before the Dart package compiles)
mise run //bindings/dart:ffigen

# Strip and copy into this package
NDK_BIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64/bin"
"$NDK_BIN/llvm-strip" --strip-unneeded \
  -o <this package>/android/src/main/jniLibs/arm64-v8a/libmaplibre-native-c.so \
  build/android-arm64-egl/libmaplibre-native-c.so
```

The stripped library is ~13 MB and links only against Android system
libraries (no `libc++_shared`).

`android/local_maven/` vendors the tiny (9 KB) `rustls-platform-verifier`
Android component that `mln_android_init` requires at initialization; it is
not published to Maven Central and ships with the Rust crate of the same name.
With the Dart HTTP resource provider installed the Rust TLS stack is no longer
on the request path, but initialization still requires the component.

## Usage

```dart
import 'package:maplibre_gl_native/maplibre_gl_native.dart';

void main() {
  MapLibreGlNative.use(); // before runApp
  runApp(const MyApp());
}
```

Then use the regular `MapLibreMap` widget from `maplibre_gl`.

## API coverage

Implemented (see `docs/ffi-api-expansion-plan.md` for the phase history):

- Camera: move/animate/ease, bounds fit, camera constraints
  (`setCameraBounds`, `cameraTargetBounds`, `minMaxZoomPreference`), content
  insets, visible region, projection (single/batch, both directions).
- Style: URL/JSON loading and `getStyle()` (patch 0004), sources
  (GeoJSON/vector/raster/raster-dem/image incl. add/update/remove and
  single-feature updates for annotation drag), layers of every type with
  add/remove, property updates (paint AND layout), visibility, filters,
  runtime images (`addImage`, sdf), introspection (layer/source ids, filter,
  visibility), `setMapLanguage`/`matchMapLanguageWithDeviceDefault`.
- Interaction: pan/pinch/rotate/two-finger-tilt/double-tap gestures, map
  click/long-click, feature taps (`enableInteraction` hit-testing,
  `featureTapsTriggersMapClick`) and feature drag (annotation drag),
  `queryRenderedFeatures` (point/rect), `querySourceFeatures`, feature state
  (set/get/remove; the method-channel backends throw on these).
- Events: style-loaded, camera move/idle, map idle, user-location,
  camera-tracking changed/dismissed, feature tapped/dragged.
- Location component: puck via the native `location-indicator` layer,
  platform location stream (permission must already be granted by the app),
  tracking modes with gesture dismissal, `requestMyLocationLatLng`.
- Ornaments: compass (tap resets north), attribution (per-source strings from
  the style), MapLibre wordmark, all four corner positions plus margins.
- HTTP: all engine traffic through Dart's HTTP stack; per-map
  `setCustomHeaders` and process-global
  `MapLibreGlNative.setGlobalHttpHeaders`.
- Cache/network: persistent tile cache database in the app cache directory,
  `invalidateAmbientCache`/`clearAmbientCache`, `forceOnlineMode`,
  `setMaximumFps` (engine-isolate mode).
- Snapshots: `takeSnapshot()` renders an offscreen still image (static-mode
  map sharing the live GPU context) and returns PNG bytes.
- Offline regions: full engine plumbing plus the package-level
  `MapLibreGlNativeOffline` API mirroring `global.dart` (download with
  progress events, list, merge, metadata, status, pause/resume, delete,
  `setOffline`). The standard `global.dart` functions still reach the
  method-channel backends until the global-channel seam PR lands.

Known gaps: explicit `takeSnapshot(width:, height:)` sizes render at the
current surface size; `setOfflineTileCountLimit` and
`setOfflineMaxConcurrentRequests` have no C API counterpart (no-ops); no RTL
text plugin API upstream; `onFeatureHover`/mouse events are web-only; an
animated GIF image source renders only its first frame (parity with the
platform backends: animate by cycling `updateImageSource` with per-frame
images).

Run the full example gallery on this backend with:

```sh
cd maplibre_gl_example
flutter run -t lib/main_ffi.dart
```
