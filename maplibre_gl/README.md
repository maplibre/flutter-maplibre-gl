# Flutter MapLibre GL

[![Pub Version](https://img.shields.io/pub/v/maplibre_gl)](https://pub.dev/packages/maplibre_gl)
[![likes](https://img.shields.io/pub/likes/maplibre_gl?logo=flutter)](https://pub.dev/packages/maplibre_gl)
[![Pub Points](https://img.shields.io/pub/points/maplibre_gl)](https://pub.dev/packages/maplibre_gl/score)
[![stars](https://badgen.net/github/stars/maplibre/flutter-maplibre-gl?label=stars&color=green&icon=github)](https://github.com/josxha/flutter-maplibre-gl/stargazers)

This Flutter plugin allows to show **embedded interactive and customizable
vector maps** as a Flutter widget.

- This project is a fork
  of [flutter-mapbox-gl](https://github.com/tobrun/flutter-mapbox-gl),
  replacing its usage of Mapbox GL libraries with the open
  source [MapLibre GL](https://github.com/maplibre) libraries.
- The repository has been transferred to
  the [MapLibre](https://github.com/maplibre)
  organization. You shouldn't see any negative effects, as GitHub automatically
  redirects references from the old URL to the new URL. Please
  see [#221](https://github.com/maplibre/flutter-maplibre-gl/issues/221) for
  more information.

### Supported Platforms

- Support for **web** through [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js)
- Support for **android** and **iOS** through [maplibre-native](https://github.com/maplibre/maplibre-native)

This project only supports a subset of the API exposed by these libraries.

### Supported API

| Feature        | Android | iOS | Web |
|----------------|:-------:|:---:|:---:|
| Style          |    ✅    |  ✅  |  ✅  |
| Camera         |    ✅    |  ✅  |  ✅  |
| Gesture        |    ✅    |  ✅  |  ✅  |
| User Location  |    ✅    |  ✅  |  ✅  |
| Symbol         |    ✅    |  ✅  |  ✅  |
| Circle         |    ✅    |  ✅  |  ✅  |
| Line           |    ✅    |  ✅  |  ✅  |
| Fill           |    ✅    |  ✅  |  ✅  |
| Fill Extrusion |    ✅    |  ✅  |  ✅  |
| Heatmap Layer  |    ✅    |  ✅  |  ✅  |

### Android

### Web



## Map Styles

Map styles can be supplied by setting the `styleString` in the `MapLibreMap`
constructor. The following formats are supported:

1. Passing the URL of the map style. This should be a custom map style served
   remotely using a URL that start with `http(s)://`
2. Passing the style as a local asset. Create a JSON file in the `assets` and
   add a reference in `pubspec.yml`. Set the style string to the relative path
   for this asset in order to load it into the map.
3. Passing the style as a local file. create an JSON file in app directory (e.g.
   ApplicationDocumentsDirectory). Set the style string to the absolute path of
   this JSON file.
4. Passing the raw JSON of the map style. This is only supported on Android.

### Tile sources requiring an API key

If your tile source requires an API key, we recommend directly specifying a
source url with the API key included.
For example:

```console
https://tiles.example.com/{z}/{x}/{y}.vector.pbf?api_key={your_key}
```

## Documentation

- Check
  the [API documentation](https://pub.dev/documentation/maplibre_gl/latest/).
- See example implementations in
  our [example project](https://github.com/maplibre/flutter-maplibre-gl/tree/main/example).
- For more information about the MapLibre libraries
  visit [maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js)
  and [maplibre-native](https://github.com/maplibre/maplibre-native).

## Getting Help

- **Need help with your code?**: Check
  the [discussions](https://github.com/maplibre/flutter-maplibre-gl/discussions)
  on this repo or open a new one.
  Or look for previous questions on
  the [#maplibre](https://stackoverflow.com/questions/tagged/maplibre) tag —
  or [ask a new question](https://stackoverflow.com/questions/tagged/maplibre).
- **Have a bug to report?**
  [Open an issue](https://github.com/maplibre/flutter-maplibre-gl/issues/new).
  If possible, include a full log, code and information which shows the issue.
- **Have a feature request?**
  [Open an issue](https://github.com/maplibre/flutter-maplibre-gl/issues/new).
  Tell us what the feature should do and why you want the feature.

## Common problems & frequent questions

### Loading .mbtiles tile files or sprites/glyphs from the assets shipped with the app

<details>
  <summary>Click here to expand / hide.</summary>

One approach that has been used successfully to do that is to copy the files
from the app's assets directory to another directory, e.g. the app's cache
directory, and then reference that location.
See e.g. issues https://github.com/maplibre/flutter-maplibre-gl/issues/338
and https://github.com/maplibre/flutter-maplibre-gl/issues/318

---
</details>

### Avoid Android UnsatisfiedLinkError

<details>
  <summary>Click here to expand / hide.</summary>

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

---
</details>

### iOS app crashes when using location based features

<details>
  <summary>Click here to expand / hide.</summary>

Please include the `NSLocationWhenInUseUsageDescription` as
described [here](#location-features)

---
</details>

### Layer is not displayed on IOS, but no error

<details>
  <summary>Click here to expand / hide.</summary>

Have a look in your `LayerProperties` object, if you supply a `lineColor`
argument, (or any color argument) the issue might come from here.
Android supports the following format : `'rgba(192, 192, 255, 1.0)'`, but on
iOS, this doesn't work!

You have to have the color in the following format : `#C0C0FF`

---
</details>

### iOS crashes with error: `'NSInvalidArgumentException', reason: 'Invalid filter value: filter property must be a string'`

<details>
  <summary>Click here to expand / hide.</summary>

Check if one of your expression is : `["!has", "value"]`. Android support this
format, but iOS does not.
You can replace your expression with :   `["!",["has", "value"] ]` which works
both in Android and iOS.

Note : iOS will display the
error : `NSPredicate: Use of 'mgl_does:have:' as an NSExpression function is forbidden`,
but it seems like the expression still works well.

---
</details>

## Contributing

[Feedback](https://github.com/maplibre/flutter-maplibre-gl/issues),
contributing pull requests
and [bug reports](https://github.com/maplibre/flutter-maplibre-gl/issues) are
very welcome!
