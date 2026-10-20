import 'package:web/web.dart' as web;

/// Applies the Dart `MyLocationStyle` to the user-location puck of one map.
///
/// Both pucks the web plugin can show, the browser `GeolocateControl` one and
/// the `ManualLocationPuck`, are built from maplibre-gl-js'
/// `maplibregl-user-location-*` classes. So the colors are CSS rules for those
/// classes, scoped to this map's container through a class unique to the map,
/// in a `<style>` element that lives inside the container and goes away with
/// it.
class LocationPuckStyler {
  LocationPuckStyler(this._container);

  final web.HTMLElement _container;
  web.HTMLStyleElement? _styleElement;

  static int _nextId = 0;
  final String _scopeClass = 'maplibre-gl-puck-style-${_nextId++}';

  /// Applies the map written by `MyLocationStyle.toJson`. An empty map, or one
  /// that customizes nothing, restores maplibre-gl-js' own look.
  void apply(Map<String, dynamic> style) {
    final css = locationPuckCss('.$_scopeClass', style);
    if (css.isEmpty) {
      _styleElement?.remove();
      _styleElement = null;
      _container.classList.remove(_scopeClass);
      return;
    }
    _container.classList.add(_scopeClass);
    final element =
        _styleElement ??=
            web.document.createElement('style') as web.HTMLStyleElement;
    element.textContent = css;
    if (element.parentNode == null) _container.appendChild(element);
  }
}

/// The CSS for [style] (`MyLocationStyle.toJson`), with every rule scoped to
/// [scope]. Empty when nothing is customized.
String locationPuckCss(String scope, Map<String, dynamic> style) {
  final rules = <String>[];
  const dot = '.maplibregl-user-location-dot';

  final fill = style['fillColor'];
  if (fill is int) {
    // A stale browser fix keeps maplibre-gl-js' grey, as Android does.
    rules.add(
      '$scope $dot:not(.maplibregl-user-location-dot-stale)'
      ' { background-color: ${_rgba(fill)}; }',
    );
  }

  final pulseEnabled = style['pulseEnabled'];
  final pulse = style['pulseColor'];
  if (pulseEnabled == false) {
    rules.add('$scope $dot::before { display: none; }');
  } else if (pulse is int) {
    rules.add('$scope $dot::before { background-color: ${_rgba(pulse)}; }');
  }

  const accuracy = '.maplibregl-user-location-accuracy-circle';
  final accuracyColor = style['accuracyColor'];
  if (style['accuracyCircleEnabled'] == false) {
    // `!important` beats the inline `display` the manual puck writes.
    rules.add('$scope $accuracy { display: none !important; }');
  } else if (accuracyColor is int) {
    // Only the color channels are used: the circle keeps maplibre-gl-js' own
    // 20% opacity, as Android and iOS keep theirs.
    rules.add(
      '$scope $accuracy'
      ' { background-color: ${_rgba(accuracyColor, alpha: 0.2)}; }',
    );
  }

  final bearing = style['bearingColor'];
  if (bearing is int) {
    rules.add(
      '$scope .maplibre-gl-manual-location-arrow'
      ' { border-bottom-color: ${_rgba(bearing)}; }',
    );
  }

  return rules.join('\n');
}

/// A CSS color from an ARGB int, with [alpha] in place of its own when given.
String _rgba(int argb, {double? alpha}) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final a = alpha ?? ((argb >> 24) & 0xFF) / 255;
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}
