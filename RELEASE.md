

# Release Process

This document describes the steps needed to make a release.
All packages are versioned and released together.

## Preparing a release

### Define the release version number

As long as we are on major version 0 (i.e. version number 0.xx.xx), we increase
the minor component (e.g. from 0.16.0 to 0.17.0) for every breaking/significant
release.

We may want to make releases where we only increase the patch version (the final
digits) for small bug-fix-releases or similar.

### Update the version number

Update the library version in `pubspec.yaml` for each library:
   - `maplibre_gl_platform_interface`
   - `maplibre_gl_web`
   - `maplibre_gl` (root directory)

Ensure that also the dependent sub-packages are updated to the new version.

### Update the changelog

Update the `maplibre_gl` (root directory) `CHANGELOG.md` with the commits/PRs since the previous
release (the changelogs for the other two packages link there). Ideally at
least PRs with breaking changes should already have modified the changelog to
list their breaking change.

### Create a PR

Commit all changes and create a PR targeting the main branch.

## Creating a release

After the release PR has been merged, the release can be created
by creating & pushing a tag on the main branch in the format `vVERSION`,
for example `v0.20.0`.