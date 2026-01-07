# Contributing

We welcome contributions of all kinds: bug fixes, new features, documentation improvements, benchmarks, and issue triage. This guide explains how to work effectively in this repository.

---
## Quick Start (TL;DR)
1. Fork & create a feature branch from `main` (or the current release prep branch if coordinating).
2. Run workspace bootstrap with Melos:
   ```bash
   dart pub global activate melos
   melos bootstrap
   ```
3. Make changes (add tests, update example where relevant).
4. Regenerate code if you touched style/source definitions:
   ```bash
   melos run generate && melos format-all
   ```
5. Run analyzer & tests:
   ```bash
   melos analyze-all
   melos test
   ```
6. Update CHANGELOG(s) if user‑visible behavior changed.
7. Open a Pull Request (PR) and fill out the template.

---
## Before You Start
- Search existing [issues](https://github.com/maplibre/flutter-maplibre-gl/issues) & [PRs](https://github.com/maplibre/flutter-maplibre-gl/pulls) to avoid duplication.
- For larger features, open a brief proposal issue or discussion first to align scope & design.
- Keep PRs focused: small, reviewable units are merged faster.

## Project Structure (Workspace Packages)
```
maplibre_gl/                     # Main Flutter plugin (Android/iOS bindings + shared Dart API)
maplibre_gl_platform_interface/  # Federated plugin interface (abstractions & shared types)
maplibre_gl_web/                 # Web implementation (maplibre-gl-js bridge)
maplibre_gl_example/             # Example app (integration & usage demos)
scripts/                         # Code generation templates and generator entrypoints
```
Generated code lives inside the plugin packages — never modify it directly (see Code Generation section).

## Prerequisites & Tooling
| Tool | Minimum / Expected | Notes |
|------|--------------------|-------|
| Flutter SDK | Stable channel (latest) | Ensure `flutter doctor` is clean |
| Dart | Comes with Flutter | Required for generator scripts |
| Melos | Latest | Workspace orchestration |
| Java / Android SDK | As per Flutter requirements | For Android builds |
| Xcode | Current stable | For iOS builds |

Optional: `just`/`make` scripts (if later added), Node (only if experimenting with web build tooling).

## Workflow Overview
1. Bootstrap: `melos bootstrap`
2. (Optional) Clean: `melos clean` if dependency graph changed significantly.
3. Develop inside the package needing changes; update the example app to showcase new APIs.
4. Run local verification: analyze, test, run example on target platforms.
5. Commit with a clear message; push branch & open PR.

## Branching Strategy
- `main`: Always buildable; contains latest released or soon‑to‑be released code.
- Release prep branches (e.g. `release-v.X.Y.Z`): Used briefly before tagging.
- Feature / fix branches: `feat/<short-description>` or `chore/<issue-id>` (no strict enforcement, but clarity helps).

## Commit Message Guidelines
Not strictly enforced, but recommended pattern (Conventional Commit style):
```
feat: add circle layer dash pattern support
fix(ios): correct expression conversion for !has
chore: bump maplibre-native version
```
Why: Helps generate release notes & scan history quickly.

## Coding Standards
- Follow `analysis_options.yaml` (pedantic / lints). Fix warnings before PR.
- Keep public API additions minimal & purposeful; prefer consistency with existing naming.
- Null safety: avoid unnecessary `!`; use safe patterns & explicit types.
- Avoid wide diffs from formatting unrelated code.

## Adding / Extending API Surface
When adding new layer/source property helpers or expression constructs:
1. Update or create mapping logic in `scripts/lib/conversions.dart` (or relevant template).
2. Run generation & formatting.
3. Add usage sample in example app (new page or extend an existing one).
4. Document in README if user‑facing.

## Tests & Quality Assurance
Currently (if present):
- Unit tests under each package's `test/` directory.
- Run all tests: `melos test`.
- Add at least: success path + one edge case.
- For map rendering or gesture logic that's hard to unit test, prefer: clearly documented behavior + example reproduction steps.

Before submitting:
```bash
melos analyze
melos test
```
If adding platform‑channel changes, test both Android & iOS (simulator/emulator acceptable) plus web if impacted.

## Performance Considerations
- Batch style or layer operations.
- Avoid unnecessary rebuilds of `MapLibreMap` widget in example pages.
- Profile only when needed (Flutter DevTools / native profilers). Include notes if performance-sensitive code added.

## Documentation & Changelog
Update the root `CHANGELOG.md` (and package‑specific ones if only a sub‑package changed) with a brief, user‑oriented entry:
```
### Added
- New heatmap gradient expression helper (#123)
```
Group entries under `## [Unreleased]` (or the upcoming version header depending on existing pattern). The maintainers will finalize version numbers on release.

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

## Pull Request Checklist
Before marking your PR ready for review, verify:
- [ ] Example app updated (if API / behavior change)
- [ ] Tests added/updated (or rationale provided)
- [ ] Analyzer passes (no new warnings)
- [ ] Code generation re-run (if templates touched)
- [ ] Changelog updated
- [ ] No unrelated formatting noise
- [ ] All platforms tested that are affected
- [ ] Screenshots / recordings included for UI changes (if applicable)

## Security & Responsible disclosure
Found a vulnerability or sensitive exposure vector?
- Do **not** open a public issue with exploit details first.
- Email the maintainers or use GitHub security advisories if enabled.
- Provide reproduction steps & potential impact.

## Release process (Maintainers)
A high-level outline (subject to change):
1. Ensure `main` (or release branch) is green (CI, tests, analyzer).
2. Update package versions & root/individual `CHANGELOG.md` sections following the pre-1.0 versioning policy in [RELEASE.md](RELEASE.md):
   - **MINOR** version for breaking changes, significant features, or new functionality
   - **PATCH** version for backward-compatible bug fixes
3. Tag the release (`v0.X.Y`) and publish packages to pub.dev in dependency order.
4. Merge back any release branch into `main`.
5. Announce in discussions (optional).

For more information, see [RELEASE.md](RELEASE.md) instructions.

## Community epectations
Be respectful and constructive. We follow the project's `CODE_OF_CONDUCT.md`. Harassment, discrimination, or unprofessional behavior is not tolerated.

## Getting help while Contributing
- Open a draft PR early to get directional feedback.
- Use Discussions for design clarifications.
- Reference upstream MapLibre issues if exposing a capability that exists natively.

---
## A note on Native dependencies
When bumping native MapLibre engine versions:
- Link to upstream release notes.
- Test style load, camera operations, at least one annotation per type on both iOS & Android.
- Watch for symbol changes or removed APIs.

---
## Attribution
This fork builds upon earlier work of `flutter-mapbox-gl` contributors and the broader MapLibre community.

---
## Thank You
Your time and expertise help keep an open, vendor‑neutral mapping stack thriving in Flutter.
