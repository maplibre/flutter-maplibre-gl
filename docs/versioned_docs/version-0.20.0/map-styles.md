---
sidebar_position: 3
---

# Map Styles

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

## Tile sources that require an API key

If your tile source requires an API key, we recommend directly specifying a
source url with the API key included.
For example:

```url
https://tiles.example.com/{z}/{x}/{y}.vector.pbf?api_key={your_key}
```