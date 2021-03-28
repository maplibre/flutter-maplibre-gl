# Flutter Maplibre GL

**This project is a fork of [https://github.com/tobrun/flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl), aiming to replace its usage of Mapbox GL libraries with [Maplibre GL](https://github.com/maplibre) libraries.**

**This change isn't fully done, yet, and the project shouldn't be used at this time.**

**Please note that this project is community driven and is not affiliated with the company Mapbox.** <br>
It does use some of their amazing open source libraries/tools, though. Thank you, Mapbox, for all the open-source work you do!


This Flutter plugin allows to show embedded interactive and customizable vector maps inside a Flutter widget. For the Android and iOS integration, we use [maplibre-gl-native](https://github.com/maplibre/maplibre-gl-native). For web, we rely on [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js). This project only supports a subset of the API exposed by these libraries. 

## Current migration status

| Android | iOS | Web |
| ------ | ------ | ----- |
| ✅ Using Maplibre; works fine <br>(Features provided by Android plugins aren't tested, yet) | Compiles, but still uses Mapbox GL.<br>**[Help wanted](https://github.com/m0nac0/flutter-maplibre-gl/issues/2)** | ✅ Using Maplibre GL JS; works fine |


## Using the SDK in your project

This project is not yet available on pub.dev.
You can use it by referencing it in your pubspec.yaml like this:
```yaml
dependencies:
    ...
    maplibre_gl:
      git:
        url: https://github.com/m0nac0/flutter-maplibre-gl.git
        ref: main
```
Compared to flutter-mapbox-gl, the only breaking API changes are: 
- `MapboxMap` <--> `MaplibreMap`
- `MapboxMapController` <--> `MaplibreMapController`
## Running the example app

- Install [Flutter](https://flutter.io/get-started/) and validate its installation with `flutter doctor`
- Clone the repository with `git clone git@github.com:m0nac0/flutter-maplibre-gl.git`
- Connect a mobile device or start an emulator, simulator or chrome
- Locate the id of a the device with `flutter devices`
- Run the app with `cd flutter_mapbox/example && flutter packages get && flutter run -d {device_id}`

## Avoid Android UnsatisfiedLinkError

Update buildTypes in `android\app\build.gradle`

```gradle
buildTypes {
    release {
        // other configs
        ndk {
            abiFilters 'armeabi-v7a','arm64-v8a','x86_64', 'x86'
        }
    }
}
```


## Supported API

| Feature | Android | iOS | Web |
| ------ | ------ | ----- | ----- |
| Style | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Camera | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Gesture | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| User Location | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Symbol | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Circle | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Line | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Fill | :white_check_mark:   | :white_check_mark: | :white_check_mark: |

## Map Styles

Map styles can be supplied by setting the `styleString` in the `MapOptions`. The following formats are supported:

1. Passing the URL of the map style. This should be a custom map style served remotely using a URL that start with 'http(s)://'
2. Passing the style as a local asset. Create a JSON file in the `assets` and add a reference in `pubspec.yml`. Set the style string to the relative path for this asset in order to load it into the map.
3. Passing the style as a local file. create an JSON file in app directory (e.g. ApplicationDocumentsDirectory). Set the style string to the absolute path of this JSON file.
4. Passing the raw JSON of the map style. This is only supported on Android.  



## Location features
To enable location features in an **Android** application:

You need to declare the `ACCESS_COARSE_LOCATION` or `ACCESS_FINE_LOCATION` permission in the AndroidManifest.xml and starting from Android API level 23 also request it at runtime. The plugin does not handle this for you. The example app uses the flutter ['location' plugin](https://pub.dev/packages/location) for this. 

To enable location features in an **iOS** application:

If you access your users' location, you should also add the following key to your Info.plist to explain why you need access to their location data:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>[Your explanation here]</string>
```

Mapbox [recommends](https://docs.mapbox.com/help/tutorials/first-steps-ios-sdk/#display-the-users-location) the explanation "Shows your location on the map and helps improve the map".

## Documentation

This README file currently houses all of the documentation for this Flutter project. Please visit [https://github.com/maplibre/maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) and [https://github.com/maplibre/maplibre-gl-native](https://github.com/maplibre/maplibre-gl-native) for more information about the Maplibre libraries.

## Getting Help

- **Need help with your code?**: Check the [discussions](https://github.com/m0nac0/flutter-maplibre-gl/discussions) on this repo or open a new one. 
 Or look for previous questions on the [#maplibre tag](https://stackoverflow.com/questions/tagged/maplibre) — or [ask a new question](https://stackoverflow.com/questions/tagged/maplibre).
- **Have a bug to report?** [Open an issue](https://github.com/m0nac0/flutter-maplibre-gl/issues/new). If possible, include a full log and information which shows the issue.
- **Have a feature request?** [Open an issue](https://github.com/m0nac0/flutter-maplibre-gl/issues/new). Tell us what the feature should do and why you want the feature.


## Contributing


[Feedback](https://github.com/m0nac0/flutter-maplibre-gl/issues) and contributions are very welcome!
