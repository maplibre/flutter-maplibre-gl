---
sidebar_position: 5
---

# FAQ

### Loading .mbtiles tile files or sprites/glyphs from the assets shipped with the app

One approach that has been used successfully to do that is to copy the files
from the app's assets directory to another directory, e.g. the app's cache
directory, and then reference that location.
See e.g. issues https://github.com/maplibre/flutter-maplibre-gl/issues/338
and https://github.com/maplibre/flutter-maplibre-gl/issues/318

### Avoid Android UnsatisfiedLinkError

Update buildTypes in `android\app\build.gradle`

```gradle title="android\app\build.gradle"
buildTypes {
    release {
        // other configs
        ndk {
            abiFilters 'armeabi-v7a','arm64-v8a','x86_64', 'x86'
        }
    }
}
```

### Layer is not displayed on IOS, but no error

Have a look in your `LayerProperties` object, if you supply a `lineColor`
argument, (or any color argument) the issue might come from here.
Android supports the following format : `'rgba(192, 192, 255, 1.0)'`, but on
iOS, this doesn't work!

You have to have the color in the following format : `#C0C0FF`

### iOS crashes with error: `'NSInvalidArgumentException', reason: 'Invalid filter value: filter property must be a string'`

Check if one of your expression is : `["!has", "value"]`. Android support this
format, but iOS does not.
You can replace your expression with :   `["!",["has", "value"] ]` which works
both in Android and iOS.

Note : iOS will display the
error : `NSPredicate: Use of 'mgl_does:have:' as an NSExpression function is forbidden`,
but it seems like the expression still works well.
