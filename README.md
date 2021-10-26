# Flutter Maplibre GL
[![Flutter CI](https://github.com/m0nac0/flutter-maplibre-gl/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/m0nac0/flutter-maplibre-gl/actions/workflows/flutter_ci.yml)

This Flutter plugin allows to show **embedded interactive and customizable vector maps** as a Flutter widget. 

For the Android and iOS integration, we use [maplibre-gl-native](https://github.com/maplibre/maplibre-gl-native). For web, we rely on [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js). This project only supports a subset of the API exposed by these libraries. 


This project is a fork of [https://github.com/tobrun/flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl), replacing its usage of Mapbox GL libraries with the open source [Maplibre GL](https://github.com/maplibre) libraries.

**Please note that this project is community driven and is not affiliated with the company Mapbox.** <br>
It does use some of their amazing open source libraries/tools, though. Thank you, Mapbox, for all the open-source work you do!


## Using the plugin in your project

This project is not yet available on pub.dev.
You can use it by referencing it in your `pubspec.yaml` like this:
```yaml
dependencies:
    ...
    maplibre_gl:
      git:
        url: https://github.com/m0nac0/flutter-maplibre-gl.git
        ref: main
```
This will get you the very latest changes from the main branch.
You can replace `main` with the name of the [latest release](https://github.com/m0nac0/flutter-maplibre-gl/releases)
to get a well-tested version.


Compared to flutter-mapbox-gl, the only breaking API changes are: 
- `MapboxMap` <--> `MaplibreMap`
- `MapboxMapController` <--> `MaplibreMapController`

## Supported API

| Feature | Android | iOS | Web |
| ------ |:-:|:-:|:-:|
| Style | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Camera | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Gesture | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| User Location | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Symbol | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Circle | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Line | :white_check_mark:   | :white_check_mark: | :white_check_mark: |
| Fill | :white_check_mark:   | :white_check_mark: | :white_check_mark: |

## Running the example app

- Install [Flutter](https://flutter.io/get-started/) and validate its installation with `flutter doctor`
- Clone the repository with `git clone git@github.com:m0nac0/flutter-maplibre-gl.git`
- Connect a mobile device or start an emulator, simulator or chrome
- Run the app with `cd flutter-maplibre-gl/example && flutter packages get && flutter run`


## Map Styles

Map styles can be supplied by setting the `styleString` in the `MapOptions`. The following formats are supported:

1. Passing the URL of the map style. This should be a custom map style served remotely using a URL that start with 'http(s)://'
2. Passing the style as a local asset. Create a JSON file in the `assets` and add a reference in `pubspec.yml`. Set the style string to the relative path for this asset in order to load it into the map.
3. Passing the style as a local file. create an JSON file in app directory (e.g. ApplicationDocumentsDirectory). Set the style string to the absolute path of this JSON file.
4. Passing the raw JSON of the map style. This is only supported on Android.  

### Tile sources requiring an API key
If your tile source requires an API key, we recomend directly specifying a source url with the API key included.
For example:

 `https://tiles.example.com/{z}/{x}/{y}.vector.pbf?api_key={your_key}`



## Location features
### Android
Add the `ACCESS_COARSE_LOCATION` or `ACCESS_FINE_LOCATION` permission in the application manifest `android/app/src/main/AndroidManifest.xml` to enable location features in an **Android** application:
```
<manifest ...
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

Starting from Android API level 23 you also need to request it at runtime. This plugin does not handle this for you. The example app uses the flutter ['location' plugin](https://pub.dev/packages/location) for this.

### iOS
To enable location features in an **iOS** application:

If you access your users' location, you should also add the following key to `ios/Runner/Info.plist` to explain why you need access to their location data:

```
xml ...
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>[Your explanation here]</string>
```

A possible explanation could be: "Shows your location on the map".

## Documentation

This README file currently houses most of the documentation for this Flutter project. Please visit [https://github.com/maplibre/maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) and [https://github.com/maplibre/maplibre-gl-native](https://github.com/maplibre/maplibre-gl-native) for more information about the Maplibre libraries.

## Getting Help

- **Need help with your code?**: Check the [discussions](https://github.com/m0nac0/flutter-maplibre-gl/discussions) on this repo or open a new one. 
 Or look for previous questions on the [#maplibre tag](https://stackoverflow.com/questions/tagged/maplibre) — or [ask a new question](https://stackoverflow.com/questions/tagged/maplibre).
- **Have a bug to report?** [Open an issue](https://github.com/m0nac0/flutter-maplibre-gl/issues/new). If possible, include a full log and information which shows the issue.
- **Have a feature request?** [Open an issue](https://github.com/m0nac0/flutter-maplibre-gl/issues/new). Tell us what the feature should do and why you want the feature.

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




## Contributing


[Feedback](https://github.com/m0nac0/flutter-maplibre-gl/issues) and contributions are very welcome!
