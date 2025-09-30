## 0.23.0

> Note: This release has breaking changes.

 - **REFACTOR**: enable and fix some lint rules ([#452](https://github.com/maplibre/flutter-maplibre-gl/issues/452)).
 - **FIX**: Aligned example and maplibre_gl_web pubspec versions. ([#476](https://github.com/maplibre/flutter-maplibre-gl/issues/476)).
 - **FIX**(web): ensure the usage of `maplibre-gl-js` version 4.x.x, remove `_addStylesheetToShadowRoot` ([#409](https://github.com/maplibre/flutter-maplibre-gl/issues/409)).
 - **FEAT**: added set style method on controller ([#444](https://github.com/maplibre/flutter-maplibre-gl/issues/444)).
 - **FEAT**: update maplibre-native to the latest versions ([#552](https://github.com/maplibre/flutter-maplibre-gl/issues/552)).
 - **FEAT**: upgrade FGP & compatible with flutter 3.29.0 ([#542](https://github.com/maplibre/flutter-maplibre-gl/issues/542)).
 - **FEAT**: use lints from very_good_analysis ([#434](https://github.com/maplibre/flutter-maplibre-gl/issues/434)).
 - **FEAT**: allow latest `flutter_lints` version ([#419](https://github.com/maplibre/flutter-maplibre-gl/issues/419)).
 - **FEAT**: add `flutter_lints`, fix or ignore lints ([#414](https://github.com/maplibre/flutter-maplibre-gl/issues/414)).
 - **FEAT**: update package links in pubspec.yaml files ([#413](https://github.com/maplibre/flutter-maplibre-gl/issues/413)).
 - **FEAT**(web): allow package:js version 0.6.x and 0.7.x ([#410](https://github.com/maplibre/flutter-maplibre-gl/issues/410)).
 - **FEAT**: heatmap layer ([#365](https://github.com/maplibre/flutter-maplibre-gl/issues/365)).
 - **FEAT**: add support for changing the receiver’s viewport to fit given bounds ([#133](https://github.com/maplibre/flutter-maplibre-gl/issues/133)).
 - **FEAT**: Set layer visibility ([#138](https://github.com/maplibre/flutter-maplibre-gl/issues/138)).
 - **BREAKING** **FEAT**: rename `Maplibre` to `MapLibre` ([#441](https://github.com/maplibre/flutter-maplibre-gl/issues/441)).
 - **BREAKING** **FEAT**: use lower camel case for enum fields and consts ([#415](https://github.com/maplibre/flutter-maplibre-gl/issues/415)).

## newer releases

see top-level CHANGELOG.md

## 0.15.1, May 24, 2022

see top-level CHANGELOG.md

## 0.15.0, Oct 26, 2021

see top-level CHANGELOG.md

## 0.14.0, Oct 14, 2021

## 0.13.0, Oct 6, 2021

🎉 The first release of flutter-maplibre-gl with the complete transition to
MapLibre libraries. 🎉

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0

* Dependencies: updated image
  package [#598](https://github.com/tobrun/flutter-mapbox-gl/pull/598)
* Fix feature manager on release
  build [#593](https://github.com/tobrun/flutter-mapbox-gl/pull/593)
* Emit onTap only for the feature above the
  others [#589](https://github.com/tobrun/flutter-mapbox-gl/pull/589)
* Add annotationOrder to
  web [#588](https://github.com/tobrun/flutter-mapbox-gl/pull/588)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0

* Fix Mapbox GL JS CSS embedding on
  web [#551](https://github.com/tobrun/flutter-mapbox-gl/pull/551)
* Add batch mode of screen
  locations [#554](https://github.com/tobrun/flutter-mapbox-gl/pull/554)

## Below is the original changelog of the tobrun/flutter-mapbox-gl project, before the fork.

## 0.10.0, February 12, 2020

* Added web support for
  fills [#501](https://github.com/tobrun/flutter-mapbox-gl/pull/501)
* Add heading to UserLocation and expose UserLocation
  type [#522](https://github.com/tobrun/flutter-mapbox-gl/pull/522)
* Update tracked camera position in
  camera#onIdle [#500](https://github.com/tobrun/flutter-mapbox-gl/pull/500)
* Improved Image Source
  Support [#469](https://github.com/tobrun/flutter-mapbox-gl/pull/469)

## 0.9.0, October 24. 2020

* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different
  padding values for left, top, right, bottom with default of 0 for all.
  Implementations using the old approach with only one padding value for all
  edges have to be
  updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* web:ignore myLocationTrackingMode if myLocationEnabled is
  false [#363](https://github.com/tobrun/flutter-mapbox-gl/pull/363)
* Add methods to access
  projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Listen to OnUserLocationUpdated to provide user location to
  app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Get meters per pixel at
  latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)

## 0.8.0, August 22, 2020

- implementation of feature
  querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Allow setting accesstoken in
  flutter [#321](https://github.com/tobrun/flutter-mapbox-gl/pull/321)
- Batch create/delete of
  symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Set dependencies from
  git [#319](https://github.com/tobrun/flutter-mapbox-gl/pull/319)
- Add multi map
  support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)

## 0.7.0

- Initial version
