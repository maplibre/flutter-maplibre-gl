## newer releases

see top-level CHANGELOG.md

## 0.15.1, May 24, 2022

see top-level CHANGELOG.md

## 0.15.0, Oct 26, 2021

see top-level CHANGELOG.md

## 0.14.0, Oct 14, 2021

### Breaking changes:

* Replace example
  styles [#25](https://github.com/m0nac0/flutter-maplibre-gl/pull/25) (also
  see [#21](https://github.com/m0nac0/flutter-maplibre-gl/issues/21))
    * The built-in constants for specific styles were removed. You can continue
      using these styles by using the styles' URL

## 0.13.0, Oct 6, 2021

🎉 The first release of flutter-maplibre-gl with the complete transition to
MapLibre libraries. 🎉

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.12.0

* Batch creation/removal for circles, fills and
  lines [#576](https://github.com/tobrun/flutter-mapbox-gl/pull/576)

### Changes cherry-picked/ported from tobrun/flutter-mapbox-gl:0.11.0

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

## 0.9.0, October 24, 2020

* Breaking change: CameraUpdate.newLatLngBounds() now supports setting different
  padding values for left, top, right, bottom with default of 0 for all.
  Implementations using the old approach with only one padding value for all
  edges have to be
  updated. [#382](https://github.com/tobrun/flutter-mapbox-gl/pull/382)
* Add methods to access
  projection [#380](https://github.com/tobrun/flutter-mapbox-gl/pull/380)
* Add fill API support for Android and
  iOS [#49](https://github.com/tobrun/flutter-mapbox-gl/pull/49)
* Listen to OnUserLocationUpdated to provide user location to
  app [#237](https://github.com/tobrun/flutter-mapbox-gl/pull/237)
* Add support for custom font stackn in symbol
  options [#359](https://github.com/tobrun/flutter-mapbox-gl/pull/359)
* Basic ImageSource
  Support [#409](https://github.com/tobrun/flutter-mapbox-gl/pull/409)
* Get meters per pixel at
  latitude [#416](https://github.com/tobrun/flutter-mapbox-gl/pull/416)

## 0.8.0, August 22, 2020

- implementation of feature
  querying [#177](https://github.com/tobrun/flutter-mapbox-gl/pull/177)
- Batch create/delete of
  symbols [#279](https://github.com/tobrun/flutter-mapbox-gl/pull/279)
- Add multi map
  support [#315](https://github.com/tobrun/flutter-mapbox-gl/pull/315)
- Add line#getGeometry and
  symbol#getGeometry [#281](https://github.com/tobrun/flutter-mapbox-gl/pull/281)

## 0.7.0

- Initial version
