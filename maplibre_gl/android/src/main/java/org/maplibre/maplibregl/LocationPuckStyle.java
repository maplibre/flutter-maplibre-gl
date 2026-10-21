package org.maplibre.maplibregl;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
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

  /** Reads the {@code myLocationStyle} of the map options. */
  static LocationPuckStyle from(@NonNull PgMyLocationStyle style) {
    return new LocationPuckStyle(
        color(style.getFillColor()),
        color(style.getBearingColor()),
        color(style.getAccuracyColor()),
        style.getAccuracyCircleEnabled(),
        style.getPulseEnabled(),
        color(style.getPulseColor()));
  }

  /** {@code value}, an ARGB color, as an Android color int: its low 32 bits. */
  @Nullable
  private static Integer color(@Nullable Long value) {
    return value == null ? null : value.intValue();
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
