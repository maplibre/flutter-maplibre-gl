# Release Process

This document describes the steps needed to make a release:

## **On the main branch:**
1. Update the top-level `CHANGELOG.md` with the commits/PRs since the previous release (the changelogs for the other two packages link there). Ideally at least PRs with breaking changes should already have modified the changelog to list their breaking change.

2. Update the library version in `pubspec.yaml` for each supported library:
    - `maplibre_gl_platform_interface`
    - `maplibre_gl_web`
    - `flutter-maplibre-gl`

### Version numbering
 As long as we are on major version 0 (i.e. version number 0.xx.xx), we increase the minor component (e.g. from 0.16.0 to 0.17.0) for every breaking/significant release. 

We may want to make releases where we only increase the patch version (the final digits) for small bug-fix-releases or similar.



## Only on the GitHub release branch 
After performing the above changes on the main branch (new changelog and versions), create a new git release branch from the main branch, named like `git-release-x.y.z`.

On that branch: In `flutter-maplibre-gl` and `maplibre_gl_web` in their respective pubspec.yaml file,  change the `ref` value for the maplibre git dependencies from `main` to `git-release-x.y.z` (the new git release branch).

Now testing can be performed by commenting out the `dependency_overrides` in the example app. Then the example app will use the packages from this git release branch, instead of their local copies. This way, inter-package dependencies can be tested.


Then, create a GitHub release (`x.y.z`) with a new git tag (`x.y.z`) from this git release branch (This can be done from the GitHub web interface).

The only difference between the git release branch and the `main` branch directly after the GitHub release is, which branch the git refs for the intra-package dependencies point to.

## Only on the pub release branch
After performing the above changes on the git release branch, create a new pub release branch from the git release branch, named like `pub-release-x.y.z`.

 On that branch: In `flutter-maplibre-gl` and `maplibre_gl_web` in their pubspec.yaml files change the maplibre git dependencies to hosted dependencies (regular pub.dev dependencies) with the same version number.

 ### Publishing order to pub.dev
 Then the 3 plugins can be published from this pub release branch in this order (because of the inter-package dependencies):
 1. `maplibre_gl_platform_interface`
 2. `maplibre_gl_web`
 3. `flutter-maplibre-gl`

(For the first two, of course only publish the contents of the relevant subfolder with the same name)
