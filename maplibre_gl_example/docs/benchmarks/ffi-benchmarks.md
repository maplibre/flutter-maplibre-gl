# Engine benchmarks (Android)

Repeatable performance comparison between the two map engines this repository ships, run from `maplibre_gl_example` on a real device.

This is the document to start from: it explains how to run a suite, what each scenario measures, and how to read the report. The other two are the last full suite's output:

- [`ffi-benchmark-results-2026-07.md`](ffi-benchmark-results-2026-07.md): what it found, in prose. Read it for the conclusions.
- [`ffi-benchmark-full-tables-2026-07.md`](ffi-benchmark-full-tables-2026-07.md): every table, as generated. Read it to check a specific number.
- [`ffi-benchmarks-report.html`](ffi-benchmarks-report.html): the same findings as a visual summary (charts, headline numbers), for sharing with people who will not read a table. Open it in a browser; the PDF rendering of it is generated locally and deliberately not versioned.

| variant | rendering | transport |
|---|---|---|
| `stable` | SDK `MapView` in a platform view (virtual display), OpenGL ES | method channels |
| `ffi` | MapLibre Native core into an external `Texture`, Vulkan | `SendPort` to a dedicated engine isolate with its own frame loop |

A third variant existed until July 2026: FFI calls made directly on the UI isolate, no engine isolate. It lost in every scenario and was removed, so the isolate is now the only FFI mode. The July 2026 result documents predate that cleanup and use the ids of the time, where `ffi` means the retired single-isolate mode and `ffi_isolate` the current one.

The question this harness answers today: **how far is the FFI engine from the stable platform-view implementation, and in which direction?** Any change to the FFI backend can regress it, and only a suite like this one notices.

## Methodology

Modeled on the MapLibre Native Android "world tour" benchmark (`BenchmarkActivity`) and its published methodology:

- **One discarded warm-up pass** over every (engine, scenario) pair, online, which doubles as the tile-cache fill. Measured runs then execute with the engine-level network switch off (`setOffline`), so tile decode/render is measured, never the network.
- **N recorded iterations** (default 3) with the engine order rotated per iteration, so no variant systematically runs on a cooler or hotter device.
- **Thermal gate + cooldown** between runs (`dumpsys thermalservice`, default: start only at status <= 1, 60 s cooldown); thermal status before and after every run is stored with the results.
- **Frame-time distributions, not averages**: p50/p90/p99, jank rates against the 90 Hz and 60 Hz budgets, and the upstream "low 1 %" metric (mean of the worst 1 % of frames).
- Every run is a **cold app start** (`am start -S`) of the same profile-mode APK, configured through the `route` intent extra; results leave the device as gzip+base64 chunks on logcat, so no debuggable build or storage permission is needed.

### Measured signals

- **Flutter frame timings** (`SchedulerBinding.addTimingsCallback`): build, raster, and total span per frame, bucketed per scenario phase.
- **Engine render stats**, from instrumentation added for this purpose:
  - FFI: wall time of every `renderUpdate` (`FrameStatsCollector`, shared by both isolate modes; `SetFrameStatsEnabledCommand`/`TakeFrameStatsQuery`);
  - stable: `OnDidFinishRenderingFrameListener` frame encoding/rendering times (`FrameStatsRecorder`, `map#setFrameStatsEnabled`/`map#takeFrameStats`).
- **API latencies**: per-call round-trip times of projections and feature queries.
- **Process counters**: RSS samples, peak RSS, average CPU utilization.
- **Metadata**: git revision, actual engine transport (the isolate bootstrap can silently fall back to local; mismatched runs are rejected), device model, Android SDK, display refresh rate, thermal status.

### Scenarios

| key | what it measures |
|---|---|
| `style_load` | app init -> map created -> style loaded -> first fully-idle map |
| `world_tour` | upstream-style fly-through: 4 cities at zoom 14, engine-driven camera animation |
| `tracking` | GPS-follow simulation: instant camera jumps at frame cadence along a deterministic orbit (API-heavy path) |
| `gestures` | synthetic touch through the framework: continuous pans, flings with inertia, pinches, two-finger rotations |
| `stress_ramp` | 500 -> 20k GeoJSON points: `setGeoJsonSource` cost per step plus camera orbit over the data |
| `dynamic_data` | live-data stress: every feature position rewritten at up to 30 Hz, per-update round-trip timed |
| `api_latency` | `toScreenLocation`, `toLatLng`, 100-point batch projection, `queryRenderedFeatures` |

The gesture scenario dispatches synthetic `PointerEvent`s through `GestureBinding`, which follows the same framework path as real touches (including the platform-view touch forwarding of the stable engine) and is bit-identical across variants; only the OS-to-engine hop is skipped, equally for everyone.

## Running

You need one connected Android arm64 device (the reference device is a Xiaomi 11 Lite 5G NE, 90 Hz), screen unlocked at fixed brightness, battery comfortably charged, and `adb` on the PATH. The orchestrator keeps the screen on, gates on thermal status, and force-stops the app between runs.

```sh
cd maplibre_gl_example
dart run tool/bench/run_bench.dart --help    # every option, with defaults
```

Check the setup first: five minutes, one scenario, no warm-up pass.

```sh
dart run tool/bench/run_bench.dart \
  --engines stable,ffi --scenarios gestures --iterations 1 --no-warmup
```

Then the full matrix. `--dry-run` prints what would run, how many runs it is and roughly how long, without touching the device:

```sh
dart run tool/bench/run_bench.dart --dry-run
dart run tool/bench/run_bench.dart          # 42 measured runs, a few hours
```

Each run prints its position in the matrix and, from the second one on, the remaining time measured from the runs already done. Unknown options are rejected instead of ignored, so a typo cannot silently start the whole matrix.

Two options worth knowing about:

- `--only engine:scenario:iteration,...` reruns exactly those tuples and appends them to an existing results directory (pass the same `--out`). This is how you fill a hole left by a failed run without repeating the suite.
- `--style URL` swaps the style; everything is measured against OpenFreeMap Liberty by default.

### Results

Everything lands in `maplibre_gl_example/build/bench_results/<timestamp>/`:

| file | what it is |
|---|---|
| `<engine>-<scenario>-i<n>.json` | one raw run, including its metadata and thermal status |
| `report.md` | the comparison tables, per scenario and phase, with percent deltas against stable |
| `summary.json` | the same numbers, machine readable |
| `index.json` | outcome of every run of the suite, including failures |
| `<runId>.log` | the raw logcat of a failed run, for diagnosis |

`report.md` opens with a "How to read this" section: what every metric means, which direction is good, and the three caveats that change conclusions. That legend is generated with the report, so it always matches the columns.

`dart run tool/bench/aggregate.dart <results-dir>` re-renders the report from the JSONs, which is useful after changing the aggregator or to aggregate an older directory.

Note that `build/` is gitignored: results stay on the machine that produced them. The two result documents next to this one are the copies worth keeping.

## Known caveats

- **Renderer confound**: the FFI build ships the Vulkan backend, the stable SDK uses OpenGL ES. Stable-vs-FFI deltas therefore mix transport and renderer effects (upstream measured real Vulkan/GL differences). Comparing one engine against itself across revisions, which is what this harness is for day to day, is free of the confound.
- **Engine render stats measure CPU cost** (command encoding + submit), not GPU completion, on both engines; same limitation as upstream's metrics.
- The stable engine runs in the plugin's default composition mode (virtual display). `useHybridComposition: true` (TextureView) is a one-flag follow-up variant if composition overhead needs to be isolated.
- `style_load` with `offline=1` measures warm-cache loads; cold-cache online loads carry network variance and need `--online` plus a `pm clear` between runs (not automated).
