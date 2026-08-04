# maplibre_gl_example

The example gallery of the maplibre_gl plugin: one page per feature, and the
place where changes to the plugin get tried on a real device.

## Three entry points

```sh
flutter run                        # the gallery, on the default engine
flutter run -t lib/main_ffi.dart   # the same gallery, on the experimental FFI engine
flutter run --profile -t lib/main_bench.dart   # one benchmark run, by hand
```

`lib/main_ffi.dart` is a two-line file: it calls `MapLibreGlNative.use()` and
then the gallery's own `main()`. Every page then runs on the
[`maplibre_gl_native`](../maplibre_gl_native) backend without a single change to
the app code, which is the whole claim of that package. Android arm64 only.

## Benchmarks

This package also hosts the performance harness that compares the two engines
on a real device: synthetic gestures, camera fly-throughs, GeoJSON stress,
live-data updates and API latencies, all measured with thermal gating and a
warm-up pass so consecutive runs are comparable.

```sh
dart run tool/bench/run_bench.dart --help      # every option, with defaults
dart run tool/bench/run_bench.dart --dry-run   # what would run, and for how long
```

- [`docs/benchmarks/ffi-benchmarks.md`](docs/benchmarks/ffi-benchmarks.md):
  how to run a suite, what each scenario measures, how to read the report.
  **Start here.**
- [`docs/benchmarks/ffi-benchmark-results-2026-07.md`](docs/benchmarks/ffi-benchmark-results-2026-07.md):
  what the last full suite found.
- `tool/bench/run_bench.dart` orchestrates the device, `tool/bench/aggregate.dart`
  turns the raw runs into a report, `lib/bench/` is the in-app instrumentation.

## New to Flutter?

[Lab: write your first Flutter app](https://flutter.io/docs/get-started/codelab),
[cookbook](https://flutter.io/docs/cookbook), and the
[full documentation](https://flutter.io/docs).
