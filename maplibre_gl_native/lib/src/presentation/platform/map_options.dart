import '../../utils/projection.dart';
import '../../protocol/protocol.dart';

/// Mutable gesture configuration shared between the platform adapter and the
/// map widget, mirroring the maplibre_gl widget options.
///
/// A plain mutable object, deliberately not a [ChangeNotifier] like
/// `OrnamentConfig`: these flags are read at the moment a gesture is
/// sampled, so a change takes effect on the next touch sample and nothing has
/// to rebuild. Ornaments instead affect the widget tree, which is why that one
/// notifies.
class GestureConfig {
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
  required GestureConfig gestures,
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
    final entry = targetBounds.isEmpty ? null : targetBounds[0];
    if (entry == null) {
      // No bounds list at all is CameraTargetBounds.unbounded, which removes
      // the constraint rather than widening it to the world: world bounds
      // would still clamp longitude and stop the map crossing the
      // antimeridian.
      commands.add(
        SetBoundsCommand(
          sessionId,
          bounds: const BoundsConstraintSpec.unbounded(),
        ),
      );
    } else {
      // A malformed bounds list constrains nothing: skipping the command
      // leaves the previous constraint in place, instead of crashing the
      // whole options batch or silently unbounding the camera.
      final bounds = _boundsSpec(entry);
      if (bounds != null) {
        commands.add(
          SetBoundsCommand(
            sessionId,
            bounds: BoundsConstraintSpec.bounded(bounds),
          ),
        );
      }
    }
  }

  // MinMaxZoomPreference.toJson() is [minZoom, maxZoom] with null meaning
  // unbounded on that side.
  final minMaxZoom = options['minMaxZoomPreference'];
  if (minMaxZoom is List && minMaxZoom.length >= 2) {
    final minZoom = minMaxZoom[0];
    final maxZoom = minMaxZoom[1];
    commands.add(
      SetBoundsCommand(
        sessionId,
        // The projection limits clear a previous preference; a non-numeric
        // value clears that side too rather than crashing the batch.
        minZoom: minZoom is num ? minZoom.toDouble() : MapLimits.minZoom,
        maxZoom: maxZoom is num ? maxZoom.toDouble() : MapLimits.maxZoom,
      ),
    );
  }
  return commands;
}

/// The `[[swLat, swLng], [neLat, neLng]]` shape as a [BoundsSpec], or null
/// when [entry] does not have that shape.
BoundsSpec? _boundsSpec(Object entry) {
  if (entry is! List || entry.length < 2) return null;
  final southwest = entry[0];
  final northeast = entry[1];
  if (southwest is! List || southwest.length < 2) return null;
  if (northeast is! List || northeast.length < 2) return null;
  final south = southwest[0];
  final west = southwest[1];
  final north = northeast[0];
  final east = northeast[1];
  if (south is! num || west is! num || north is! num || east is! num) {
    return null;
  }
  return BoundsSpec(
    south: south.toDouble(),
    west: west.toDouble(),
    north: north.toDouble(),
    east: east.toDouble(),
  );
}
