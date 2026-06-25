# Map Snapshot

Capture a static image of the current map view as a `Uint8List` (PNG bytes). Use it to share, save, or display the map without requiring a live `MapLibreMap` widget.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=map-snapshot"
  title="Map Snapshot example"
  loading="lazy"
></iframe>

## Capture a snapshot

```dart
final Uint8List? bytes = await controller.takeSnapshot();

if (bytes != null) {
  // Display it in an Image widget
  final image = Image.memory(bytes);

  // Or save it to a file
  final file = File('${directory.path}/map_snapshot.png');
  await file.writeAsBytes(bytes);
}
```

The snapshot captures the current viewport exactly as rendered, including any added layers, annotations, and the camera position.

## Show snapshot in a dialog

```dart
Future<void> _shareSnapshot() async {
  final bytes = await controller.takeSnapshot();
  if (bytes == null || !mounted) return;

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
