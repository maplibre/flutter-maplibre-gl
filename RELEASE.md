# Release Process

This document describes the steps needed to make a release.
All packages are versioned and released together.

---
## Overview
The repository is a multi-package workspace (`maplibre_gl` (root dir), `maplibre_gl_web`, `maplibre_gl_platform_interface`). 

All packages share the same version number. A release = bump versions + update changelog + tag + publish.

## Versioning Policy

Format: `MAJOR.MINOR.PATCH` (currently MAJOR fixed at 0 until 1.0.0).

| Change Type | Bump | Effect | Example (old → new) | Notes |
|-------------|------|--------|---------------------|-------|
| Breaking / significant feature | MINOR (2nd) & reset PATCH | Public API or behavior change (may be breaking pre‑1.0) | 0.23.4 → 0.24.0 | Mark **BREAKING** in changelog if present |
| Compatible feature / enhancement | MINOR (2nd) & reset PATCH | Adds capability, no removal | 0.24.1 → 0.25.0 | Combine small features where possible |
| Bug fix / doc / internal only | PATCH (3rd) | No API change | 0.24.0 → 0.24.1 | Batch multiple fixes if close in time |

Rules:
1. Pre‑1.0 any incompatible change still uses a MINOR bump (second segment).
2. Always reset PATCH to 0 when you bump MINOR.
3. Avoid publishing multiple PATCH releases within minutes—group fixes.
4. No build metadata (`+...`) for normal releases.

Changelog tags:
- Use headings: Added / Changed / Fixed / Removed / **BREAKING**.
- Provide a one‑line migration hint for each breaking change.

Tag format: `v0.X.Y` (e.g. `v0.24.0`).

After 1.0.0 the table semantics align with standard SemVer (MINOR no longer contains breaking changes; those move to MAJOR).

### Examples (Pre-1.0)
| Scenario | Old | New | Notes |
|----------|-----|-----|-------|
| Add new public controller API | 0.23.1 | 0.24.0 | MINOR bump (document new API) |
| Fix crash in symbol update logic | 0.24.0 | 0.24.1 | PATCH fix |
| Introduce breaking rename of parameter | 0.24.1 | 0.25.0 | MINOR bump (flag **BREAKING**) |
| Documentation typo only (optional) | 0.25.0 | 0.25.1 | Only if you want it on pub.dev |

### Deciding the bump
1. Is the change user-visible (new feature or breaking)? -> bump MINOR, reset PATCH to 0.
2. Pure bug fix with no API surface change? -> bump PATCH.
3. Multiple fixes queued? Prefer batching into one PATCH rather than multiple rapid releases.

---
## Pre‑Release Checklist
Before changing any versions ensure:
- [ ] Local workspace is clean (`git status` shows no unintended changes)
- [ ] CI is green on `main` (or the release branch)
- [ ] No open high‑priority issues blocking release
- [ ] Example app builds & runs on: Android emulator, iOS simulator, Web
- [ ] Map renders default style & basic layers (symbol, line, fill) on each platform
- [ ] Newly added APIs have minimal doc comments
- [ ] CHANGELOG has human readable entries (no raw commit noise)
- [ ] Generated code (if applicable) is up to date (`melos run generate`)
- [ ] `melos analyze` passes with no new warnings
- [ ] `melos test` passes (if tests present)

## Determining the Next Version
1. Gather changes since last tag: `git log --oneline vLAST_TAG..HEAD`.
2. Classify: breaking? feature? fix?
3. Apply rule above (minor vs patch bump).

## Update Version Numbers
Edit `pubspec.yaml` in each package:
- `maplibre_gl_platform_interface`
- `maplibre_gl_web`
- `maplibre_gl`

Ensure internal dependencies point to the new version (same number across all three). Example snippet:
```yaml
dependencies:
  maplibre_gl_platform_interface: ^0.25.0
```

## Update the Changelog
In root `CHANGELOG.md`:
1. Move items from `Unreleased` (if present) under a new heading: `## 0.25.0 - YYYY-MM-DD`.
2. Group by sections (Suggested):
   - Added
   - Changed
   - Fixed
   - Removed / Deprecated
   - Internal (optional)
3. Ensure breaking changes are clearly marked with **BREAKING** and (if needed) short migration hints.

Sub-package changelogs may link to root; keep duplication minimal.

## Sanity / Validation Matrix
Run these smoke tests after version & changelog updates and before tagging:
| Platform | Action | Expected |
|----------|--------|----------|
| Android  | Launch example, toggle style, add symbol | No crashes; annotations visible |
| iOS      | Same as Android | Stable, location permission flow (if enabled) works |
| Web      | Load example, pan/zoom, switch style | Tiles load, no console errors |

Optional deeper checks if native deps changed:
- Memory not growing excessively while panning 30s.
- Custom style JSON loads.

## Create Release PR
1. Commit changes: version bumps + changelog + any doc updates.
2. Title suggestion: `chore: release 0.23.0`.
3. Include summary of notable changes & any upgrade notes.
4. Wait for CI to pass & get review.

## Tag & Publish
After the release PR has been merged, create & push the version tag (format `vX.Y.Z`). The CI/CD pipeline will perform the publish steps automatically.

> **IMPORTANT**: Only a project maintainer (with publish permissions) must create & push the release tag. Contributors should not tag releases directly.

```bash
git checkout main
git pull origin main
git tag v0.24.0
git push origin v0.24.0
```
No further manual publish commands are required unless the pipeline fails. In that case, resolve the issue and re-push (delete & recreate tag only if absolutely necessary and before broad adoption).

## Post‑Release Tasks
- [ ] Verify package pages on pub.dev reflect new version
- [ ] Create GitHub Release entry (auto-populate from CHANGELOG section) – attach highlights
- [ ] Announce in Discussions (optional)
- [ ] Update any pinned examples or docs referencing an older version
- [ ] Open a new `Unreleased` heading in the changelog for future changes

## Rollback / Hotfix
If a critical issue is discovered shortly after release:
1. Decide: rollback (yank) vs hotfix.
2. For rollback: publish a patch with fix (preferred) instead of deleting tag (immutability). Bump patch (`0.x.(n+1)`).
3. Add clear changelog entry referencing the prior faulty version.
4. Communicate in issue & release notes.

## Tips
- Keep PR small: avoid mixing refactors with release prep.
- If native SDK version bumps are included, link upstream release notes in the PR description.
- Run `flutter clean` in example only if weird build artifacts appear (avoid unnecessary noise in instructions).

## Example Flows

### Patch Fix (Bug Fix)
```bash
# After merging a simple fix
# decide version 0.25.1 (was 0.25.0)
edit pubspecs -> 0.25.1
update CHANGELOG
commit & PR -> chore: release 0.25.1
merge
git tag v0.25.1 && git push origin v0.25.1
```

### Minor Release (New Feature)
```bash
# After merging a new feature
# decide version 0.25.0 (was 0.24.1)
edit pubspecs -> 0.25.0
update CHANGELOG
commit & PR -> chore: release 0.25.0
merge
git tag v0.25.0 && git push origin v0.25.0
```

---
Happy releasing! Keep the cycle short & incremental for faster feedback.