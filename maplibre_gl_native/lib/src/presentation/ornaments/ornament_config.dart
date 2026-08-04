import 'package:flutter/foundation.dart';

/// Map corner an ornament is pinned to.
///
/// The wire values are the maplibre_gl option indexes, which is the only
/// reason the order matters.
enum OrnamentPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight
  ;

  /// Reads a maplibre_gl `*ViewPosition` option value, keeping [fallback]
  /// when it is out of range.
  static OrnamentPosition fromOptionIndex(
    int index,
    OrnamentPosition fallback,
  ) {
    return index >= 0 && index < values.length ? values[index] : fallback;
  }

  bool get isLeft => this == topLeft || this == bottomLeft;
  bool get isTop => this == topLeft || this == topRight;
}

/// Placement of one ornament: which corner, and how far from it.
class OrnamentPlacement {
  const OrnamentPlacement(this.position, this.margins);

  final OrnamentPosition position;

  /// Distance from the corner in logical pixels, as [x, y].
  final List<int> margins;

  OrnamentPlacement withExtraX(double extra) =>
      OrnamentPlacement(position, [(margins[0] + extra).round(), margins[1]]);
}

/// Ornament (compass, attribution, logo, scale bar) configuration shared
/// between the platform and the map widget; notifies the widget on change.
///
/// A [ChangeNotifier] because these values decide what is in the widget tree
/// and where: enabling the compass or moving the scale bar has to rebuild. The
/// gesture flags (`GestureConfig`) are a plain object for the opposite
/// reason: they are read per touch sample and rebuild nothing.
class OrnamentConfig extends ChangeNotifier {
  bool compassEnabled = true;
  OrnamentPlacement compass = const OrnamentPlacement(
    OrnamentPosition.topRight,
    [8, 8],
  );

  bool attributionEnabled = true;
  OrnamentPlacement attribution = const OrnamentPlacement(
    OrnamentPosition.bottomRight,
    [8, 8],
  );

  bool logoEnabled = true;
  OrnamentPlacement logo = const OrnamentPlacement(
    OrnamentPosition.bottomLeft,
    [8, 8],
  );

  /// Process-wide default for [scaleBarEnabled], applied to every
  /// subsequently created config. Set through the public
  /// `MapLibreGlNative.scaleBarEnabled`.
  static bool scaleBarEnabledDefault = false;

  /// The scale bar has no maplibre_gl option key (the Android SDK has no
  /// scale bar ornament), so it is opt-in via
  /// `MapLibreGlNative.scaleBarEnabled` and off by default.
  bool scaleBarEnabled = scaleBarEnabledDefault;
  OrnamentPlacement scaleBar = const OrnamentPlacement(
    OrnamentPosition.topLeft,
    [8, 8],
  );

  /// Applies the ornament keys of a maplibre_gl options map.
  void applyOptions(Map<String, dynamic> options) {
    var changed = false;

    bool boolOf(String key, bool current) {
      final value = options[key];
      if (value is bool && value != current) changed = true;
      return value is bool ? value : current;
    }

    OrnamentPlacement placementOf(
      String positionKey,
      String marginsKey,
      OrnamentPlacement current,
    ) {
      var position = current.position;
      final positionValue = options[positionKey];
      if (positionValue is int) {
        position = OrnamentPosition.fromOptionIndex(positionValue, position);
      }
      var margins = current.margins;
      final marginsValue = options[marginsKey];
      if (marginsValue is List && marginsValue.length >= 2) {
        margins = [
          (marginsValue[0] as num).toInt(),
          (marginsValue[1] as num).toInt(),
        ];
      }
      if (position == current.position &&
          margins[0] == current.margins[0] &&
          margins[1] == current.margins[1]) {
        return current;
      }
      changed = true;
      return OrnamentPlacement(position, margins);
    }

    compassEnabled = boolOf('compassEnabled', compassEnabled);
    compass = placementOf('compassViewPosition', 'compassViewMargins', compass);
    attributionEnabled = boolOf('attributionButtonEnabled', attributionEnabled);
    attribution = placementOf(
      'attributionButtonPosition',
      'attributionButtonMargins',
      attribution,
    );
    logoEnabled = boolOf('logoEnabled', logoEnabled);
    logo = placementOf('logoViewPosition', 'logoViewMargins', logo);
    if (changed) notifyListeners();
  }
}
