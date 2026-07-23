# FFI Engine: Spike -> Stable, full API expansion plan

## Context

The spike on `spike/native-ffi-android` passed every exit criterion (remote style, ~90 fps gestures on a render isolate, Vulkan, rotation/resize via surface-replace patch, hot restart). Goal now: expand from the spike subset toward the full `MapLibrePlatform` contract so real apps work unchanged (annotation managers, feature interaction, style mutation), moving the backend toward stable (M1). Confirmed scope: core phases + location component + ornaments + offline; the global-channel seam fix is deferred to a separate PR against main.

**Feasibility verdict: YES.** Three parallel inventories (platform contract, current coverage, bindings surface) established that the pinned bindings (`9b2934e` + 3 local patches) wrap 100% of the C API; every gap except `getStyle` maps onto existing, already-wrapped functions. The work is dominated by protocol plumbing (command/query types + engine-core cases + platform overrides), not by native or upstream work.

## Ground truth (from the 3 inventories)

- Parity surface: 70 `MapLibrePlatform` methods + 17 event callbacks + 15 `global.dart` functions (separate global MethodChannel that a Dart backend cannot intercept).
- Current FFI coverage: camera/projection/setStyle/add+remove sources+layers/click events implemented; ~45 loud `UnimplementedError` stubs.
- Bindings: feature queries + feature state live on `RenderSessionHandle`; bounds+min/max zoom+pitch = `MapHandle.setBounds(BoundOptions)`; images = `setStyleImage(PremultipliedRgba8Image, sdf)`; snapshot = `readPremultipliedRgba8()`; offline = complete async start/take API on `RuntimeHandle` + runtime events; ambient cache ops = `runAmbientCacheOperation` (RESET/PACK/INVALIDATE/CLEAR); network toggle = `Maplibre.setNetworkStatus`; `location-indicator` layer fully supported incl. bearing/accuracy/image setters; `mln_camera_options` has `padding` (edge insets) -> content insets. Style ops are JSON-only (fine: our layer adders already build style-spec JSON).

## Critical issues found (multi-angle check) and their fixes

1. **FFI-backed objects can't cross the isolate boundary** (`QueriedFeature`, `JsonValue`). Fix: serialize to plain JSON strings/maps inside `engine_core.dart`; `jsonValueToDart` in `json_convert.dart` exists, unused, ready.
2. **`QueriedFeature` has no `layerId`, but `feature#onTap` payload requires it.** Fix: engine-side ordered hit-test (one query per interactive layer, topmost-first, first hit wins) inside a single `QueryTopFeatureQuery` handler; 1 isolate round-trip, not N.
3. **`addImage` receives encoded PNG; native wants raw premultiplied RGBA.** Fix: decode on the presentation side with `dart:ui` (`instantiateImageCodec` -> `toByteData(rawRgba)`), send raw pixels + dims over the protocol. MUST verify premultiplication with a semi-transparent icon (rawRgba may be straight alpha -> premultiply manually).
4. **No `mln_map_get_style_json` in the C API** (only set). Fix: upstream patch `0004-map-get-style-json.patch` (trivial, mirrors existing `get_style_layer_json` pattern: `style().getJSON()` + status_boundary + header + Dart wrapper). Rebuild .so with the known worktree patch-isolation procedure (commit --no-verify because of dprint hook).
5. **`global.dart` bypasses `MapLibrePlatform`** (offline, global setHttpHeaders). Decision: seam fix deferred to a separate PR against main. Now: package-level APIs on `maplibre_gl_native` (`MapLibreGlNative.setGlobalHttpHeaders(...)`, `MapLibreGlNativeOffline.*` mirroring `global.dart` signatures) so capability lands; standard routing bolts on later.
6. **`setFeatureForGeoJsonSource` (annotation drag fast path) would resend whole collections.** Fix: engine-side per-source GeoJSON cache; only the single patched feature crosses the boundary; engine merges by feature id and calls `setGeojsonSourceData`. Cache dropped on removeSource/setStyle.
7. **Runtime cache is `:memory:`** -> ambient-cache ops and offline would be meaningless. Fix (phase 4, prerequisite for offline): `getCacheDir` on the existing texture-bridge channel -> `RuntimeOptions(cachePath: <cacheDir>/maplibre_ffi_cache.db)`.
8. **Drag trigger parity risk**: method-channel Android starts drags from a touch on a draggable feature. Fix: hit-test draggable interactive layers on pan-start (`properties['draggable'] == true` + widget `dragEnabled`), capture the pan into a drag session emitting `start/drag/end` (exact `DragEventType` names). Tune on device.
9. **`setOfflineMaxConcurrentRequests` has no C API** -> no-op with debug log, documented.
10. **No RTL text plugin API upstream** -> document limitation (README + RFC).
11. **Feature-state APIs throw on current native backends but ARE supported by our bindings** -> implement them (a parity improvement over method-channel).
12. **Exhaustive switch in `engine_core.dart`**: every new message type must be added in protocol + core + platform together or it fails at runtime. Mitigation: each phase lands all three layers together + analyzer + on-device smoke test before the next phase.

## Implementation phases

All protocol work follows the established pattern: new types in `maplibre_gl_native/lib/src/engine_protocol.dart` (isolate-sendable fields only) -> cases in `engine_core.dart` -> overrides in `ffi_platform.dart` (removing stubs from `MapLibreFfiPlatformBase` coverage). Widget work in `ffi_map_view.dart`.

### Phase 0: persist this plan
This document (`docs/ffi-api-expansion-plan.md`), linked from the RFC roadmap section. Done.

### Phase 1: style mutation + introspection + camera constraints (unblocks annotation managers)
- Commands: `SetGeoJsonSourceCommand(sourceId, data)`, `SetGeoJsonFeatureCommand(sourceId, featureJson)` (engine-side cache merge), `SetLayerPropertiesCommand(layerId, props)` (iterate `setLayerProperty`; single accessor covers paint AND layout, no split needed), `SetFilterCommand`, `SetLayerVisibilityCommand`, `SetBoundsCommand(bounds?, minZoom?, maxZoom?, minPitch?, maxPitch?)`, `SetCameraPaddingCommand(insets, animated)`.
- Queries: `GetLayerIdsQuery`, `GetSourceIdsQuery`, `GetFilterQuery`, `GetLayerPropertyQuery` (for `getLayerVisibility`), `GetStyleQuery` (needs patch 0004).
- Platform overrides: `setGeoJsonSource`, `setFeatureForGeoJsonSource`, `editGeoJsonSource`, `editGeoJsonUrl` (`setGeojsonSourceUrl`), `addSource(SourceProperties)` (toJson -> AddSourceJsonCommand), `setLayerProperties`, `setLayerVisibility`, `getLayerVisibility`, `setFilter`/`getFilter`/`setLayerFilter`, `getLayerIds`, `getSourceIds`, `getStyle`, `setCameraBounds`, `updateContentInsets`; extend `updateMapOptions` (`cameraTargetBounds`, `minMaxZoomPreference`).
- Patch 0004 + .so rebuild + ffigen regen + README/proposals-doc entries.

### Phase 2: images and image sources
- Presentation-side PNG decode helper (dart:ui) -> `AddStyleImageCommand(name, rgba, width, height, pixelRatio, sdf)`.
- `addImage`, `addImageSource`/`updateImageSource` (`add/set_image_source_image` + `set_image_source_coordinates`), `addLayer`/`addLayerBelow` (raster layer JSON over the image source).
- Premultiplication verification test (translucent icon on device).

### Phase 3: feature queries, interaction, feature state
- Queries: `QueryRenderedFeaturesQuery` (point or rect geometry, layerIds, filter), `QuerySourceFeaturesQuery`, `QueryTopFeatureQuery` (ordered hit-test, returns layerId + feature JSON), feature-state set/get/remove messages.
- Platform: `queryRenderedFeatures`, `queryRenderedFeaturesInRect`, `querySourceFeatures`, `setFeatureState`/`getFeatureState`/`removeFeatureState`.
- Interaction: registry of interactive layer ids (honor `enableInteraction` on all vector layer adders); tap handler in `ffi_map_view.dart` hit-tests before emitting map click; emit `onFeatureTappedPlatform` `{id, point, latLng, layerId}`; honor `featureTapsTriggersMapClick`.
- Drag plumbing per critical issue 8 -> `onFeatureDraggedPlatform` with `eventType` in {start, drag, end}. This makes `click_annotations` and draggable symbols work.

### Phase 4: HTTP headers, cache, network, fps
- `HttpResourceProvider`: headers map + URL-filter regex list applied in `_fetch`; `SetHttpHeadersCommand` (engine-level, provider lives engine-side).
- Platform: `setCustomHeaders`/`getCustomHeaders`; package-level `MapLibreGlNative.setGlobalHttpHeaders()` (documented stand-in for `global.dart` until the seam PR).
- Persistent cache path via new `getCacheDir` bridge method; `RunAmbientCacheOperationCommand` -> `invalidateAmbientCache` (INVALIDATE), `clearAmbientCache` (CLEAR).
- `forceOnlineMode` -> `Maplibre.setNetworkStatus(online)`; `setMaximumFps` -> command adjusting the engine driver frame timer (isolate host) / ticker gate (local host).

### Phase 5: snapshot + language + leftovers
- `TakeSnapshotQuery` -> engine `readPremultipliedRgba8()` -> bytes+info across boundary -> PNG encode presentation-side (`decodeImageFromPixels` -> `toByteData(png)`). MVP at current surface size; explicit width/height offscreen render deferred (note in docs).
- `setMapLanguage` + `matchMapLanguageWithDeviceDefault`: Dart reimplementation over `getLayerIds` + `getLayerProperty('text-field')` + `setLayerProperty`, adapting `["get","name*"]` expressions like the Android impl; device locale via `Platform.localeName`.
- Parity no-ops: `waitUntilMapIsIdleAfterMovement`, `waitUntilMapTilesAreLoaded` (native no-ops in method-channel too), `setWebMapToCustomSize` (return size unchanged).

### Phase 6: location component
- Kotlin: small location bridge on the existing plugin (LocationManager/fused; permission CHECK only, never request), streaming fixes to Dart.
- Engine commands: `AddLocationIndicatorCommand`, `SetLocationIndicatorCommand(location, bearing, accuracyRadius)`, puck images drawn in Dart (Canvas -> RGBA) and registered via phase-2 image path.
- Platform/widget: `myLocationEnabled`/`myLocationRenderMode` options, `updateMyLocationTrackingMode`, `requestMyLocationLatLng` (last fix), `onUserLocationUpdatedPlatform` (exact payload shape incl. timestamps in ms), tracking camera follow + `onCameraTrackingChanged`/`Dismissed` (dismiss on user gesture).

### Phase 7: ornaments (pure Flutter overlay in `FfiMapView`)
- Compass (rotates from camera events, tap -> bearing 0, honors `compassEnabled`/position/margins), attribution button (dialog fed by new `GetAttributionsQuery` -> per-source `copyStyleSourceAttribution`), scale bar (from metersPerPixel), logo placement.
- Honor the remaining `updateMapOptions` keys (positions/margins, `trackCameraPosition` gating of camera events).

### Phase 8: offline (package-level API, standard routing deferred to seam PR)
- Engine messages wrapping `RuntimeHandle` offline ops (create/list/get/merge/updateMetadata/status/downloadState/invalidate/delete) + take-result handles + runtime events (`offlineRegionStatusChanged`, response errors, tile-count-limit, operation-completed) -> progress stream over `EngineEvent`s.
- Public `MapLibreGlNativeOffline` mirroring `global.dart` signatures (`downloadOfflineRegion(definition, metadata, onEvent)`, `getListOfRegions`, `deleteOfflineRegion`, `mergeOfflineRegions`, `setOfflineTileCountLimit`, pause/resume via downloadState). `setOfflineMaxConcurrentRequests` = documented no-op (no C API).
- Adapted offline example page (the stock one calls `global.dart`, which still routes to the method channel until the seam PR).

### Cross-cutting (every phase)
- Update `maplibre_gl_native/README.md` spike-coverage section + RFC checklist as coverage grows; keep `docs/upstream-native-ffi-proposals.md` in sync (patch 0004).
- No commits/pushes without explicit per-action approval. No GitHub interactions. CHANGELOG untouched (branch not user-facing yet).

## Verification

- Per phase: `melos run analyze` + on-device smoke (profile build on the Xiaomi 11 Lite) of the EXISTING example pages that exercise that phase, unchanged: annotation managers + moving symbols (phase 1), `place_symbol`/custom marker (phase 2), `click_annotations` + drag (phase 3), custom tile-server headers (phase 4), snapshot page + language switch (phase 5), user-location page (phase 6), visual compass/scale/attribution check (phase 7), offline-regions page adapted (phase 8).
- End-to-end proof: new `main_ffi.dart` entry point in `maplibre_gl_example` that runs the FULL example gallery under `MapLibreGlNative.use()`; the "same API, new engine" claim tested against every page. (Historical note: during the spike the gallery entry point actually ran the since-retired single-isolate mode; the engine isolate has been the only architecture since the July 2026 consolidation.)
- Final pass: profile run confirming ~90 fps unchanged and stable memory over 10+ minutes (also closes the last spike exit criterion).
