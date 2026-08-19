# Startup & Performance

Three things dominate how a map-heavy app feels: how long the first map takes to appear, what the map costs while it is off screen, and how much work a data update does on the UI thread.

## Pre-warm the engine

The map engine initializes when the first `MapLibreMap` is built, and that work lands squarely in the frame the user is waiting for. `MapLibreMap.preWarm()` starts it earlier, so it overlaps app start-up instead:

```dart
void main() {
  MapLibreMap.preWarm(); // fire-and-forget, do not await
  runApp(const MyApp());
}
```

Measured at first map display, this saves roughly 170 to 480 ms on Android, 45 to 165 ms on iOS, and 10 to 50 ms on web, where the cost being moved is the MapLibre GL JS download. The spread is the range across the devices used for those measurements, so treat it as an order of magnitude and profile your own app.

!!! warning "Not for every app"
    Pre-warming is worth it when your **first screen is a map**. An app whose map is a few screens in pays for engine start-up its first screen never uses, and possibly never uses at all. The example app deliberately does not call it, because it opens on a list of examples.

Calling it more than once is harmless. It initializes the Flutter binding if the app has not done so yet, since it runs before `runApp()`; an app or test that needs a specific binding, such as `IntegrationTestWidgetsFlutterBinding`, must initialize that one first.

## Pause maps that are off screen

A map that is alive but not visible keeps rendering, which is a plain waste of GPU and battery. The most common case is a map on an inactive `TabBarView` page, or one behind a full-screen route: the widget is not disposed, so the map keeps running.

```dart
// Leaving the map's tab
await controller.pauseMap();

// Coming back
await controller.resumeMap();
```

On Android this stops the `MapView` render loop; on iOS it drops the preferred frame rate to zero; on web both calls are no-ops, so the code is safe to run unconditionally. A map paused this way stays paused across backgrounding until you call `resumeMap()`, so pair the calls with the visibility change that caused them rather than with app lifecycle events.

## Platform view mode (Android)

On Android the map is a platform view, and Flutter has several ways to embed one.
Which one you get is decided by the Android `View` the map renders into, and that
is what `MapLibreMap.useHybridComposition` controls:

- **`false` (the default, since 0.16.0)**: the map renders into a `GLSurfaceView`.
  Flutter cannot redirect a `SurfaceView`'s drawing into a texture, so it embeds
  the map through Virtual Display. The map renders as directly as Android allows,
  and you inherit Virtual Display's limitations around text input, accessibility
  and z-order.
- **`true`**: the map renders into a `TextureView`, which is MapLibre's
  `textureMode`. Flutter composites it as a texture layer, so the map behaves
  like a regular widget: Flutter content can paint over it, and the map itself
  can be transformed, clipped or animated. A `TextureView` costs more to render
  than a `SurfaceView` on every Android version.

```dart
MapLibreMap.useHybridComposition = true; // call before runApp()
```

Set it before the first map is built. The mode is fixed once a platform view
exists, so changing it later leaves maps already on screen untouched.

Two things about this flag are worth knowing. Despite the name it does not select
Flutter's "Hybrid Composition" mode: both values go through
`PlatformViewsService.initAndroidView`, and Flutter chooses Texture Layer Hybrid
Composition or Virtual Display based on the native view it finds. And the
`translucentTextureSurface` map option moves the map to a `TextureView` as well,
additionally making it non-opaque, so reach for `useHybridComposition` when you
want the texture layer with an opaque surface.

### Hybrid Composition++

Flutter's [Hybrid Composition++](https://docs.flutter.dev/platform-integration/android/platform-views)
composites platform views through the Android OS instead of through a texture, which
removes the reason to choose between the two modes above: the map keeps its
`SurfaceView` and still behaves like a widget. It needs Android 14 (API 34) or
newer, Impeller and Vulkan, and Flutter falls back to the mode configured above
on devices that do not qualify.

It is opt-in per app, not per plugin, so nothing changes on the `maplibre_gl`
side. Leave `useHybridComposition` at `false` and add this to your app's
`AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="io.flutter.embedding.android.EnableHcpp"
    android:value="true" />
```

For a local run, `flutter run --enable-hcpp` does the same thing. The flag is not
accepted by `flutter build`, which is what the manifest entry is for. It is still
experimental, so test it on the Android versions you support before shipping it.

## Keep large data updates off the UI thread

Handing a large GeoJSON payload to the map costs an encode to JSON before it can cross to the native side. On Android and iOS the plugin does that encode on a background isolate once the payload is big enough, so a line with tens of thousands of points no longer freezes the UI for the whole encode. This is automatic; see [Working with GeoJSON](../concepts/geojson.md#large-payloads) for what it does and does not buy you.

For restyling rather than reshaping data, prefer [feature state](feature-state.md) over re-feeding the source: changing one feature's color by re-sending the whole collection re-encodes and re-tessellates everything.

## Choose the right annotation API

The [annotation API](../concepts/annotations-vs-layers.md) is convenient but keeps a Dart object per annotation and re-syncs on change. Past ~50 items, a style layer over a GeoJSON source is dramatically cheaper, and [clustering](../layers/cluster.md) cheaper still.

## Key APIs

| API | Purpose |
|-----|---------|
| `MapLibreMap.preWarm()` | start engine initialization before the first map |
| `controller.pauseMap()` / `resumeMap()` | stop and restart rendering for an off-screen map |
| `MapLibreMap.useHybridComposition` | which Android view the map renders into, see [Platform view mode (Android)](#platform-view-mode-android) |
| `controller.setFeatureState()` | restyle single features without touching source data |
