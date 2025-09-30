# Contributing

We welcome contributions to this repository. Please follow these steps if you're
interested in making contributions:

1. Please familiarize yourself with
   the [process of running the example app](https://github.com/maplibre/flutter-maplibre-gl#running-the-example-app).
2. Ensure that
   existing [pull requests](https://github.com/maplibre/flutter-maplibre-gl/pulls)
   and [issues](https://github.com/maplibre/flutter-maplibre-gl/issues) don’t
   already cover your contribution or question.
3. Create a new branch that will contain your contributed code. Along with your
   contribution you should also adapt the example app to showcase any new
   features or APIs you have developed. This also makes testing your
   contribution much easier. Eventually create a pull request once you're done
   making changes.
4. If there are any changes that developers should be aware of, please update
   the [changelog](https://github.com/maplibre/flutter-maplibre-gl/blob/master/CHANGELOG.md)
   once your pull request has been merged to the `main` branch.

## Code Generation & Formatting

Some parts of the public API (layer & source property helpers, expression utilities, etc.) are **generated**.

Do not edit generated Dart / Java / Swift files manually. Instead:

1. Make or adjust templates / generator logic under `scripts/` (main entry: `scripts/lib/generate.dart`).

2. Activate Melos and run a clean bootstrap:
   ```bash
   dart pub global activate melos && melos clean && melos bootstrap
   ```
3. Run the generator:
   ```bash
   melos run generate
   ```
4. (Optional) Run the workspace formatter (Dart files generated are already batch‑formatted automatically):
   ```bash
   melos format-all
   ```
5. Review changes:
   ```bash
   git diff
   ```
6. Stage & commit if everything looks correct.

Notes:
- The generator itself batch‑formats newly created Dart files using `dart format` so CI should not introduce extra diffs.
- Running `melos format-all` afterward is still fine (idempotent) and catches accidental manual edits elsewhere.
- Never hand‑edit generated files: your edits will be overwritten the next time the generator runs.

If you add new style specification fields, extend the mapping logic in `scripts/lib/conversions.dart` and/or templates under `scripts/templates/`.
