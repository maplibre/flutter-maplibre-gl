# Native Dart style-image retention regression

This fixture uses the public Flutter API to reproduce a generated image becoming
eligible for native eviction after the style first requested its ID as missing.
It uses an inline background-only style, a generated blue square and one synthetic
GeoJSON point at `(0, 0)`. It needs no API key, remote tiles, glyphs, sprites,
location permission, customer data or network connection during execution.
Build dependencies must already be available or downloaded in the normal way.

## Run the fixture

Bootstrap this workspace as described in `CONTRIBUTING.md`, then run from
`maplibre_gl_example/` on an Android device/emulator or iOS device/simulator:

```sh
flutter test integration_test/style_image_retention_test.dart -d <device-id>
```

The file is also included in `integration_test/all_tests.dart`, which both native
CI jobs run. It is skipped on web because this regression concerns Native's
image manager and its removal callbacks.

## What the test does

1. Add a source and symbol layer referencing an ID that is not a bundled asset.
   Wait for a fresh map-idle callback and confirm the symbol is absent.
2. Register a generated PNG under that ID with `addImage` exactly once. Recreate
   the symbol layer to refresh layout, then require a rendered-feature hit at
   the synthetic point. This establishes that the late image really rendered.
3. Remove the symbol layer and the entire GeoJSON source, then confirm source
   removal. Move the empty map from zoom 3 to 4, wait for a fresh idle callback,
   pump frames for a bounded second, then move back to zoom 3 and wait for idle.
   These explicit native render passes avoid assuming that source removal alone
   emits an idle event and allow asynchronous tile teardown to finish.
4. Recreate the source and symbol layer without calling `addImage` again. Require
   the symbol to render using the retained image.

The assertion queries only a single centered symbol with overlap enabled, avoiding
collision ambiguity. It verifies an observable rendered symbol through the public
API; it does not directly inspect Native's image store or removal callback.

## Why this reaches native cleanup

The plugin currently pins Android Native `13.7.1` and iOS Native `7.0.0`. Native's
on-demand image cache accounts for the decoded RGBA image, not the compressed PNG.
Its default threshold is `100 * 8192` bytes (819,200 bytes). The test's one
512 by 512 image occupies 1,048,576 decoded bytes, exceeding that threshold.
`pixelRatio: 16` keeps its rendered size at 32 logical pixels without reducing the
decoded image-cache cost.

Native tracks an image in this cache when its ID was missing before registration.
Adding an image before the first layer requests it does not exercise that path.
When a requesting geometry tile is destroyed, Native unregisters that requestor.
Removing the source retires its tile cache as well; removing only a layer or
moving the camera can leave cached tile requestors alive. On a fully loaded frame
without transitions, the renderer checks the image-cache limit and proposes
unused requested images for removal. The retention fix rejects that proposal for
IDs registered from Dart in the current style.

Official Native source references:

- [iOS 7.0.0 cache threshold](https://github.com/maplibre/maplibre-native/blob/ios-v7.0.0/include/mln/util/constants.hpp)
- [iOS 7.0.0 image cache and requestor bookkeeping](https://github.com/maplibre/maplibre-native/blob/ios-v7.0.0/src/mln/renderer/image_manager.cpp)
- [Android 13.7.1 automatic cleanup and removed-source teardown](https://github.com/maplibre/maplibre-native/blob/android-v13.7.1/src/mln/renderer/render_orchestrator.cpp)
- [Android 13.7.1 geometry-tile destruction](https://github.com/maplibre/maplibre-native/blob/android-v13.7.1/src/mln/tile/geometry_tile.cpp)

`clearAmbientCache` and `setMaximumAmbientCacheSize` concern disk resources, so the
test does not use them to simulate image-memory pressure. No private SDK API,
additional plugin method or platform-specific memory-warning injection is needed.

## Observed baseline and patched results

The identical fixture was run in cold launches against the original controller
from upstream `1c20e9a` and the patched controller, keeping the SDK and fixture
unchanged:

| Target | Original controller | Patched controller |
| --- | --- | --- |
| Android 17, Pixel 7, Skia, Native 13.7.1 | Fails after source retirement | Passes |
| iOS 27.2, iPhone simulator, Native 7.0.0 | Fails after source retirement | Passes |

Both original builds passed the initial late-image render assertion. Both then
failed the final reuse assertion with:

```text
Timed out waiting for Dart image retained after native cache cleanup (last value: [])
```

Both patched builds completed all assertions. The baseline comparison temporarily
used the exact original platform controller; the corresponding retention patch
was restored afterwards. This checks the real native rendering path, independently
of the Java/Swift registry-policy unit tests. No raw logs, device identifiers or
customer data are included here.

## Verify the regression in another environment

Run this exact fixture with the original native image-removal behavior and with
the retention fix, using a cold application build for each. Preserve the fixture,
SDK versions and target type between runs. The original behavior must fail a
rendered-symbol assertion while the fix passes; a passing fixed build by itself
does not establish that the test exercises eviction. Record which assertion
failed, since late-image layout and post-retirement reuse are separate phases.

The fixture depends on the pinned SDK cache policy and bounded asynchronous
cleanup. Revisit its threshold and teardown assumptions when upgrading Native.
It does not cover image replacement, style-reload lifetime reset, OS memory
warnings, or visual pixel fidelity. Native policy unit tests cover bookkeeping
independently; this test covers the real Dart-to-Native render path.
