# Upstream proposals for maplibre-native-ffi (DRAFT, not sent)

Drafted from the flutter-maplibre-gl FFI spike (`spike/native-ffi-android`,
see `docs/rfc-native-ffi-engine.md`). Each item is written so it can be
turned into a standalone upstream issue/PR. Sending anything upstream is a
maintainer decision; nothing here has been posted.

Context for all items: the spike drives the C API from Dart on Android,
rendering into a Flutter external texture, behind the unchanged
flutter-maplibre-gl public API. Pinned upstream: branch `dart` (PR #187) at
`9b2934e`.

## 1. Prefix matching for Dart queued resource provider routes

**Status: local patch exists**
(`maplibre_gl_native/upstream_patches/0001-dart-shim-prefix-route-match.patch`).

`mln_dart_queued_resource_provider_route.url` is matched with exact string
equality (`dart_shim.cpp`, `request_matches_route`). A provider that wants to
serve tiles/glyphs/sprites cannot enumerate those URLs up front, so exact
matching makes the queued provider unusable for the most important resource
kinds. The patch treats a route URL ending in `*` as a prefix match
(`https://*` claims all HTTPS traffic). Glob or regex matching would also
work; prefix is the minimal useful semantic.

Motivating use case: routing all engine networking through Dart's HTTP stack.
This proved necessary in practice (see item 4) and is also the natural seam
for per-app HTTP headers.

## 2. Owner-thread rebind API

**Status: REQUIRED for Dart isolate embedding; working local patch exists**
(`maplibre_gl_native/upstream_patches/0002-runtime-rebind-thread.patch`,
C API + module helpers + Dart binding wrapper).

Reproduction data: on a physical Android device the Dart VM resumed the
engine isolate on a different OS thread within one second of bootstrap
(observed via a `gettid` watchdog), and every subsequent call failed with
`MLN_STATUS_WRONG_THREAD`; a synthetic probe that never returned from its
entrypoint had shown a stable thread for 5 minutes, so the migration depends
on scheduling load and cannot be designed around. With the patch, the driver
rebinds on thread change and the engine runs normally.

Runtime, map, projection, and render-session handles capture
`std::this_thread::get_id()` at creation and hard-fail with
`MLN_STATUS_WRONG_THREAD` from any other thread. This contract is fine for
embedders that own their threads (Kotlin single-thread dispatchers, host main
loops), but the Dart VM does not pin isolates to OS threads: a long-lived
background isolate may be resumed on a different pool thread after going idle
(dart-lang/sdk#46943). A Dart embedder that wants to drive the engine off the
UI thread therefore has no thread it can legally promise.

The patch implements:

```c
/* Rebinds the runtime and every handle owned by it (maps, projections,
 * render sessions) to the calling thread. Must not be called while any
 * call on the runtime or its handles is in flight. */
MLN_API mln_status mln_runtime_rebind_thread(mln_runtime* runtime);
```

- Updates `owner_thread` on the runtime, on its maps (filtered by runtime),
  and globally on projections and render sessions (they carry no owner link;
  the patch assumes a single live runtime, which upstream may want to lift by
  adding back-references).
- Re-registers the runtime's `mbgl::util::RunLoop` via
  `mbgl::Scheduler::SetCurrent` on the calling thread (the constructor
  registered it on the creating thread). The old thread's slot goes stale;
  only `create_runtime`'s "already has a scheduler" check could observe it.
- No GPU work needed: the OpenGL surface session already brackets every
  operation with `activate()`/`deactivate()` (save previous context, make
  current, restore), so no EGL context remains current on the old thread
  between calls.
- Open point to audit: any other thread-local or thread-cached state inside
  mbgl (e.g. JNI `JNIEnv` attachment for the Android TLS component) that a
  rebind would need to refresh.

The caller contract (single-threaded mutual exclusion, rebind only between
turns) matches exactly what a Dart isolate can guarantee.

## 3. Runtime wake callback (push instead of poll)

**Status: idea, no patch.**

`mln_runtime_run_once` + `mln_runtime_poll_event` force embedders into a
polling loop. The Flutter spike parks its frame ticker when the map is idle
and drains events on a 100 ms timer; that is wasted wakeups at idle and up to
100 ms of added latency on network-driven updates.

Proposal: a callback invoked (from any thread) whenever work or an event is
enqueued while the runtime may be idle:

```c
typedef void (*mln_runtime_wake_callback)(void* user_data);
MLN_API mln_status mln_runtime_set_wake_callback(
  mln_runtime* runtime, mln_runtime_wake_callback callback, void* user_data);
```

Dart maps this 1:1 onto `NativeCallable.listener` (as the queued resource
provider already does), Kotlin onto a coroutine resume, etc. The embedder
then only pumps when woken.

## 4. rustls-platform-verifier "Revoked" failure on some Android devices

**Status: needs a reproduction report.**

On a Xiaomi 11 Lite 5G NE (Android 14, MIUI), every HTTPS request from the
built-in Rust HTTP client fails TLS verification with
`invalid peer certificate: Revoked` (rustls-platform-verifier, Android
component 0.1.1), for both `demotiles.maplibre.org` and
`tiles.openfreemap.org`. Device clock, proxy, and DNS were checked clean; the
same hosts load fine in on-device browsers and via Dart's HTTP stack. Checked
server-side too: the current `*.maplibre.org` leaf (Google Trust Services WE1,
issued 2026-07-06) is NOT in the CA's CRL (`c.pki.goog/we1`, 3 entries), so
the "Revoked" verdict is wrong on this device. The spike bypasses the issue
entirely with a Dart resource provider (items 1-2 and 9), but non-Flutter
consumers keep the Rust client, so an emulator/stock-Android reproduction and
an upstream issue are worth doing.

## 5. Packaging friction (for the PR #187 discussion)

- The ffigen output (`maplibre_native_c.g.dart`) is gitignored; a published
  Dart package must vendor it so `pub get` suffices.
- The `rustls-platform-verifier` Android component (9 KB AAR) is not on Maven
  Central; consumers must vendor it. Publishing it (or documenting the
  vendoring step) unblocks Android embedders.
- The Android build needs `rustup target add aarch64-linux-android` on top of
  `mise install`; worth adding to the mise setup or docs.
- No binary releases yet: every consumer builds the C++ core from source.
  A CI release pipeline per target (the platform list already exists) is the
  single biggest enabler for downstream packaging (Dart build hooks would
  download + checksum-verify these).

## 6. Surface swap on a live render session

**Status: working local patch
(`upstream_patches/0003-render-session-replace-surface.patch`), verified on
device (Android rotation now keeps the map fully rendered; before the patch
it visibly re-rendered from scratch).**

Surface render sessions cannot survive a native surface change today:

- `mln_render_session_resize` resizes in place but only over the **same**
  native surface.
- `mln_render_session_detach` keeps the handle live "for destruction" only;
  there is no re-attach.
- The only way to point a map at a new surface is
  `mln_map_attach_{opengl,vulkan}_surface`, which creates a **new session and
  a new renderer**, dropping every GPU-side resource (uploaded tile textures,
  glyph atlas, symbol buffers).

On Android this matters more than it sounds: Flutter's
`SurfaceProducer.setSize()` recreates the underlying `Surface` (ImageReader
backed under Impeller), and device rotation recreates it too, so an embedder
can never actually use `mln_render_session_resize`. Every geometry change
becomes a full session teardown, visible as the map re-rendering from scratch
for a few frames (background first, then cheap layers, then tiles popping
back in) even though all tile data is still in memory.

Proposal (implemented by the local patch as a two-call API, because Vulkan
mandates that a swapchain is destroyed before the surface it was created on,
and the embedder owns the surface):

- `mln_render_session_release_surface(session)`: destroys the presentation
  objects bound to the current native surface (swapchain, render pass,
  framebuffers) while keeping the renderer; the session suspends (render and
  resize return `MLN_STATUS_INVALID_STATE`) and the host may then destroy the
  native surface it lent.
- `mln_render_session_replace_surface(session, surface, width, height,
  scale_factor)`: adopts a new native surface of the same backend kind and
  rebuilds the presentation objects at the new extent.

This mirrors what the MapLibre Android SDK does internally on
`surfaceChanged` (the renderer survives; only the window surface is rebound).
Backend-wise the resources belong to the `VkDevice` / EGL context, not to the
swapchain / window surface. Implementation notes from the patch:

- The renderer is kept unless `scale_factor` changes (the pixel ratio is
  baked into `mbgl::Renderer` at construction).
- Pipelines created against the old `VkRenderPass` stay valid because the
  rebuilt pass has identical formats/attachments (render-pass compatibility);
  the core already relies on this in
  `SurfaceRenderableResource::recreateSwapchain`.
- For OpenGL the swap is trivial: the surface handle is only used by value
  inside `activate()`/`swap_surface()` and nothing stays bound between calls.
- Metal keeps returning `MLN_STATUS_UNSUPPORTED` (untested here).

## 7. Whole-style JSON getter

**Status: working local patch
(`upstream_patches/0004-map-copy-style-json.patch`).**

The C API exposes `mln_map_set_style_json` but no way to read the current
style back. Embedders that wrap an existing map API with a `getStyle()`
method (flutter-maplibre-gl, the MapLibre Android SDK's `Style#getJson`)
need the inverse. The core already has it: `mbgl::style::Style::getJSON()`.

The patch adds:

```c
MLN_API mln_status mln_map_copy_style_json(
  mln_map* map, char* out_json, size_t json_capacity, size_t* out_json_size
) MLN_NOEXCEPT;
```

following the existing caller-owned-buffer copy convention
(`mln_map_copy_style_source_attribution`), with a zero-capacity call as an
explicit size query, plus a `MapHandle.getStyleJson()` Dart wrapper.

## 8. Location indicator sets `location` in the wrong axis order (bug)

`mln_map_set_location_indicator_location` builds the layer's `location`
property as `[longitude, latitude, altitude]` (GeoJSON order). The
location-indicator style-spec property is `[latitude, longitude, altitude]`,
and `RenderLocationIndicatorLayer::evaluate()` reads `pos[0]` as latitude:

```cpp
const std::array<double, 3> pos = evaluated.get<style::Location>();
renderImpl->parameters.puckPosition = LatLng{pos[0], pos[1]};
```

The result is a puck silently rendered at transposed coordinates, which
looks like "the location indicator does not render at all" as soon as a
real position is set (the swap is only invisible at Null Island). Patched
locally by emitting latitude first (patch 0005); the fix belongs upstream
in `src/map/map.cpp`.

## 9. Scheme-alias URLs bypass custom resource providers (bug)

**Status: fixed locally by `0006-canonicalize-url-before-custom-provider.patch`.**

Custom-provider route matching happens on the RAW resource URL, but
`OnlineFileSource::request` canonicalizes scheme-alias URLs (per-kind
`util::mapbox::normalize*URL`, e.g. `maplibre://tiles` ->
`https://demotiles.maplibre.org/tiles/tiles.json`) only AFTER the provider
declined. A provider registered for `http://*` + `https://*` therefore never
sees alias URLs: they silently fall through to the built-in Rust HTTP client.
Found because the demotiles style references its vector source as
`maplibre://tiles`; on the device of item 4 that single fallback request
failed TLS verification ("Failed to load source maplibre: invalid peer
certificate: Revoked") while every other request of the same style flowed
through the Dart provider. Worse, the built-in client retries connection
errors internally (exponential backoff), so one fallen-through request stays
on the Rust client until the style reloads. The fix mirrors the
`OnlineFileSource::request` normalization switch before provider dispatch so
providers always see the canonical URL.
## 10. Style transition options are not exposed (placement cross-fade)

**Status: local patch exists (`upstream_patches/0007-style-transition-options.patch`).**

The C API has no equivalent of `mbgl::style::Style::setTransitionOptions`,
which the Android SDK exposes as `Style.setTransition(TransitionOptions)`.
Its `enablePlacementTransitions` flag is the only way to turn off the ~300ms
symbol placement cross-fade, and that matters for any embedder implementing
feature dragging: with the fade on, a dragged symbol visibly trails its
GeoJSON position on every per-move source update. The patch adds

```c
MLN_API mln_status mln_map_set_style_transition_options(
  mln_map* map, double duration_ms, double delay_ms,
  bool enable_placement_transitions);
```

(negative duration/delay leave the style defaults untouched) plus the Dart
wrapper. The Flutter spike disables placement transitions on feature-drag
start and restores them on drag end.

## 11. Gesture-in-progress flag is not exposed

**Status: local patch exists
(`upstream_patches/0008-map-set-gesture-in-progress.patch`).**

`mbgl::Map::setGestureInProgress(bool)` has no C API counterpart. The native
SDKs bracket every touch gesture with it (Android:
`Transform.setGestureInProgress` from `MapGestureDetector.onTouchEvent`), so
the core knows a live gesture is feeding camera writes: it keeps transition
state coherent and defers camera-idle reporting. An embedder implementing
gestures on top of the C API (like the Flutter FFI backend, which drives
`moveBy`/`scaleBy`/`jumpTo` from Flutter recognizers) currently cannot set
it. Everything works without it, but a

```c
MLN_API mln_status mln_map_set_gesture_in_progress(mln_map* map, bool value);
```

would close the last semantic difference with the platform SDK gesture
stacks.
