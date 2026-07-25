/// Reads. Every one of these replies to the presentation side.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

/// Replies true once every message sent before it has been processed.
///
/// Messages are handled in FIFO order, so awaiting a barrier after a command
/// guarantees the command completed on the engine side. Used to order EGL
/// surface teardown between the presentation isolate (which owns the surface)
/// and the engine (which renders into it).
class BarrierQuery extends EngineQuery<bool> {
  const BarrierQuery();
}

/// Current camera state.
class GetCameraQuery extends SessionQuery<CameraSnapshot> {
  const GetCameraQuery(super.sessionId);
}

/// Visible bounds of the camera.
class GetVisibleRegionQuery extends SessionQuery<BoundsSpec> {
  const GetVisibleRegionQuery(super.sessionId);
}

/// Projects a coordinate to screen space.
class PixelForLatLngQuery extends SessionQuery<ScreenPoint> {
  const PixelForLatLngQuery(super.sessionId, this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Batch projection; [latLngPairs] is [lat0, lng0, lat1, lng1, ...] and the
/// reply is [x0, y0, x1, y1, ...].
///
/// The flat buffers are deliberate, not an oversight: this is the bulk API,
/// and packing N coordinates into one typed-data allocation is the whole
/// reason it exists next to [PixelForLatLngQuery].
class PixelsForLatLngsQuery extends SessionQuery<Float64List> {
  const PixelsForLatLngsQuery(super.sessionId, this.latLngPairs);

  final Float64List latLngPairs;
}

/// Unprojects a screen point.
class LatLngForPixelQuery extends SessionQuery<GeoPoint> {
  const LatLngForPixelQuery(super.sessionId, this.x, this.y);

  final double x;
  final double y;
}

/// Current style as a full style-spec JSON document.
class GetStyleJsonQuery extends SessionQuery<String> {
  const GetStyleJsonQuery(super.sessionId);
}

/// Style layer ids in style order.
class GetLayerIdsQuery extends SessionQuery<List<String>> {
  const GetLayerIdsQuery(super.sessionId);
}

/// Style source ids in style order.
class GetSourceIdsQuery extends SessionQuery<List<String>> {
  const GetSourceIdsQuery(super.sessionId);
}

/// A layer's style-spec filter, JSON-encoded, or null when unset or when the
/// layer does not exist.
class GetFilterQuery extends SessionQuery<String?> {
  const GetFilterQuery(super.sessionId, this.layerId);

  final String layerId;
}

/// One style-spec property of a layer, JSON-encoded, or null when unset or
/// when the layer does not exist.
class GetLayerPropertyQuery extends SessionQuery<String?> {
  const GetLayerPropertyQuery(super.sessionId, this.layerId, this.propertyName);

  final String layerId;
  final String propertyName;
}

/// Whether a layer is visible; null when the layer does not exist.
class GetLayerVisibilityQuery extends SessionQuery<bool?> {
  const GetLayerVisibilityQuery(super.sessionId, this.layerId);

  final String layerId;
}

/// Queries rendered features at a screen point or inside a screen box.
/// Replies with plain GeoJSON feature maps.
class QueryRenderedFeaturesQuery
    extends SessionQuery<List<Map<String, dynamic>>> {
  const QueryRenderedFeaturesQuery.point(
    super.sessionId, {
    required double this.x,
    required double this.y,
    this.layerIds,
    this.filter,
  }) : left = null,
       top = null,
       right = null,
       bottom = null;

  const QueryRenderedFeaturesQuery.rect(
    super.sessionId, {
    required double this.left,
    required double this.top,
    required double this.right,
    required double this.bottom,
    this.layerIds,
    this.filter,
  }) : x = null,
       y = null;

  final double? x;
  final double? y;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
  final List<String>? layerIds;
  final Object? filter;
}

/// Queries features of one source. Replies with plain GeoJSON feature maps.
class QuerySourceFeaturesQuery
    extends SessionQuery<List<Map<String, dynamic>>> {
  const QuerySourceFeaturesQuery(
    super.sessionId,
    this.sourceId, {
    this.sourceLayerId,
    this.filter,
  });

  final String sourceId;
  final String? sourceLayerId;
  final Object? filter;
}

/// The topmost hit of a [QueryTopFeatureQuery]: which layer answered, and the
/// feature itself.
///
/// [feature] stays a decoded GeoJSON map because that is what the maplibre_gl
/// API hands to apps; the layer id next to it does not have to be stringly
/// typed too.
typedef FeatureHit = ({String layerId, Map<String, dynamic> feature});

/// Ordered hit-test: queries [layerIds] one by one (topmost first) at a
/// screen point and replies with the first hit, or null. Keeps feature-tap
/// resolution to one isolate round-trip even though queried features carry no
/// layer id.
class QueryTopFeatureQuery extends SessionQuery<FeatureHit?> {
  const QueryTopFeatureQuery(
    super.sessionId, {
    required this.x,
    required this.y,
    required this.layerIds,
    this.tolerance = 0,
  });

  final double x;
  final double y;
  final List<String> layerIds;

  /// Half-size in logical pixels of the query box around (x, y); 0 queries
  /// the exact point. Used as a finger-sized touch target for drags.
  final double tolerance;
}

/// Sets per-feature state used by feature-state expressions.
class SetFeatureStateCommand extends SessionCommand {
  const SetFeatureStateCommand(
    super.sessionId, {
    required this.sourceId,
    this.sourceLayerId,
    required this.featureId,
    required this.state,
  });

  final String sourceId;
  final String? sourceLayerId;
  final String featureId;
  final Map<String, dynamic> state;
}

/// Removes per-feature state (whole source, one feature, or one key).
class RemoveFeatureStateCommand extends SessionCommand {
  const RemoveFeatureStateCommand(
    super.sessionId, {
    required this.sourceId,
    this.sourceLayerId,
    this.featureId,
    this.stateKey,
  });

  final String sourceId;
  final String? sourceLayerId;
  final String? featureId;
  final String? stateKey;
}

/// Distinct per-source attribution strings of the current style, in style
/// order (attribution ornament content).
class GetAttributionsQuery extends SessionQuery<List<String>> {
  const GetAttributionsQuery(super.sessionId);
}

/// Drains the frame statistics collected since [SetFrameStatsEnabledCommand]
/// (or since the previous drain). The reply is a plain map:
/// `clockUs` (int, elapsed collection time), `timestampsUs` (Int64List,
/// frame start times relative to enable) and `durationsUs` (Int64List,
/// per-frame `renderUpdate` wall time, CPU encode + submit).
class TakeFrameStatsQuery extends SessionQuery<Map<String, dynamic>> {
  const TakeFrameStatsQuery(super.sessionId);
}

/// Reads per-feature state; replies with a plain map or null.
class GetFeatureStateQuery extends SessionQuery<Map<String, dynamic>?> {
  const GetFeatureStateQuery(
    super.sessionId, {
    required this.sourceId,
    this.sourceLayerId,
    required this.featureId,
  });

  final String sourceId;
  final String? sourceLayerId;
  final String featureId;
}
