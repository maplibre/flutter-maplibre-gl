# Animated Annotations

Smoothly animate annotation position changes using Flutter's animation system.

<iframe
  class="example-iframe"
  src="/flutter-maplibre-gl/?example=edit-annotation-animated"
  title="Edit Annotation Animated example"
  loading="lazy"
></iframe>

## How it works

Annotation positions are updated via `updateSymbol()`. By driving updates from a Flutter `AnimationController`, you get smooth motion at the Flutter tick rate (typically 60fps).

## Animate a symbol position

```dart
late AnimationController _animationController;
late Animation<double> _animation;
Symbol? _symbol;

@override
void initState() {
  super.initState();
  _animationController = AnimationController(
    duration: const Duration(seconds: 2),
    vsync: this,
  );
  _animation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeInOut,
  );
}

void _startAnimation(LatLng from, LatLng to) {
  _animation.addListener(() {
    final t = _animation.value;
    final lat = from.latitude + (to.latitude - from.latitude) * t;
    final lng = from.longitude + (to.longitude - from.longitude) * t;
    controller.updateSymbol(
      _symbol!,
      SymbolOptions(geometry: LatLng(lat, lng)),
    );
  });
  _animationController.forward(from: 0);
}
```

Or using `lerpDouble` from `dart:ui`:

```dart
_animationController.addListener(() {
  final lat = lerpDouble(start.latitude, end.latitude, _animation.value)!;
  final lng = lerpDouble(start.longitude, end.longitude, _animation.value)!;
  controller.updateSymbol(
    symbol,
    SymbolOptions(geometry: LatLng(lat, lng)),
  );
});
_animationController.forward();
```

## Animate bearing (icon rotation)

```dart
_animationController.addListener(() {
  final bearing = lerpDouble(startBearing, endBearing, _animation.value)!;
  controller.updateSymbol(
    symbol,
    SymbolOptions(iconRotate: bearing),
  );
});
```

This is useful for animated vehicle icons that rotate to face the direction of travel.

## Continuous tracking animation

For real-time tracking (GPS updates), restart the animation on each new position:

```dart
void onNewPosition(LatLng newPos) {
  final fromPos = _currentPos;
  _currentPos = newPos;
  _animationController.value = 0;
  _from = fromPos;
  _to = newPos;
  _animationController.forward();
}
```

!!! tip "Performance"
    `updateSymbol()` triggers a style update on every frame. For very fast animations or many symbols simultaneously, consider switching to [Style Layers](../concepts/annotations-vs-layers.md) with `setGeoJsonFeature()`, which batches updates more efficiently.

## Key APIs

- [`MapLibreMapController.updateSymbol()`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController/updateSymbol.html)
- [`SymbolOptions.geometry`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolOptions/geometry.html)
- [`SymbolOptions.iconRotate`](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/SymbolOptions/iconRotate.html)
