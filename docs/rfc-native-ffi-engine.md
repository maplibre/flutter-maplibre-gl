# RFC: MapLibre Native FFI engine for flutter-maplibre-gl

- Status: Draft
- Author: Gabriel Palmisano ([@gabbopalma](https://github.com/gabbopalma))
- Created: 2026-07-11
- Discussion: TBD

## Summary

This RFC proposes evolving flutter-maplibre-gl from a platform-channel wrapper around the
MapLibre Android and iOS SDKs into a plugin backed directly by the MapLibre Native C++ core,
through the C ABI provided by [maplibre-native-ffi](https://github.com/maplibre/maplibre-native-ffi)
and its in-progress Dart bindings ([PR #187](https://github.com/maplibre/maplibre-native-ffi/pull/187)).

The key claim: this can be done **behind the existing public Dart API** ("same API, new engine"),
so existing users face no rewrite, while unlocking Linux, Windows, and macOS support that no
platform SDK can provide today.

An Android rendering spike accompanies this document (see [Spike results](#spike-results)).

## 1. Motivation

The current architecture has served well, but it carries structural costs that grow with every
feature:

1. **Duplicated native glue.** Every feature is implemented three times: Dart, Kotlin/Java
   (`MapLibreMapController.java`, ~2,800 LOC, 58 method-call cases), and Swift
   (`MapLibreMapController.swift`, ~2,300 LOC). Total: ~9,800 LOC of hand-written marshalling
   plus ~1,300 LOC of generated per-platform property converters. Bug fixes and features
   routinely land on one platform and not the other.
2. **No desktop support.** The Android/iOS SDKs do not exist on Linux, Windows, or macOS.
   MapLibre Native itself runs on all of them.
3. **Method-channel latency on hot paths.** Gestures, feature drag, and hover all pay an
   async serialization hop per event. Screen/coordinate conversions during a drag cannot be
   synchronous.
4. **Divergent behavior per platform.** Camera easing curves, gesture feel, ornament layout,
   and offline edge cases differ between Android and iOS because two different SDK stacks
   implement them (see the `CameraAnimationInterpolation` doc comments admitting per-platform
   limitations).
5. **Two upstream SDK release trains** (android-sdk 13.x, ios 6.x) to track, each wrapping the
   same C++ core we could target once.

## 2. Current state of the plugin

Facts that shape the proposal (verified against `main` at the time of writing):

- **The backend seam already exists.** `MapLibrePlatform` is an abstract class of ~90 methods
  with a settable factory, `MapLibrePlatform.createInstance`
  (`maplibre_gl_platform_interface/lib/src/maplibre_gl_platform_interface.dart`).
  `maplibre_gl_web` proves a non-platform-view backend is a drop-in: its `buildView` returns an
  `HtmlElementView` and synthesizes the "platform view created" id. An FFI backend returning a
  `Texture`-based widget can do exactly the same. No breaking interface change is needed.
- **Annotations are already pure Dart.** `Symbol`/`Line`/`Circle`/`Fill` managers
  (`maplibre_gl/lib/src/annotation_manager.dart`) are implemented over generic GeoJSON sources
  and style layers, not over the SDK annotation plugins. They port to any backend unchanged.
- **Style property code is generated** from the style spec (`scripts/`, Mustache templates)
  for Dart, Java, and Swift. The Dart half is reusable as-is; the Java/Swift halves disappear
  with the native glue.
- **One real abstraction leak:** `maplibre_gl/lib/src/global.dart` (offline regions, global
  HTTP headers) bypasses `MapLibrePlatform` and talks to a global `MethodChannel` directly.
  A small `OfflineGlobalPlatform` seam must be introduced before any alternative backend can
  implement offline. Public function signatures stay identical.
- **Web is out of scope for FFI** and stays as-is: the C++ core does not run on the web;
  `maplibre_gl_web` (~11k LOC over maplibre-gl-js) remains the web backend behind the same
  interface.

## 3. maplibre-native-ffi and the Dart bindings (PR #187)

[maplibre-native-ffi](https://github.com/maplibre/maplibre-native-ffi) is a MapLibre-org
project (primary author: [@sargunv](https://github.com/sargunv)) exposing a C ABI over the
MapLibre Native C++ core, exactly so that language bindings and host integrations do not need
C++ interop.

**What it covers** (headers under `include/maplibre_native_c/`): runtime and event loop,
map lifecycle, full style CRUD (`style.h` is the largest header), camera, feature/geometry
query, projection, feature state, offline, resource provider hooks (custom HTTP), logging,
and, crucially, **rendering**:

- `texture.h`: render-to-texture sessions with owned/borrowed texture variants for **Metal,
  Vulkan, and OpenGL**, an acquire-frame/release-frame loop, and CPU readback
  (`mln_texture_read_premultiplied_rgba8`).
- `surface.h` / `render_session.h` / `render_target.h`: on-screen surface rendering.
- The embedder drives the render loop. There is deliberately **no gesture/input/widget layer**;
  each host supplies its own.

**Platform targets:** Linux x64/arm64, macOS, Windows x64/arm64, Android, iOS, OpenHarmony.
Existing bindings: C#, Go, Kotlin, Python, Rust, Swift, Zig.

**Current limitations, stated plainly:**

- Pre-1.0: the C ABI is explicitly unstable (`mln_c_version()` returns 0).
- No binary release pipeline yet; consumers build from source (CMake/mise).
- Advanced extension APIs (custom layers, shader registry) are not yet exposed.

**PR #187 (Dart bindings, draft, +12k LOC)** delivers the pure-Dart half: ffigen-generated raw
bindings plus hand-written idiomatic wrappers (camera/map/style/offline/render/runtime/query/
projection/resource modules), isolate-aware callback lifecycle, arena memory management, and
status-to-exception mapping. What it does **not** deliver is the Flutter half: no `Texture`
bridge, no gesture layer, no widget, no build-hooks packaging (the library is loaded via
environment variables). That Flutter half is exactly what this proposal contributes.

## 4. Options considered

### Option A: FFI backend behind the existing API (evolutionary)

Add a new endorsed package implementing `MapLibrePlatform` over the C bindings. Desktop first
(purely additive, zero risk for mobile users), mobile opt-in later, mobile default only after
parity gates pass.

- Pros: no user migration; incremental; reversible at every step; deletes ~10k LOC of glue at
  the end.
- Cons: the old API's warts survive (dynamic-typed properties, Mapbox-era leftovers); some
  methods become no-ops.

### Option B: clean-slate package with a new API

Rejected. A modern rewrite already exists in the ecosystem
([josxha/flutter-maplibre](https://github.com/josxha/flutter-maplibre), `maplibre` on pub.dev,
built on jnigen/ffigen over the platform SDKs). If flutter-maplibre-gl forced its users through
a full API migration, the switching cost to any other package would be identical, and the
Flutter/MapLibre community is too small to sustain a third API. Maintainer attention is the
scarcest resource we have.

### Prior art: the flutter-native-interop-playground

[maplibre/flutter-native-interop-playground](https://github.com/maplibre/flutter-native-interop-playground)
(namespace `com.kekland.flmln`) is a separate FFI proof-of-concept worth comparing against,
since it renders MapLibre Native into a Flutter `Texture` via `dart:ffi` like this proposal.
The two share only that premise; the approaches diverge sharply:

- **C bindings.** The playground *forks and recompiles* maplibre-native: a custom Python
  libclang generator (`tool/generate_cpp_ffi.py`) parses the C++ `mbgl::` headers and emits a
  bespoke C layer (`flmln_ffi_gen.*` plus hand-written wrappers) that is copied into the
  upstream tree and built as `libflmln.so`. This proposal instead consumes the upstream
  `maplibre-native-ffi` C ABI (section 3) and keeps its divergences as discrete, upstream-bound
  patches, not a fork.
- **Threading.** The playground drives rendering from the widget `build()` on the UI isolate
  (GL only; Vulkan is a `// TODO`). This proposal splits presentation from a native-owning
  engine behind a sendable message protocol, with an optional dedicated render isolate
  (section 5.1) and EGL+Vulkan support.
- **HTTP, gestures, integration.** The playground uses the native Rust/OkHttp stack, delegates
  gestures to `flutter_map`, and exposes its own widget. This proposal routes HTTP through Dart
  (section 6), implements gestures in Dart, and stays behind the unchanged `maplibre_gl` API.

The one axis where the playground leads is a **generated, typed style DSL**
(`tool/generate_style.dart` produces `FillLayer`, `PropertyValue.constant<T>`), whereas this
backend passes raw style-spec JSON with a hand-maintained layout/paint table (see the M1 item
in [Notable friction](#spike-results)). It is the concrete reference for that future work.

### Option C: shared engine layering

Structure the FFI work as an engine, not a product:

```
maplibre-native-ffi (C ABI, upstream)
  -> maplibre_native        pure Dart bindings (PR #187, upstream)
    -> maplibre_gl_native   Flutter integration: texture bridge, render loop,
                            gestures, ornaments (this repo)
      -> maplibre_gl        existing public API, unchanged for users
```

The engine layers contain no opinionated public API, so other Flutter packages could adopt
them too. This RFC proposes **C combined with A**: build the engine layers, consume them behind
the existing API.

### Option D: modernize the current channels with Pigeon first

Rejected as a precursor. Migrating the 58 method cases plus event streams to Pigeon across
Dart/Kotlin/Swift is roughly 2-3 engineer-months of purely internal work, all of which the FFI
path deletes wholesale, and it brings neither desktop support nor less duplication. Pigeon
remains a sensible investment **only** in the fallback scenario where the FFI decision gates
fail and the plugin stays on the platform SDKs long-term. (The FFI backend itself keeps one
tiny platform channel, the per-platform texture shim with ~4 methods, where Pigeon is
irrelevant either way.)

## 5. Proposed architecture

### 5.1 New package: `maplibre_gl_native`

A new workspace package implementing `MapLibrePlatform` over `maplibre_native`:

- **Widget:** a `Texture`-based map view. `buildView` returns it and synthesizes the view id,
  following the `maplibre_gl_web` precedent.
- **Per-platform texture shim** (the only remaining native code, ~100-400 LOC per platform):
  registers an external texture with the engine's `TextureRegistry` and hands the render
  target to the FFI layer. "FFI-first" does not mean "zero native code"; it means the native
  code shrinks from ~10k LOC of API glue to a texture handshake.
- **Render loop in Dart:** the core is embedder-driven; a `Ticker` on Flutter's frame clock
  triggers renders when the map is dirty (core repaint callback, camera animation, active
  gesture). GPU work runs off the UI isolate; events come back via `NativeCallable.listener`.
- **Gesture layer in Dart:** pan/pinch/rotate/tilt/fling with inertia, built once, identical
  on all five platforms, including mouse wheel/trackpad/keyboard for desktop. Screen/LatLng
  conversions become synchronous FFI calls, removing the per-event channel hop.
- **Ornaments as Flutter widgets:** compass, scale bar, logo, and the legally required
  attribution, rendered in a `Stack` above the texture, consistent across platforms.

### 5.2 Backend selection

- Desktop (Linux/macOS/Windows): endorsed `default_package` in `maplibre_gl/pubspec.yaml`.
  Purely additive; Android/iOS users are untouched.
- Mobile: opt-in via a one-liner (`MapLibreGlNative.use()`) during a long bake period; the
  endorsed default flips only after parity gates pass; the current Java/Swift implementation
  is extracted to a legacy opt-out package for a deprecation window.

### 5.3 Binary distribution

- Contribute a release pipeline to maplibre-native-ffi publishing versioned, checksummed
  prebuilt libraries per target (Linux x64/arm64, Windows x64/arm64, macOS, Android ABIs,
  iOS xcframework).
- `maplibre_native` ships a `hook/build.dart` (Dart build hooks are stable since
  Dart 3.10 / Flutter 3.38) that downloads the pinned prebuilt by exact version and checksum,
  with opt-in build-from-source and local-dev overrides.
- ABI instability is absorbed at one point: `maplibre_native` pins an exact native artifact and
  vendors the matching generated bindings; a startup version assertion fails fast.

## 6. Gap analysis: the ~90-method `MapLibrePlatform` surface

**Bucket A: maps 1:1 onto the C API (~60 methods, low risk).** All style CRUD (sources,
the nine layer types, filters, images, visibility), GeoJSON source editing, feature state,
camera operations and queries, rendered/source feature queries, projection
(`toScreenLocation`/`toLatLng`/batch), snapshots (CPU readback, works at custom sizes),
idle/tile-loaded waits. The Dart annotation managers sit above these and need zero changes.

**Bucket B: reimplemented in Dart with the same signatures (~20 methods, the real work).**

- Location puck and tracking modes: no SDK `LocationComponent` anymore. Rebuilt as a Dart
  puck manager (position stream via e.g. geolocator, puck/accuracy as style layers, tracking
  camera follower). Largest single gap: ~1.5-2 engineer-months. Desktop simply reports
  location unavailable where the OS provides none.
- Offline: mapped onto the core offline API through a new `OfflineGlobalPlatform` seam
  replacing the `global.dart` direct channel. Same core database format as the SDKs; database
  path compatibility must be verified so existing downloads survive the switch.
- Custom HTTP headers: via the core resource-provider hook, finally identical across
  platforms (today: OkHttp interceptor vs URLProtocol hacks).
- Map language helpers: port of the pure-Dart implementation that already exists in
  `maplibre_gl_web`.
- Ornaments and their position/margin options: Flutter overlay widgets.

**Bucket C: no-ops or absorbed (~8 methods).** Telemetry getters/setters (no telemetry in the
core), `useHybridComposition`, `iosLongClickDuration` (superseded by Dart gesture config),
web-only sizing methods (already no-ops on mobile today), `translucentTextureSurface`
(textures are naturally alpha-capable).

## 7. Roadmap

| Milestone | Scope | Estimate |
|---|---|---|
| **M0: Spike (this document's companion)** | Android: styled map in a `Texture` widget via FFI, basic pan/zoom. Riskiest unknown first. | 1-2 months part-time |
| **M1: Desktop preview** | `maplibre_gl_native` with buckets A+C, full gesture layer, ornaments incl. attribution, Linux/macOS/Windows bridges, hooks-based binaries, endorsed desktop defaults. Ships as a minor release with desktop marked "preview". Zero mobile risk. | +3-5 EM |
| **M2: Mobile opt-in** | Android/iOS texture bridges, location puck, offline DB compatibility, dual-backend test matrix, published performance comparison. | +3-4 EM |
| **M3: Default switch** | Flip mobile defaults, legacy opt-out package, deprecate leaked API, delete ~10k LOC of native glue. | +2-3 EM over 2+ release cycles |

Total: roughly 10-14 engineer-months of focused work; realistically 12-18 calendar months at
open-source cadence.

The concrete API-expansion plan bridging M0 to M1 on Android (full `MapLibrePlatform`
coverage: style mutation, feature interaction, HTTP headers, snapshots, location component,
ornaments, offline) lives in [ffi-api-expansion-plan.md](ffi-api-expansion-plan.md).

## 8. Decision gates

Commitment beyond M0/M1 requires:

1. **Spike pass:** sustained smooth pan/zoom on mid-range Android hardware, correct DPR and
   resize, hot-restart safe, flat memory. (See results below.)
2. **ABI stability signal:** `mln_c_version()` >= 1 or a written upstream stability and
   deprecation policy.
3. **Binary release pipeline** upstream, consumable from Dart build hooks.
4. **PR #187 merged and published** as a MapLibre-org-owned pub.dev package, not a fork this
   repo must maintain.
5. **Upstream buy-in** from maplibre-native-ffi maintainers for the layering in section 5.
6. **Funding**: this scale of work will not happen on volunteer time alone; MapLibre's
   grant/bounty program is the natural fit for the engine layers.

If the gates fail: stay on the platform SDKs, consider the Pigeon modernization (Option D) as
an internal quality investment, and revisit when the ABI stabilizes.

## 9. Open questions

1. Should the Flutter engine layer (`maplibre_gl_native`'s texture bridge + gestures) live in
   this repo or upstream next to the Dart bindings, so non-maplibre_gl consumers can use it?
2. Offline database location defaults differ per SDK; what migration guarantees do we commit
   to for existing users' downloaded regions?
3. Graphics backend per platform: Vulkan vs OpenGL on Android/Linux (the current plugin pins
   the GL SDK variant; the core supports both). Which does upstream want to bless per target?
4. What is the deprecation story for API that cannot be honored by the core
   (telemetry, hybrid-composition toggles, platform-specific gesture tunables)?
5. Web stays on maplibre-gl-js indefinitely; is that acceptable long-term, or does a
   WASM-compiled core ever enter the picture?

## Spike results

Executed 2026-07-11 on this branch (`spike/native-ffi-android`), on a physical
Xiaomi 11 Lite 5G NE (Adreno 642L, Android 14, arm64), debug build, Flutter
3.41.4 / Dart 3.11.1, Impeller (Vulkan) enabled. Pinned upstream:
maplibre-native-ffi branch `dart` (PR #187) at `9b2934e`. The new code lives
in `maplibre_gl_native/`; through the render-isolate and Vulkan phases it
grew to ~3,500 LOC Dart + ~350 LOC Kotlin + ~210 LOC JNI/Vulkan C. The
app-facing page uses the **unchanged** `maplibre_gl` `MapLibreMap` widget
and controller.

After the spike passed, coverage was expanded toward the full
`MapLibrePlatform` contract (style mutation and introspection, images,
feature queries/taps/drag and feature state, HTTP headers, persistent tile
cache, offscreen snapshots, map language, location component, ornaments, and
package-level offline regions) following
[ffi-api-expansion-plan.md](ffi-api-expansion-plan.md); the maplibre_gl_native
README documents the current per-API status, and
`maplibre_gl_example/lib/main_ffi.dart` runs the full example gallery on the
FFI engine. A fourth local upstream patch (`0004-map-copy-style-json`) adds
the missing whole-style JSON getter.

**Confirmed working:**

- [x] **Styled map renders in a Flutter `Texture` via FFI only.** MapLibre
  Native core (OpenGL ES/EGL backend) renders into an EGL window surface over
  a `SurfaceProducer` surface; Flutter composites it as an external texture
  under Impeller/Vulkan. No MapLibre Android SDK involved. The EGL setup is
  pure Kotlin (`EGL14` native handles passed to Dart); the only JNI C at this
  stage was `mln_android_init` (~20 lines; the shim later grew a ~200-line
  Vulkan bootstrap, see the Vulkan backend note below).
- [x] **Event pipeline.** Runtime events (style loaded, camera, render
  frames, map idle, loading failures) polled in Dart and dispatched to the
  existing `MapLibrePlatform` callback sinks; `onStyleLoadedCallback` and
  `onMapClick` of the public widget fire as on the SDK backends.
- [x] **Style CRUD through the unchanged public API.**
  `controller.addGeoJsonSource(...)` and `controller.addCircleLayer(...)`
  work via `mln_map_add_style_source_json` / `mln_map_add_style_layer_json`.
- [x] **Synchronous projection.** Tap-to-coordinate uses `latLngForPixel` as
  a synchronous FFI call (no channel hop); values verified correct before and
  after camera moves.
- [x] **Pan gesture** (Flutter `GestureDetector` -> `mln_map_move_by` ->
  immediate re-render): correct direction and magnitude on device.
- [x] **Idle-parking render loop.** Ticker drives runtime pump + render only
  while work is pending, then parks and polls the event queue on a
  low-frequency timer; wakes on gestures/camera/network events. Keeps the UI
  thread frame-free when the map is idle.
- [x] **Binary size:** stripped `libmaplibre-native-c.so` (arm64, GL/EGL,
  RelWithDebInfo) is **13 MB**, comparable to the current SDK payloads. It
  links only Android system libraries (no `libc++_shared`).
- [x] Memory snapshot at idle (debug build): ~23 MB native heap,
  ~126 MB EGL/GPU tracked (debug + Impeller overhead included).
- [x] **Real remote styles with Dart-owned HTTP.** The built-in Rust HTTP
  client failed TLS verification on this device
  (`invalid peer certificate: Revoked` from rustls-platform-verifier 0.1.1,
  for both `tiles.openfreemap.org` and `demotiles.maplibre.org`; device
  clock/proxy/DNS checked clean, suspected verifier/device interaction).
  Resolved architecturally rather than debugged: a **Dart resource provider**
  (`mln_runtime_set_resource_provider` via the PR #187 queued-provider
  bindings) intercepts all http(s) requests and serves them with `dart:io`'s
  `HttpClient` (platform trust store, conditional requests via
  ETag/If-Modified-Since, cache-control mapping). OpenFreeMap Liberty renders
  fully on device: vector tiles, glyphs, and sprites all fetched by Dart,
  including on-demand tile loads while panning. This is the same seam that
  will serve `setHttpHeaders` and offline. One upstream gap: the queued
  provider matches route URLs **exactly only**, which cannot express "all
  tiles"; the spike carries a 15-line local patch adding trailing-`*` prefix
  matching (`upstream_patches/0001-dart-shim-prefix-route-match.patch` in
  `maplibre_gl_native/`), to be proposed upstream.
- [x] Pinch zoom, double-tap zoom, pan, rotate, and two-finger tilt (shove,
  with pinch/tilt mode disambiguation on the scale-gesture stream) verified
  manually on device. Rotate initially turned opposite to the fingers:
  Flutter's gesture rotation is positive clockwise while increasing
  MapLibre's bearing turns the map content counterclockwise; fixed by
  negating the delta (bearing sign conventions are exactly the kind of
  per-platform detail the Dart gesture layer centralizes). Gesture polish
  (inertia/fling, tunable thresholds) is deliberately deferred to M1.
- [x] Sustained fps measured on a profile build: ~90 fps (the device's
  display refresh rate) at every zoom level with the render isolate; see
  [Performance profiling](#performance-profiling) below.

**Verified only partially / open items:**

- [ ] The rustls-platform-verifier "Revoked" failure is bypassed, not
  root-caused; still worth an emulator/stock-Android repro and an upstream
  issue, since the Rust client remains the default for non-Flutter consumers.
- [x] Hot restart verified on device: the app restarts cleanly and the map
  comes back working (spike exit criterion passed). The old native runtime's
  memory is presumably still leaked across restarts (debug-time only; needs
  `NativeFinalizer` coverage upstream or explicit lifecycle handling before
  productization). A related developer-experience finding: hot *reload* of
  map callbacks passed as inline closures is stale by design in the plugin
  (`onPlatformViewCreated` captures them into final controller fields, and
  Dart hot reload never rewrites frozen closure bodies; method tear-offs
  reload fine). This affects the SDK backends identically and is fixable in
  `maplibre_gl` with the trampoline pattern `onStyleLoadedCallback` already
  uses; proposed as a separate small PR, independent of this RFC.
- [x] Resize and device rotation exercised manually on device: correct
  layout, DPR, and gestures afterwards; no crashes or stuck frames. A
  cosmetic limitation was observed on rotation: every native-surface change
  forced a full render-session teardown (the pinned C API cannot swap the
  surface of a live session, and Flutter's `SurfaceProducer.setSize()`
  recreates the `Surface`, so the in-place `mln_render_session_resize` is
  unreachable; notably even that in-place resize resets the renderer). The
  new session brings a new renderer, so GPU-side resources were rebuilt from
  in-memory map state and the map visibly re-rendered for a few frames
  (background, then cheap layers, then tiles), with no network refetch.
  **Fixed by a third local upstream patch**
  (`upstream_patches/0003-render-session-replace-surface.patch`):
  `mln_render_session_release_surface` + `mln_render_session_replace_surface`
  swap the native surface of a live session while keeping the renderer and
  every GPU-side resource, mirroring what the MapLibre Android SDK does
  internally on `surfaceChanged`. Release/replace are split because Vulkan
  mandates destroying the swapchain before the surface it was created on,
  and the embedder owns the surface; the engine's existing SurfaceLost ->
  barrier -> recreate flow already sequences this correctly across isolates.
  Proposed upstream as item 6 in `docs/upstream-native-ffi-proposals.md`.
  **User-verified on device (profile build): rotation now keeps the map fully
  rendered.** Logs show the expected one-off engine-frame spike per rotation
  (~160-330 ms: device waitIdle + swapchain rebuild + first full frame at the
  new extent), confined to the engine isolate; the UI thread is unaffected.
  The Adreno driver re-emits its benign 4x4 AHardwareBuffer format-probe
  errors on every swapchain rebuild (same noise as at Vulkan init).
- [ ] Background/foreground cycles: code paths implemented (`SurfaceProducer`
  callbacks, surface recreation) but not yet exercised systematically.

**Notable friction found (feeds the M1 plan):**

1. PR #187 does not commit the ffigen output; `maplibre_native_c.g.dart` must
   be generated (`mise run //bindings/dart:ffigen`). A published package must
   vendor it.
2. `rustls-platform-verifier`'s Android component is not on Maven Central; it
   ships inside the Rust crate and must be vendored (9 KB AAR) or published.
3. The upstream Android build needs `rustup target add aarch64-linux-android`
   on top of `mise install` (worth an upstream docs/CI fix).
4. Flutter tooling that waits for frame quiescence (flutter_driver) conflicts
   with a naive always-on render ticker; the idle-parking loop solves this
   and is the right design anyway.
5. The Dart queued resource provider only matches route URLs exactly, so a
   provider cannot claim URL families (tiles/glyphs/sprites). Prefix or glob
   matching is needed upstream (local patch in this branch).
6. Layers are added as raw style-spec JSON, and the flat maplibre_gl property
   maps are split into `layout`/`paint` objects via a hand-maintained key set
   (`maplibre_gl_native/lib/src/ffi_platform.dart`, `_layoutPropertyKeys`, with
   a `NOTE(spike)`). The long-term implementation should generate this table
   from the style spec in `scripts/`, the way the flutter-native-interop
   playground already generates its typed style DSL (see Option B prior art).
   Deferred to M1.

### Performance profiling

A DevTools profiling pass (debug build, Impeller/Vulkan, same device) during
sustained pan/zoom isolated the frame budget into two distinct jank sources,
one fixed in the spike and one structural.

**1. Camera-event flooding on the UI isolate (fixed).** During a continuous
pan/zoom the core emits a burst of `mapCameraIsChanging` runtime events, tens
per frame. The initial drain dispatched each one individually, allocating a
`RuntimeEvent` and invoking the Dart camera callback every time; the UI thread
hit ~24 ms/frame with the cost concentrated entirely in event draining, not
rendering. Since the callback just re-reads the current camera from the map,
the events are idempotent within a frame. Coalescing them to a single dispatch
at the end of each drain (`FfiEngine.pump`) removed this source: the drain
collapsed to a sliver and normal (no-tile) frames settled at ~5 ms UI / ~2 ms
raster. This is a pure Dart-layer win and is committed.

**2. `renderUpdate` cost on the UI isolate when tiles arrive (structural).**
The residual jank is a single `renderUpdate` FFI call spiking to **~14 ms**
(measured 13.9 ms) on frames where a batch of new tiles is integrated. Its
`Thread duration` is **0%**: the wall-clock is GPU/native work the UI thread
blocks on, not Dart CPU. Because this spike drives `renderUpdate` on the UI
isolate (mirroring the upstream android-map example), any heavy frame stalls
the UI thread for its full duration.

It scales with how much geometry each integrated tile carries, so it is
**more frequent at high zoom** (close-in): high-zoom tiles over a dense area
pack far more geometry, labels, and symbols (street names, POIs, house
numbers) than low-zoom tiles, and label placement/collision is among the
costliest render work. Panning while zoomed in keeps pulling in these
detail-heavy tiles, so the heavy `renderUpdate` frames arrive in bursts rather
than isolated, dropping sustained fps (observed ~77 vs ~88 average) and
producing brief but repeated UI stalls. This is not a Dart-fixable cost: it is
the consequence of rendering on the UI isolate.

**Implication for the architecture (section 5.1).** The right fix is to move
the runtime + map + render session onto a dedicated render isolate/thread (the
core is owner-thread affine, so the whole trio migrates together) and let the
UI isolate only present the resulting texture. That removes `renderUpdate`
from the UI thread entirely, so a heavy tile-integration frame no longer stalls
input regardless of how many tiles land. Section 5.1 already assumes GPU work
runs off the UI isolate; the spike deliberately kept everything on one isolate
to retire the rendering risk first, and this profiling is what turns "should
render off the UI isolate" into a measured, must-have requirement for M1/M2.

**Render-isolate feasibility checks (done before writing any code).** Three
facts now verified rather than assumed:

1. *The native affinity is per OS thread, checked explicitly.* Runtime, map,
   projection, and render-session handles capture `std::this_thread::get_id()`
   at creation and return `MLN_STATUS_WRONG_THREAD` from any other thread; a
   violation fails loudly as a Dart exception, never as UB. Surface sessions
   are affine to the **map owner** thread (`surface.h`), so runtime + map +
   session must migrate together, and a "map on UI, render elsewhere" split is
   not expressible with today's C API.
2. *EGL tolerates thread changes between calls.* The OpenGL surface session
   creates its own EGL context (the embedder context is only a share context)
   and brackets every operation with save-current / make-current / restore
   (`egl_context.cpp`, `activate()`/`deactivate()`), leaving no context bound
   between calls.
3. *A Dart background isolate stayed on one OS thread in practice.* The Dart
   VM does not guarantee isolate-to-thread pinning (dart-lang/sdk#46943), which
   would trip the checks in (1). A device probe
   (`maplibre_gl_example/lib/main_isolate_probe.dart`) mimicking the engine
   duty cycle (frame-paced busy work, 100 ms idle pump, 30 s fully-parked
   deep idle) observed **0 migrations over 5 cycles (~5 minutes)** on the test
   device (debug build). The engine isolate will keep a cheap `gettid()`
   watchdog so a migration is detected deterministically; the insurance if it
   ever fires is a small upstream `mln_runtime_rebind_thread` API (drafted with
   other upstream items in `docs/upstream-native-ffi-proposals.md`).

**Render isolate implemented and measured (phases 2-4).** The engine core
(runtime, maps, render sessions, the only code touching native handles) now
sits behind an isolate-sendable message protocol
(`engine_protocol.dart`/`engine_core.dart`), running on a dedicated isolate
(`engine_isolate.dart`) with a self-driving frame loop. During the spike a
single-isolate mode coexisted as `use(engineIsolate: false)` plus a silent
bootstrap fallback; after the July 2026 benchmark suite settled the question
(see `docs/ffi-benchmark-results-2026-07.md`) the isolate became the only
architecture and the fallback a loud error. Findings:

- **The VM thread-migration risk is real, not theoretical.** Despite the
  clean 5-minute probe, the real engine isolate was resumed on a different
  OS thread within a second of bootstrap, and every native call failed with
  `MLN_STATUS_WRONG_THREAD`. Solved with a second local upstream patch,
  `mln_runtime_rebind_thread`
  (`upstream_patches/0002-runtime-rebind-thread.patch`: owner-thread updates
  across runtime/maps/projections/sessions plus `mbgl::Scheduler` TLS
  re-registration, ~130 lines), invoked by a `gettid` watchdog before every
  engine turn. Rebinding is observed working in logs and costs one syscall
  per turn. This patch is a hard prerequisite for Dart-isolate embedding and
  is written up for upstreaming.
- **Frame pacing must be re-entrancy safe.** Engine events emitted during a
  render re-enter the driver's wake path; naively scheduling zero-delay
  timers there produced back-to-back renders that saturated the engine
  isolate and queued gesture commands behind renders (felt as laggy,
  delayed gestures). A re-entrancy guard restored correct pacing.
- **Result: sustained ~90 fps (the test device's display refresh rate) at
  every zoom level during continuous pan, with no jank**, versus ~77 fps
  with repeated multi-frame UI stalls in the single-isolate engine. Heavy
  tile-integration `renderUpdate` calls now run entirely off the UI thread;
  gesture latency through the SendPort hop is not perceptible.
- **Known residual (rare):** an occasional slow **raster** frame (~38 ms
  observed once in a ~45 s trace; UI thread at 0.2 ms in the same frame)
  spent inside Impeller GLES housekeeping
  (`ReactorGLES::React → ConsolidateHandles`), correlated with heavy tile
  uploads. Reading: the engine's EGL context (tile/glyph texture uploads on
  the engine thread) and Flutter's compositor GLES context contend inside
  the GPU driver, occasionally serializing the compositor's handle work
  behind ours. Not addressable from Dart; the structural mitigation is the
  Vulkan backend below.
- **Vulkan backend: working.** The same spike renders through MapLibre
  Native's Vulkan renderer (the backend the official MapLibre Android SDK
  ships as default): the upstream `android-arm64-vulkan` build variant, a
  ~200-line Vulkan bootstrap in the JNI shim (instance/device/queue plus a
  `VkSurfaceKHR` over the Flutter `SurfaceProducer` window; Android has no
  Java Vulkan API), and a backend-tagged session protocol. The Dart side
  auto-detects the compiled backend via
  `mln_supported_render_backend_mask`, so OpenGL/EGL remains a swap of the
  bundled binary for devices with weak Vulkan drivers. Style, tiles,
  gestures, and the engine isolate all worked unchanged on first run;
  stripped Vulkan library is ~15 MB (vs ~13 MB GL). This also removes the
  GLES driver-path sharing behind the residual raster spike above.
  A profile-build comparison on the test device showed **no perceptible fps
  difference** between the two backends (both sustain the ~90 fps display
  refresh with the render isolate): the motivation for shipping Vulkan is
  alignment with the upstream Android SDK's default backend and eliminating
  the compositor/engine GLES driver contention, not throughput.

**Verdict:** the core technical risk of the FFI plan (render-to-texture into
Flutter on Android, gesture-to-camera latency, event plumbing behind the
existing API, network resource loading, and UI-thread isolation of render
work) is **retired**. A real vector style
(OpenFreeMap Liberty) renders and interacts end-to-end on device with all
networking served from Dart. Profiling retired the frame-budget unknown too:
UI-isolate event flooding is fixed, and the remaining tile-integration stall is
understood and has a clear architectural fix (dedicated render isolate). The
remaining work is breadth (API coverage, location, offline, ornaments) and
packaging (build hooks + upstream binary releases).
