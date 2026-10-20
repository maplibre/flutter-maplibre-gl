part of '../maplibre_gl_web.dart';

abstract class MapLibreMapOptionsSink {
  // TODO: replace with CameraPosition.Builder target
  void setCameraTargetBounds(LatLngBounds? bounds);

  void setCompassEnabled(bool compassEnabled);

  // TODO: styleString is not actually a part of options. consider moving
  void setStyle(dynamic styleObject);

  void setMinMaxZoomPreference(num? min, num? max);

  void setGestures({
    required bool rotateGesturesEnabled,
    required bool scrollGesturesEnabled,
    required bool tiltGesturesEnabled,
    required bool zoomGesturesEnabled,
    required bool doubleClickZoomEnabled,
    PanInertia panInertia = PanInertia.normal,
  });

  void setTrackCameraPosition(bool trackCameraPosition);

  void setMyLocationEnabled(bool myLocationEnabled);

  void setMyLocationTrackingMode(int myLocationTrackingMode);

  void setMyLocationRenderMode(int myLocationRenderMode);

  /// Colors of the user-location puck, as written by `MyLocationStyle.toJson`.
  void setMyLocationStyle(Map<String, dynamic> style);

  void setLogoViewAlignment(LogoViewPosition position);

  void setLogoViewMargins(int x, int y);

  void setCompassAlignment(CompassViewPosition position);

  void setCompassViewMargins(int x, int y);

  void setAttributionEnabled(bool enabled);

  void setAttributionButtonAlignment(AttributionButtonPosition position);

  void setAttributionButtonMargins(int x, int y);

  void setScaleControlEnabled(bool enabled);

  void setScaleControlPosition(ScaleControlPosition position);

  void setScaleControlUnit(ScaleControlUnit unit);

  void setFeatureTapsTriggersMapClick(bool triggers);

  void setSymbolPlacementTransitionsEnabled(bool enabled);

  void setLocationSource(String token);

  void setLocationEngineProperties({
    required bool enableHighAccuracy,
    required int maximumAge,
    required int timeout,
  });
}
