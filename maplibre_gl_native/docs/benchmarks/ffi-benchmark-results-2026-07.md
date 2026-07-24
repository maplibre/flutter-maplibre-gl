# FFI engine benchmark results (July 2026)

Full run of the methodology in `ffi-benchmarks.md`: 63 measured runs (3 engines x 7 scenarios x 3 iterations, offline on warmed caches, thermal status 0 throughout), Xiaomi 2109119DG (11 Lite 5G NE, 90 Hz, Android 14), profile mode, revision 5facad4. Raw data + full tables: `maplibre_gl_example/build/bench_results/full-2026-07-23/report.md`.

## Question 1: should `engineIsolate: true` be the default? YES

Same engine core and renderer on both FFI variants, so this comparison is confound-free. The dedicated engine isolate keeps the UI thread clean in every scenario:

| signal (worst scenarios) | ffi (single isolate) | ffi_isolate |
|---|---|---|
| UI build p90 during load | 10-22 ms (render runs on UI thread) | 0.2-0.9 ms |
| UI jank vs 90 Hz budget, camera orbit | 86-94 % | 2-5 % (stable: 1-5 %) |
| UI jank, tracking | 91 % | 16 % (stable: 8 %) |
| UI jank, dynamic data 2000 pts | 76 % | 12 % |

Costs of the isolate: RSS +1-5 %, process CPU a few points above single-isolate (still ~half of stable), query round trip ~0.1-0.2 ms vs ~0.01 ms direct (irrelevant at app level). No scenario favored the single-isolate engine.

## Question 2: how far is FFI (isolate) from stable, and in which direction?

**Where FFI wins big (the data pipeline and the API boundary):**

- `setGeoJsonSource`, 20k points: 1455 ms (stable) vs ~110-150 ms: **~10x**.
- Live updates at 30 Hz target: stable collapses past 500 points (9.2 updates/s at 2000 pts, per-update p50 108 ms, UI 100 % janky); FFI holds ~29.5 updates/s at 2000 pts, p50 6.7 ms, 1.2 % jank: **the** use case that justifies the FFI engine.
- API latency (p50): queryRenderedFeatures 0.41 ms -> 0.01 ms (local) / 0.12 ms (isolate); 100-point batch projection 0.89 ms -> 0.07/0.15 ms.
- Startup milestones: mapCreated ~250-320 ms -> ~90-115 ms; styleLoaded ~280-460 ms -> ~150-175 ms (Dart HTTP + no platform-view inflation).
- Process CPU: 38-59 % lower in 6 of 7 scenarios; RSS on par (world tour: -13-15 % for FFI).

**Where stable is still ahead (raw render throughput under interaction):**

- Map render rate during gestures: pan 65.5 vs 72.1 fps, pinch 70.0 vs 83.3, rotate 78.5 vs 85.4, fling 36.1 vs 41.9 (-8-16 %).
- Tracking (per-frame jumpTo): 63.8 vs 76.1 map fps (-16 %).
- World-tour fly-through: -4-11 % map fps depending on leg; UI-side spans remain comparable.

Likely contributors (not separable in this run): Vulkan-vs-OpenGL renderer confound, gestures handled in Dart vs natively, and the isolate's 8 ms timer-paced frame loop not being vsync-aligned on a 90 Hz panel. A vsync-driven frame pulse for the engine isolate is the most promising follow-up optimization.

## Post-optimization addendum (2026-07-23, revision 2ff8c6b)

The follow-up above was implemented (vsync-aligned engine frame loop via AChoreographer, gesture recognizer with map-tuned touch slop, ornament updates through `ValueNotifier`s) together with the consolidation to the isolate-only architecture. A second full suite (2 engines x 7 scenarios x 3 iterations, same device, same methodology; raw data: `maplibre_gl_example/build/bench_results/final-2026-07-23/report.md`) re-measured both engines; the stable engine reproduced its baseline numbers within noise, confirming comparability.

**The interaction gap is essentially closed.** Map render rate during gestures, ffi_isolate before -> after (stable, same suite):

| scenario | baseline | optimized | stable | vs stable |
|---|---|---|---|---|
| pan | 65.5 fps | 75.1 fps (+14.6 %) | 75.3 fps | -0.4 % |
| pinch | 70.0 fps | 80.0 fps (+14.4 %) | 87.8 fps | -8.8 % |
| rotate | 78.5 fps | 88.3 fps (+12.4 %) | 90.2 fps | -2.1 % |
| fling | 36.1 fps | 43.4 fps (+20.2 %) | 44.1 fps | -1.5 % |
| tracking | 63.8 fps | 79.7 fps (+24.8 %) | 80.4 fps | -0.9 % |

UI-thread jank on the FFI side dropped alongside (rotate 16.3 % -> 6.9 %, tracking 16.3 % -> 3.4 % of frames over the 11.1 ms budget); every data-pipeline win from the baseline run held or improved (e.g. dynamic 2000-point phase 58.5 -> 81.7 map fps). The remaining pinch gap is the one scenario still clearly behind stable and is left as follow-up (it shares the renderer confound noted above).

**Is the native choreographer pulse worth its complexity? Yes, measured.** A same-session A/B (gestures + tracking, 2 iterations each) forced the engine onto the pure-Dart refresh-rate-matched timer fallback (`--dart-define=MLN_FORCE_TIMER_PACING=true`) against the AChoreographer pulse:

| scenario (map fps) | choreographer | timer fallback | delta |
|---|---|---|---|
| pan | 75.0 | 51.9 | -30.8 % |
| pinch | 79.5 | 50.7 | -36.3 % |
| rotate | 88.2 | 59.4 | -32.6 % |
| fling | 44.4 | 29.3 | -34.1 % |
| tracking | 79.7 | 51.6 | -35.3 % |

UI jank more than doubled on the timer in every scenario. The mechanism: a timer at the display's refresh rate but with no phase relation to it drifts through the vsync period and systematically misses the frame-latch deadline, so rendered frames wait a full extra period to be composited. Phase alignment, not callback rate, is what the native pulse buys.

- `map_render_*` is not directly comparable across engines (stable reports the SDK's encoding+rendering split, FFI reports `renderUpdate` wall time); use it within-engine. Cross-engine conclusions above rest on frame *rates*, UI-thread timings, latencies, CPU, and RSS.
- `ui_fps` in static phases is meaningless for stable (the platform view renders outside Flutter's pipeline, so Flutter legitimately produces few frames there); jank percentages within produced frames remain valid.
- FFI `map_render_low1p` in phases immediately after style load contains the one-shot first-frame tile/style upload spikes (~300 ms), not steady-state behavior.
- The gesture phase durations stretch on the single-isolate engine (pan +93 %) because the synthetic pointer stream shares the saturated UI thread: a real-world symptom, but it also means its per-phase averages cover a longer wall clock.
