# Release Process

This document describes the steps needed to make a release.
All packages are versioned and released together.

---
## Overview
The repository is a multi-package workspace (`maplibre_gl` (root dir), `maplibre_gl_web`, `maplibre_gl_platform_interface`). 

All packages share the same version number. A release = bump versions + update changelog + tag + publish.

## Versioning Policy

Format: `MAJOR.MINOR.PATCH` following [Semantic Versioning 2.0.0](https://semver.org/).

As of v1.0.0, this project follows **standard semantic versioning**:

| Change Type | Bump | Effect | Example (old → new) | Notes |
|-------------|------|--------|---------------------|-------|
| Breaking change | MAJOR (1st) | Incompatible API changes | 1.2.3 → 2.0.0 | Mark **BREAKING** in changelog with migration guide |
| New feature / enhancement | MINOR (2nd) & reset PATCH | Adds functionality in a backward-compatible manner | 1.2.3 → 1.3.0 | Combine related features where possible |
| Bug fix / doc / internal only | PATCH (3rd) | Backward-compatible bug fixes | 1.2.3 → 1.2.4 | Batch multiple fixes if close in time |

Rules:
1. **MAJOR version** (X.y.z) increments for incompatible API changes.
2. **MINOR version** (x.Y.z) increments for new backward-compatible functionality (reset PATCH to 0).
3. **PATCH version** (x.y.Z) increments for backward-compatible bug fixes.
4. Avoid publishing multiple PATCH releases within minutes—group fixes.
5. No build metadata (`+...`) for normal releases.

Changelog tags:
- Use headings: Added / Changed / Fixed / Removed / Deprecated / Security / **BREAKING**.
- Provide migration hints for each breaking change.

Tag format: `vX.Y.Z` (e.g. `v1.0.0`, `v1.2.3`).

### Examples (Post-1.0)
| Scenario | Old | New | Notes |
|----------|-----|-----|-------|
| Remove deprecated API or change signature | 1.2.3 | 2.0.0 | MAJOR bump (breaking change) |
| Add new public controller method | 1.2.3 | 1.3.0 | MINOR bump (backward-compatible feature) |
| Fix crash in symbol update logic | 1.2.3 | 1.2.4 | PATCH fix |
| Documentation typo only | 1.2.3 | 1.2.4 | PATCH (or skip if trivial) |

### Deciding the bump
1. Does it break existing code or change behavior? -> bump MAJOR.
2. Does it add new functionality without breaking changes? -> bump MINOR, reset PATCH to 0.
3. Is it a pure bug fix with no API surface change? -> bump PATCH.
4. Multiple fixes queued? Prefer batching into one PATCH rather than multiple rapid releases.

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
  maplibre_gl_platform_interface: ^1.0.0
```

## Update the Changelog
In root `CHANGELOG.md`:
1. Move items from `Unreleased` (if present) under a new heading: `## [X.Y.Z] - YYYY-MM-DD`.
2. Group by sections (Suggested):
   - Added
   - Changed
   - Fixed
   - Removed / Deprecated
   - Security
   - **BREAKING** (for major versions)
   - Internal (optional)
3. For **MAJOR** version bumps, ensure breaking changes are clearly marked with **BREAKING** and include migration guides.
4. Link to full changelog comparison: `[vX.Y.Z...vA.B.C]`

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
git tag v1.2.3
git push origin v1.2.3
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
# decide version 1.2.4 (was 1.2.3)
edit pubspecs -> 1.2.4
update CHANGELOG
commit & PR -> chore: release 1.2.4
merge
git tag v1.2.4 && git push origin v1.2.4
```

### Minor Release (New Feature)
```bash
# After merging a new backward-compatible feature
# decide version 1.3.0 (was 1.2.3)
edit pubspecs -> 1.3.0
update CHANGELOG
commit & PR -> chore: release 1.3.0
merge
git tag v1.3.0 && git push origin v1.3.0
```

### Major Release (Breaking Change)
```bash
# After merging breaking API changes
# decide version 2.0.0 (was 1.2.3)
edit pubspecs -> 2.0.0
update CHANGELOG with BREAKING section and migration guide
commit & PR -> chore: release 2.0.0
merge
git tag v2.0.0 && git push origin v2.0.0
```

---
Happy releasing! Keep the cycle short & incremental for faster feedback.