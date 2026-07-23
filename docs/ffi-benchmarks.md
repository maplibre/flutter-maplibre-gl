# FFI engine benchmarks (Android)

Reliable, repeatable performance comparison between the three engine
variants of the FFI spike (see `rfc-native-ffi-engine.md`):

| variant | rendering | transport |
|---|---|---|
| `stable` | SDK `MapView` in a platform view (virtual display), OpenGL ES | method channels |
| `ffi` | MapLibre Native core into an external `Texture`, Vulkan | direct FFI calls on the UI isolate |
| `ffi_isolate` | same as `ffi` | `SendPort` to a dedicated engine isolate with its own frame loop |

The goal is to answer two questions with data:

1. Should `engineIsolate: true` be the default of the FFI backend?
2. How far is the FFI path from the stable platform-view implementation,
   and in which direction?

## Methodology

Modeled on the MapLibre Native Android "world tour" benchmark
(`BenchmarkActivity`) and its published methodology:

- **One discarded warm-up pass** over every (engine, scenario) pair, online,
  which doubles as the tile-cache fill. Measured runs then execute with the
  engine-level network switch off (`setOffline`), so tile decode/render is
  measured, never the network.
- **N recorded iterations** (default 3) with the engine order rotated per
  iteration, so no variant systematically runs on a cooler or hotter device.
- **Thermal gate + cooldown** between runs (`dumpsys thermalservice`,
  default: start only at status <= 1, 60 s cooldown); thermal status before
  and after every run is stored with the results.
- **Frame-time distributions, not averages**: p50/p90/p99, jank rates
  against the 90 Hz and 60 Hz budgets, and the upstream "low 1 %" metric
  (mean of the worst 1 % of frames).
- Every run is a **cold app start** (`am start -S`) of the same profile-mode
  APK, configured through the `route` intent extra; results leave the device
  as gzip+base64 chunks on logcat, so no debuggable build or storage
  permission is needed.

### Measured signals

- **Flutter frame timings** (`SchedulerBinding.addTimingsCallback`): build,
  raster, and total span per frame, bucketed per scenario phase.
- **Engine render stats**, from instrumentation added for this purpose:
  - FFI: wall time of every `renderUpdate` (`FrameStatsCollector`, shared by
    both isolate modes; `SetFrameStatsEnabledCommand`/`TakeFrameStatsQuery`);
  - stable: `OnDidFinishRenderingFrameListener` frame encoding/rendering
    times (`FrameStatsRecorder`, `map#setFrameStatsEnabled`/`map#takeFrameStats`).
- **API latencies**: per-call round-trip times of projections and feature
  queries.
- **Process counters**: RSS samples, peak RSS, average CPU utilization.
- **Metadata**: git revision, actual engine transport (the isolate bootstrap
  can silently fall back to local; mismatched runs are rejected), device
  model, Android SDK, display refresh rate, thermal status.

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

The gesture scenario dispatches synthetic `PointerEvent`s through
`GestureBinding`, which follows the same framework path as real touches
(including the platform-view touch forwarding of the stable engine) and is
bit-identical across variants; only the OS-to-engine hop is skipped, equally
for everyone.

## Running

```sh
cd maplibre_gl_example
dart run tool/bench/run_bench.dart                  # full matrix, ~2.5-3 h
dart run tool/bench/run_bench.dart \
  --engines ffi,ffi_isolate --scenarios gestures \
  --iterations 1 --no-warmup --skip-build            # quick focused run
dart run tool/bench/aggregate.dart <results-dir>     # re-render the report
```

Results land in `maplibre_gl_example/build/bench_results/<timestamp>/`:
one JSON per run, `report.md` (per-scenario tables with percent deltas vs
stable), and `summary.json`.

Device expectations: one connected Android arm64 device (the reference
device of the spike is a Xiaomi 11 Lite 5G NE, 90 Hz), screen unlocked at
fixed brightness, battery comfortably charged. The orchestrator keeps the
screen on, gates on thermal status, and force-stops the app between runs.

## Known caveats

- **Renderer confound**: the FFI build ships the Vulkan backend, the stable
  SDK uses OpenGL ES. Stable-vs-FFI deltas therefore mix transport and
  renderer effects (upstream measured real Vulkan/GL differences). The
  `ffi` vs `ffi_isolate` comparison is free of this confound.
- **Engine render stats measure CPU cost** (command encoding + submit), not
  GPU completion, on both engines; same limitation as upstream's metrics.
- The stable engine runs in the plugin's default composition mode (virtual
  display). `useHybridComposition: true` (TextureView) is a one-flag
  follow-up variant if composition overhead needs to be isolated.
- `style_load` with `offline=1` measures warm-cache loads; cold-cache online
  loads carry network variance and need `--online` plus a `pm clear`
  between runs (not automated).
