package org.maplibre.maplibregl;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import java.util.Map;
import org.maplibre.android.location.LocationComponentOptions;

/**
 * The puck colors set through the Dart {@code MyLocationStyle}. A null field keeps the SDK
 * default. The controller applies them every time it builds its {@link
 * LocationComponentOptions}, so they survive the restyles that follow added layers.
 */
final class LocationPuckStyle {
  static final LocationPuckStyle DEFAULT = new LocationPuckStyle(null, null, null, true, null, null);

  @Nullable private final Integer fillColor;
  @Nullable private final Integer bearingColor;
  @Nullable private final Integer accuracyColor;
  private final boolean accuracyCircleEnabled;
  @Nullable private final Boolean pulseEnabled;
  @Nullable private final Integer pulseColor;

  private LocationPuckStyle(
      @Nullable Integer fillColor,
      @Nullable Integer bearingColor,
      @Nullable Integer accuracyColor,
      boolean accuracyCircleEnabled,
      @Nullable Boolean pulseEnabled,
      @Nullable Integer pulseColor) {
    this.fillColor = fillColor;
    this.bearingColor = bearingColor;
    this.accuracyColor = accuracyColor;
    this.accuracyCircleEnabled = accuracyCircleEnabled;
    this.pulseEnabled = pulseEnabled;
    this.pulseColor = pulseColor;
  }

  /** Reads the map written by {@code MyLocationStyle.toJson}. */
  static LocationPuckStyle fromMap(@NonNull Map<?, ?> data) {
    final Object accuracyCircleEnabled = data.get("accuracyCircleEnabled");
    final Object pulseEnabled = data.get("pulseEnabled");
    return new LocationPuckStyle(
        color(data.get("fillColor")),
        color(data.get("bearingColor")),
        color(data.get("accuracyColor")),
        accuracyCircleEnabled == null || Convert.toBoolean(accuracyCircleEnabled),
        pulseEnabled == null ? null : Convert.toBoolean(pulseEnabled),
        color(data.get("pulseColor")));
  }

  @Nullable
  private static Integer color(@Nullable Object value) {
    return value == null ? null : Convert.toInt(value);
  }

  void applyTo(@NonNull LocationComponentOptions.Builder builder) {
    if (fillColor != null) {
      builder.foregroundTintColor(fillColor);
    }
    if (bearingColor != null) {
      builder.bearingTintColor(bearingColor);
    }
    if (accuracyColor != null) {
      // The circle keeps the SDK's own translucency (accuracyAlpha), as on iOS
      // and web, so only the color channels are used.
      builder.accuracyColor(accuracyColor | 0xFF000000);
    }
    if (!accuracyCircleEnabled) {
      builder.accuracyAlpha(0f);
    }
    if (pulseEnabled != null) {
      builder.pulseEnabled(pulseEnabled);
    }
    if (pulseColor != null) {
      builder.pulseColor(pulseColor);
    }
  }
}
