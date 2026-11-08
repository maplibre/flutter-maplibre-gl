# Map Snapshot

Capture a static image of the current map view as a `Uint8List` (PNG bytes). Use it to share, save, or display the map without requiring a live `MapLibreMap` widget.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/demo/?example=map-snapshot"
  title="Map Snapshot example"
  loading="lazy"
></iframe>

## Capture a snapshot

```dart
final Uint8List bytes = await controller.takeSnapshot();

// Display it in an Image widget
final image = Image.memory(bytes);

// Or save it to a file
final file = File('${directory.path}/map_snapshot.png');
await file.writeAsBytes(bytes);
```

The snapshot captures the current viewport exactly as rendered, including any added layers, annotations, and the camera position.

Pass `width` and `height` in logical pixels to render at a size other than the current map view, keeping the camera position and style.

## Attribution and logo

On Android and iOS, MapLibre draws the attribution text of the style's sources and the MapLibre logo in a corner of the snapshot. Pass `attributionEnabled: false` or `logoEnabled: false` to leave one out:

```dart
// The app shows the attribution itself, next to the picture.
final bytes = await controller.takeSnapshot(
  attributionEnabled: false,
  logoEnabled: false,
);
```

These two do not follow the widget's `attributionEnabled` and `logoEnabled`. A map that hides its logo still gets the logo on its snapshot unless `logoEnabled: false` is passed to `takeSnapshot`.

Most map data licenses require the attribution to be shown. Leave it out of the snapshot only when the app shows it another way, for example as text beside the picture.

On web the snapshot never has either. The attribution and the logo are HTML elements beside the map canvas, and the snapshot is the canvas alone.

## Show snapshot in a dialog

```dart
Future<void> _shareSnapshot() async {
  final bytes = await controller.takeSnapshot();
  if (!mounted) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      content: Image.memory(bytes),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
```

## Platform support

<div class="table-scroll" markdown>
<table class="comparison-table comparison-table--centered">
  <thead>
    <tr><th>Android</th><th>iOS</th><th>Web</th></tr>
  </thead>
  <tbody>
    <tr>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
      <td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td>
    </tr>
  </tbody>
</table>
</div>

!!! note "Timing"
    Call `takeSnapshot()` after the map has fully loaded and all tiles have rendered. Taking a snapshot too early may result in a partially loaded map. Use `onStyleLoadedCallback` and wait for tiles to settle.

## Key APIs

- [`MapLibreMapController.takeSnapshot()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/takeSnapshot.html)
