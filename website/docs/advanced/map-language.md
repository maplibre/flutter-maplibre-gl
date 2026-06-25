# Map Language

Switch the map label language at runtime without reloading the style. Useful for multi-language apps or when you want to match the device locale.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=map-language"
  title="Map Language example"
  loading="lazy"
></iframe>

## Set map language

```dart
await controller.setMapLanguage('fr'); // French
await controller.setMapLanguage('de'); // German
await controller.setMapLanguage('es'); // Spanish
await controller.setMapLanguage('ja'); // Japanese
await controller.setMapLanguage('en'); // English (default for most styles)
```

The language code is an ISO 639-1 two-letter code.

## Match device locale

```dart
import 'dart:ui';

final locale = PlatformDispatcher.instance.locale;
final lang = locale.languageCode; // e.g. 'it', 'en', 'fr'

await controller.setMapLanguage(lang);
```

## Language availability

Not all tile sources include multilingual labels. Support depends on your tile provider:

<div class="table-scroll" markdown>
<table class="comparison-table">
  <thead>
    <tr><th>Provider</th><th>Multilingual support</th></tr>
  </thead>
  <tbody>
    <tr><td>OpenFreeMap Liberty</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes (<code>name:en</code>, <code>name:fr</code>, <code>name:de</code>, etc.)</span></td></tr>
    <tr><td>OpenMapTiles</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes</span></td></tr>
    <tr><td>Protomaps</td><td><span class="cell-ic"><span class="ic ic--yes">✔</span> Yes (<code>name:en</code> and native)</span></td></tr>
    <tr><td>Custom raster tiles</td><td><span class="cell-ic"><span class="ic ic--no">✘</span> No (labels are baked into the image)</span></td></tr>
  </tbody>
</table>
</div>

!!! note
    `setMapLanguage()` works by updating `text-field` expressions in all symbol layers that contain name fields. If your custom style uses non-standard property names, this method may not affect all labels.

## Key APIs

- [`MapLibreMapController.setMapLanguage()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/setMapLanguage.html)
