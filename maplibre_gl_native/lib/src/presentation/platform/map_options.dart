import '../../utils/projection.dart';
import '../../protocol/protocol.dart';

/// Mutable gesture configuration shared between the platform adapter and the
/// map widget, mirroring the maplibre_gl widget options.
class FfiGestureConfig {
  bool scrollEnabled = true;
  bool zoomEnabled = true;
  bool rotateEnabled = true;
  bool tiltEnabled = true;
  bool doubleClickZoomEnabled = true;
}

/// Applies the gesture keys of a maplibre_gl options map.
///
/// This file is the one place that knows the maplibre_gl option key names, so
/// a renamed or added option has exactly one place to be handled.
void applyGestureOptions(
  Map<String, dynamic> options, {
  required FfiGestureConfig gestures,
  required void Function(bool enabled) setFeatureTapsTriggersMapClick,
}) {
  void apply(String key, void Function(bool) setter) {
    final value = options[key];
    if (value is bool) setter(value);
  }

  apply('scrollGesturesEnabled', (v) => gestures.scrollEnabled = v);
  apply('zoomGesturesEnabled', (v) => gestures.zoomEnabled = v);
  apply('rotateGesturesEnabled', (v) => gestures.rotateEnabled = v);
  apply('tiltGesturesEnabled', (v) => gestures.tiltEnabled = v);
  apply('doubleClickZoomEnabled', (v) => gestures.doubleClickZoomEnabled = v);
  apply('featureTapsTriggersMapClick', setFeatureTapsTriggersMapClick);
}

/// The camera constraint commands a maplibre_gl options map asks for, in the
/// order they must be sent; empty when it constrains nothing.
List<SessionCommand> cameraConstraintCommands(
  Map<String, dynamic> options,
  int sessionId,
) {
  final commands = <SessionCommand>[];

  // CameraTargetBounds.toJson() is [boundsListOrNull] where the bounds list
  // is [[swLat, swLng], [neLat, neLng]]; a null entry means unbounded.
  final targetBounds = options['cameraTargetBounds'];
  if (targetBounds is List) {
    final bounds = targetBounds.isEmpty ? null : targetBounds[0] as List?;
    final southwest = bounds?[0] as List?;
    final northeast = bounds?[1] as List?;
    commands.add(
      SetBoundsCommand(
        sessionId,
        // World bounds clear a previous constraint.
        southwestLatitude:
            (southwest?[0] as num?)?.toDouble() ?? MapLimits.worldSouthLatitude,
        southwestLongitude:
            (southwest?[1] as num?)?.toDouble() ?? MapLimits.worldWestLongitude,
        northeastLatitude:
            (northeast?[0] as num?)?.toDouble() ?? MapLimits.worldNorthLatitude,
        northeastLongitude:
            (northeast?[1] as num?)?.toDouble() ?? MapLimits.worldEastLongitude,
      ),
    );
  }

  // MinMaxZoomPreference.toJson() is [minZoom, maxZoom] with null meaning
  // unbounded on that side.
  final minMaxZoom = options['minMaxZoomPreference'];
  if (minMaxZoom is List && minMaxZoom.length >= 2) {
    commands.add(
      SetBoundsCommand(
        sessionId,
        // The projection limits clear a previous preference.
        minZoom: (minMaxZoom[0] as num?)?.toDouble() ?? MapLimits.minZoom,
        maxZoom: (minMaxZoom[1] as num?)?.toDouble() ?? MapLimits.maxZoom,
      ),
    );
  }
  return commands;
}
