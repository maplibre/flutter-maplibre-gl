/// Message protocol between the presentation layer (widget, gestures, the
/// `MapLibrePlatform` adapter) and the engine core that owns every MapLibre
/// Native handle.
///
/// Every message crosses a SendPort to the engine isolate, so every field in
/// this file must stay isolate-sendable: numbers, strings, bools, lists,
/// maps, and typed data only. No mln.* types, no closures.
library;

import 'dart:typed_data';

/// Base type of everything the presentation side sends to the engine.
sealed class EngineMessage {
  const EngineMessage();
}

/// A mutation. Fire-and-forget: no reply value.
sealed class EngineCommand extends EngineMessage {
  const EngineCommand();
}

/// A read. Produces a reply of type [R].
sealed class EngineQuery<R> extends EngineMessage {
  const EngineQuery();
}

/// A command that targets one live map session.
sealed class SessionCommand extends EngineCommand {
  const SessionCommand(this.sessionId);

  final int sessionId;
}

/// A query that targets one live map session.
sealed class SessionQuery<R> extends EngineQuery<R> {
  const SessionQuery(this.sessionId);

  final int sessionId;
}

/// Partial camera state; null fields are left unchanged by the engine.
class CameraSpec {
  const CameraSpec({
    this.latitude,
    this.longitude,
    this.zoom,
    this.bearing,
    this.pitch,
  });

  final double? latitude;
  final double? longitude;
  final double? zoom;
  final double? bearing;
  final double? pitch;
}

/// Complete camera state pushed by the engine (events, [GetCameraQuery]).
class CameraSnapshot {
  const CameraSnapshot({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    required this.bearing,
    required this.pitch,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double bearing;
  final double pitch;
}

// --- Session lifecycle -------------------------------------------------------

/// Render backend of a session's native surface. Must match the backend the
/// bundled MapLibre Native library was compiled with.
enum SessionBackend { opengl, vulkan }

/// Creates a map plus its render session over an existing native surface
/// (EGLSurface or VkSurfaceKHR depending on [backend]).
/// Replies with the engine-assigned session id.
class CreateSessionQuery extends EngineQuery<int> {
  /// Session over an EGL window surface (OpenGL build of the native library).
  const CreateSessionQuery.opengl({
    required this.textureId,
    required this.surface,
    required int this.eglDisplay,
    required int this.eglConfig,
    required int this.eglContext,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.scaleFactor,
  }) : backend = SessionBackend.opengl,
       vkInstance = null,
       vkPhysicalDevice = null,
       vkDevice = null,
       vkQueue = null,
       vkQueueFamilyIndex = null,
       vkGetInstanceProcAddr = null,
       vkGetDeviceProcAddr = null;

  /// Session over a VkSurfaceKHR (Vulkan build of the native library).
  const CreateSessionQuery.vulkan({
    required this.textureId,
    required this.surface,
    required int this.vkInstance,
    required int this.vkPhysicalDevice,
    required int this.vkDevice,
    required int this.vkQueue,
    required int this.vkQueueFamilyIndex,
    required int this.vkGetInstanceProcAddr,
    required int this.vkGetDeviceProcAddr,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.scaleFactor,
  }) : backend = SessionBackend.vulkan,
       eglDisplay = null,
       eglConfig = null,
       eglContext = null;

  final int textureId;
  final SessionBackend backend;

  /// Backend surface handle: EGLSurface (opengl) or VkSurfaceKHR (vulkan).
  final int surface;

  // OpenGL context (backend == opengl).
  final int? eglDisplay;
  final int? eglConfig;
  final int? eglContext;

  // Vulkan context (backend == vulkan).
  final int? vkInstance;
  final int? vkPhysicalDevice;
  final int? vkDevice;
  final int? vkQueue;
  final int? vkQueueFamilyIndex;
  final int? vkGetInstanceProcAddr;
  final int? vkGetDeviceProcAddr;

  final int logicalWidth;
  final int logicalHeight;
  final double scaleFactor;
}

/// The platform destroyed the producer surface; detach the render target.
class SurfaceLostCommand extends SessionCommand {
  const SurfaceLostCommand(super.sessionId);
}

/// Re-attaches the render target to a freshly recreated EGL surface.
class AttachSurfaceCommand extends SessionCommand {
  const AttachSurfaceCommand(super.sessionId, {required this.eglSurface});

  final int eglSurface;
}

/// Resizes the render target; the EGL surface was recreated by the platform.
class ResizeSessionCommand extends SessionCommand {
  const ResizeSessionCommand(
    super.sessionId, {
    required this.logicalWidth,
    required this.logicalHeight,
    required this.scaleFactor,
    required this.eglSurface,
  });

  final int logicalWidth;
  final int logicalHeight;
  final double scaleFactor;
  final int eglSurface;
}

/// Tears down the render session and the map.
class DisposeSessionCommand extends SessionCommand {
  const DisposeSessionCommand(super.sessionId);
}

/// Marks the session dirty so the next tick renders a frame.
class RequestRenderCommand extends SessionCommand {
  const RequestRenderCommand(super.sessionId);
}

// --- Camera ------------------------------------------------------------------

/// Instant camera move; null [CameraSpec] fields stay unchanged.
class JumpToCommand extends SessionCommand {
  const JumpToCommand(
    super.sessionId,
    this.camera, {
    this.anchorX,
    this.anchorY,
  });

  final CameraSpec camera;
  final double? anchorX;
  final double? anchorY;
}

/// Animated camera move. [easing] is a cubic bezier as [x1, y1, x2, y2].
class EaseToCommand extends SessionCommand {
  const EaseToCommand(
    super.sessionId,
    this.camera, {
    required this.durationMs,
    this.easing,
  });

  final CameraSpec camera;
  final double durationMs;
  final List<double>? easing;
}

/// Pans by a screen-space delta in logical pixels.
class MoveByCommand extends SessionCommand {
  const MoveByCommand(super.sessionId, this.dx, this.dy, {this.durationMs});

  final double dx;
  final double dy;
  final double? durationMs;
}

/// Multiplies the map scale around an optional screen-space anchor.
class ScaleByCommand extends SessionCommand {
  const ScaleByCommand(
    super.sessionId,
    this.factor, {
    this.anchorX,
    this.anchorY,
    this.durationMs,
  });

  final double factor;
  final double? anchorX;
  final double? anchorY;
  final double? durationMs;
}

/// Rotates by a bearing delta in degrees around a screen-space anchor.
/// The engine reads the current bearing, so gesture streams never need a
/// camera round-trip.
class RotateByCommand extends SessionCommand {
  const RotateByCommand(
    super.sessionId,
    this.deltaDegrees, {
    required this.anchorX,
    required this.anchorY,
  });

  final double deltaDegrees;
  final double anchorX;
  final double anchorY;
}

/// Changes the pitch by a delta in degrees, clamped to [minPitch, maxPitch].
class PitchByCommand extends SessionCommand {
  const PitchByCommand(
    super.sessionId,
    this.deltaDegrees, {
    this.minPitch = 0,
    this.maxPitch = 60,
  });

  final double deltaDegrees;
  final double minPitch;
  final double maxPitch;
}

/// Moves the camera so the given bounds fit the viewport with padding.
class FitBoundsCommand extends SessionCommand {
  const FitBoundsCommand(
    super.sessionId, {
    required this.southwestLatitude,
    required this.southwestLongitude,
    required this.northeastLatitude,
    required this.northeastLongitude,
    required this.paddingLeft,
    required this.paddingTop,
    required this.paddingRight,
    required this.paddingBottom,
    this.durationMs,
    this.easing,
  });

  final double southwestLatitude;
  final double southwestLongitude;
  final double northeastLatitude;
  final double northeastLongitude;
  final double paddingLeft;
  final double paddingTop;
  final double paddingRight;
  final double paddingBottom;
  final double? durationMs;
  final List<double>? easing;
}

/// Cancels any in-flight camera transition (gesture start).
class CancelTransitionsCommand extends SessionCommand {
  const CancelTransitionsCommand(super.sessionId);
}

/// Brackets a live touch gesture (platform SDK parity: set on touch down,
/// cleared on touch up) so the core treats the camera writes as one gesture.
class SetGestureInProgressCommand extends SessionCommand {
  const SetGestureInProgressCommand(
    super.sessionId, {
    required this.inProgress,
  });

  final bool inProgress;
}

/// Constrains the camera. Null fields are left unchanged; to clear a bounds
/// constraint pass world bounds.
class SetBoundsCommand extends SessionCommand {
  const SetBoundsCommand(
    super.sessionId, {
    this.southwestLatitude,
    this.southwestLongitude,
    this.northeastLatitude,
    this.northeastLongitude,
    this.minZoom,
    this.maxZoom,
    this.minPitch,
    this.maxPitch,
  });

  final double? southwestLatitude;
  final double? southwestLongitude;
  final double? northeastLatitude;
  final double? northeastLongitude;
  final double? minZoom;
  final double? maxZoom;
  final double? minPitch;
  final double? maxPitch;
}

/// Sets the camera viewport padding (content insets) in logical pixels.
class SetPaddingCommand extends SessionCommand {
  const SetPaddingCommand(
    super.sessionId, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.durationMs,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double? durationMs;
}

// --- Style -------------------------------------------------------------------

/// Loads a style from a URL or an inline JSON document (auto-detected).
class SetStyleCommand extends SessionCommand {
  const SetStyleCommand(super.sessionId, this.styleString);

  final String styleString;
}

/// Adds a style source from its style-spec JSON representation.
class AddSourceJsonCommand extends SessionCommand {
  const AddSourceJsonCommand(super.sessionId, this.sourceId, this.source);

  final String sourceId;
  final Map<String, dynamic> source;
}

/// Adds a style layer from its style-spec JSON representation.
class AddLayerJsonCommand extends SessionCommand {
  const AddLayerJsonCommand(super.sessionId, this.layer, {this.beforeLayerId});

  final Map<String, dynamic> layer;
  final String? beforeLayerId;
}

/// Removes a style source by id.
class RemoveSourceCommand extends SessionCommand {
  const RemoveSourceCommand(super.sessionId, this.sourceId);

  final String sourceId;
}

/// Removes a style layer by id.
class RemoveLayerCommand extends SessionCommand {
  const RemoveLayerCommand(super.sessionId, this.layerId);

  final String layerId;
}

/// Replaces the data of an existing GeoJSON source with a decoded GeoJSON
/// document (FeatureCollection, Feature, or bare geometry).
class SetGeoJsonSourceDataCommand extends SessionCommand {
  const SetGeoJsonSourceDataCommand(super.sessionId, this.sourceId, this.data);

  final String sourceId;
  final Map<String, dynamic> data;
}

/// Points an existing GeoJSON source at a new data URL.
class SetGeoJsonSourceUrlCommand extends SessionCommand {
  const SetGeoJsonSourceUrlCommand(super.sessionId, this.sourceId, this.url);

  final String sourceId;
  final String url;
}

/// Toggles the style's symbol placement cross-fade (style default: enabled).
/// The platform disables it for the duration of a feature drag so symbol
/// position updates apply instantly instead of fading over ~300ms.
class SetPlacementTransitionsCommand extends SessionCommand {
  const SetPlacementTransitionsCommand(
    super.sessionId, {
    required this.enabled,
  });

  final bool enabled;
}

/// Updates a single feature inside a GeoJSON source. The engine merges the
/// feature into its cached copy of the source document (matched by id) and
/// re-sets the source, so only the patched feature crosses the boundary.
class SetGeoJsonFeatureCommand extends SessionCommand {
  const SetGeoJsonFeatureCommand(super.sessionId, this.sourceId, this.feature);

  final String sourceId;
  final Map<String, dynamic> feature;
}

/// Sets style-spec properties on an existing layer by name. Paint and layout
/// properties share the single name-based native accessor.
class SetLayerPropertiesCommand extends SessionCommand {
  const SetLayerPropertiesCommand(
    super.sessionId,
    this.layerId,
    this.properties,
  );

  final String layerId;
  final Map<String, dynamic> properties;
}

/// Sets (or clears, when null) the style-spec filter of a layer.
class SetFilterCommand extends SessionCommand {
  const SetFilterCommand(super.sessionId, this.layerId, this.filter);

  final String layerId;
  final Object? filter;
}

/// Registers a runtime style image (sprite) from raw premultiplied RGBA8
/// pixels, decoded on the presentation side.
class SetStyleImageCommand extends SessionCommand {
  const SetStyleImageCommand(
    super.sessionId,
    this.name,
    this.rgba, {
    required this.width,
    required this.height,
    this.pixelRatio = 1,
    this.sdf = false,
  });

  final String name;
  final Uint8List rgba;
  final int width;
  final int height;
  final double pixelRatio;
  final bool sdf;
}

/// Adds an image source from raw premultiplied RGBA8 pixels. [coordinates]
/// is [lat, lng] x 4 in top-left, top-right, bottom-right, bottom-left order.
class AddImageSourceCommand extends SessionCommand {
  const AddImageSourceCommand(
    super.sessionId,
    this.sourceId,
    this.rgba, {
    required this.width,
    required this.height,
    required this.coordinates,
  });

  final String sourceId;
  final Uint8List rgba;
  final int width;
  final int height;
  final List<double> coordinates;
}

/// Updates the pixels and/or corner coordinates of an existing image source.
class UpdateImageSourceCommand extends SessionCommand {
  const UpdateImageSourceCommand(
    super.sessionId,
    this.sourceId, {
    this.rgba,
    this.width,
    this.height,
    this.coordinates,
  });

  final String sourceId;
  final Uint8List? rgba;
  final int? width;
  final int? height;
  final List<double>? coordinates;
}

/// Renders an offscreen still image of the session's current style and
/// camera (static-mode map over an engine-owned texture) and reports the
/// result asynchronously via [SnapshotResultEvent], correlated by
/// [requestId].
///
/// [width]/[height] are the requested logical size of the still image. When
/// null the snapshot renders at the live surface size. They are honored at
/// the session's own scale factor with the camera left unchanged, so an
/// off-aspect size reveals more of the map rather than distorting it.
class TakeSnapshotCommand extends SessionCommand {
  const TakeSnapshotCommand(
    super.sessionId,
    this.requestId, {
    this.width,
    this.height,
  });

  final int requestId;
  final int? width;
  final int? height;
}

/// Adapts every style layer whose text-field references the `name` data
/// property to prefer `name:<language>` (setMapLanguage semantics).
class SetMapLanguageCommand extends SessionCommand {
  const SetMapLanguageCommand(super.sessionId, this.language);

  final String language;
}

/// Adds (or rebinds after a style reload) the location indicator layer and
/// binds its puck images, which must already be registered via
/// [SetStyleImageCommand].
class ShowLocationIndicatorCommand extends SessionCommand {
  const ShowLocationIndicatorCommand(
    super.sessionId, {
    required this.topImage,
    this.bearingImage,
    this.shadowImage,
  });

  final String topImage;
  final String? bearingImage;
  final String? shadowImage;
}

/// Moves the location indicator (and optionally its bearing and accuracy
/// circle radius in meters).
class UpdateLocationIndicatorCommand extends SessionCommand {
  const UpdateLocationIndicatorCommand(
    super.sessionId, {
    required this.latitude,
    required this.longitude,
    this.bearing,
    this.accuracyRadius,
  });

  final double latitude;
  final double longitude;
  final double? bearing;
  final double? accuracyRadius;
}

/// Removes the location indicator layer.
class RemoveLocationIndicatorCommand extends SessionCommand {
  const RemoveLocationIndicatorCommand(super.sessionId);
}

// --- Engine-level commands (not bound to one session) --------------------------

/// Sets the custom HTTP headers applied by the Dart resource provider to
/// engine resource requests. [urlFilters] are regex patterns; when non-empty
/// a request URL must match one of them for the headers to apply. An empty
/// [headers] map clears.
class SetHttpHeadersCommand extends EngineCommand {
  const SetHttpHeadersCommand(this.headers, {this.urlFilters = const []});

  final Map<String, String> headers;
  final List<String> urlFilters;
}

/// Toggles the process-global network status of the engine.
class SetNetworkStatusCommand extends EngineCommand {
  const SetNetworkStatusCommand({required this.online});

  final bool online;
}

/// Ambient (non-offline-region) tile cache maintenance operations.
enum AmbientCacheOperationKind {
  resetDatabase,
  packDatabase,
  invalidate,
  clear,
}

/// Starts an ambient cache maintenance operation (fire-and-forget).
class RunAmbientCacheOperationCommand extends EngineCommand {
  const RunAmbientCacheOperationCommand(this.operation);

  final AmbientCacheOperationKind operation;
}

/// Caps the engine's self-driven frame loop; values <= 0 restore the default
/// pacing. Only effective in engine-isolate mode (the single-isolate engine
/// is paced by the widget's vsync ticker).
class SetMaximumFpsCommand extends EngineCommand {
  const SetMaximumFpsCommand(this.fps);

  final int fps;
}

/// Toggles per-frame render statistics collection on a session (benchmark
/// instrumentation). Enabling resets any previously collected samples.
class SetFrameStatsEnabledCommand extends SessionCommand {
  const SetFrameStatsEnabledCommand(super.sessionId, {required this.enabled});

  final bool enabled;
}

// --- Offline regions (engine-level, async via OfflineResultEvent) --------------

/// Creates a tile-pyramid offline region and replies with it.
class CreateOfflineRegionCommand extends EngineCommand {
  const CreateOfflineRegionCommand(
    this.requestId, {
    required this.styleUrl,
    required this.southwestLatitude,
    required this.southwestLongitude,
    required this.northeastLatitude,
    required this.northeastLongitude,
    required this.minZoom,
    required this.maxZoom,
    this.pixelRatio = 1,
    this.includeIdeographs = false,
    this.metadata,
  });

  final int requestId;
  final String styleUrl;
  final double southwestLatitude;
  final double southwestLongitude;
  final double northeastLatitude;
  final double northeastLongitude;
  final double minZoom;
  final double maxZoom;
  final double pixelRatio;
  final bool includeIdeographs;
  final Uint8List? metadata;
}

/// Lists the stored offline regions.
class ListOfflineRegionsCommand extends EngineCommand {
  const ListOfflineRegionsCommand(this.requestId);

  final int requestId;
}

/// Merges a side database of offline regions into the cache database.
class MergeOfflineRegionsCommand extends EngineCommand {
  const MergeOfflineRegionsCommand(this.requestId, this.path);

  final int requestId;
  final String path;
}

/// Replaces the opaque metadata bytes of one region.
class UpdateOfflineRegionMetadataCommand extends EngineCommand {
  const UpdateOfflineRegionMetadataCommand(
    this.requestId,
    this.regionId,
    this.metadata,
  );

  final int requestId;
  final int regionId;
  final Uint8List metadata;
}

/// Reads the download status of one region.
class GetOfflineRegionStatusCommand extends EngineCommand {
  const GetOfflineRegionStatusCommand(this.requestId, this.regionId);

  final int requestId;
  final int regionId;
}

/// Deletes one region.
class DeleteOfflineRegionCommand extends EngineCommand {
  const DeleteOfflineRegionCommand(this.requestId, this.regionId);

  final int requestId;
  final int regionId;
}

/// Starts/pauses a region download and toggles its progress observation
/// ([OfflineRegionProgressEvent]). Fire-and-forget.
class SetOfflineRegionDownloadStateCommand extends EngineCommand {
  const SetOfflineRegionDownloadStateCommand(
    this.regionId, {
    required this.active,
    required this.observed,
  });

  final int regionId;
  final bool active;
  final bool observed;
}

// --- Queries -----------------------------------------------------------------

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

/// Visible bounds as [swLat, swLng, neLat, neLng].
class GetVisibleRegionQuery extends SessionQuery<List<double>> {
  const GetVisibleRegionQuery(super.sessionId);
}

/// Projects a coordinate to screen space; replies [x, y].
class PixelForLatLngQuery extends SessionQuery<List<double>> {
  const PixelForLatLngQuery(super.sessionId, this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Batch projection; [latLngPairs] is [lat0, lng0, lat1, lng1, ...] and the
/// reply is [x0, y0, x1, y1, ...].
class PixelsForLatLngsQuery extends SessionQuery<Float64List> {
  const PixelsForLatLngsQuery(super.sessionId, this.latLngPairs);

  final Float64List latLngPairs;
}

/// Unprojects a screen point; replies [lat, lng].
class LatLngForPixelQuery extends SessionQuery<List<double>> {
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

/// Ordered hit-test: queries [layerIds] one by one (topmost first) at a
/// screen point and replies with `{'layerId': ..., 'feature': {...}}` for the
/// first hit, or null. Keeps feature-tap resolution to one isolate
/// round-trip even though queried features carry no layer id.
class QueryTopFeatureQuery extends SessionQuery<Map<String, dynamic>?> {
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

// --- Events (engine -> presentation) -----------------------------------------

/// Base type of everything the engine pushes to the presentation side.
sealed class EngineEvent {
  const EngineEvent(this.sessionId);

  final int sessionId;
}

/// The style finished loading.
class StyleLoadedEvent extends EngineEvent {
  const StyleLoadedEvent(super.sessionId);
}

/// A camera transition is about to start.
class CameraWillChangeEvent extends EngineEvent {
  const CameraWillChangeEvent(super.sessionId);
}

/// The camera moved this frame (already coalesced to one event per pump).
class CameraIsChangingEvent extends EngineEvent {
  const CameraIsChangingEvent(super.sessionId, this.camera);

  final CameraSnapshot camera;
}

/// The map became idle (tiles loaded, no transitions running).
class MapIdleEvent extends EngineEvent {
  const MapIdleEvent(super.sessionId, this.camera);

  final CameraSnapshot camera;
}

/// The map failed to load a resource or the style.
class MapLoadingFailedEvent extends EngineEvent {
  const MapLoadingFailedEvent(super.sessionId, this.message);

  final String message;
}

/// Work arrived for a session whose driver may be idle-parked; the
/// presentation side should resume ticking.
class RenderPendingEvent extends EngineEvent {
  const RenderPendingEvent(super.sessionId);
}

/// Reply to an offline region command, correlated by [requestId]. Offline
/// events are engine-scoped: their sessionId is 0.
class OfflineResultEvent extends EngineEvent {
  const OfflineResultEvent(
    this.requestId, {
    this.regions,
    this.status,
    this.error,
  }) : super(0);

  final int requestId;

  /// Plain region maps: {id, definition: {...}, metadata: Uint8List}.
  final List<Map<String, dynamic>>? regions;

  /// Plain status map (download counters).
  final Map<String, dynamic>? status;
  final String? error;
}

/// Download progress of an observed offline region.
class OfflineRegionProgressEvent extends EngineEvent {
  const OfflineRegionProgressEvent(this.regionId, this.status) : super(0);

  final int regionId;
  final Map<String, dynamic> status;
}

/// A resource error (or the tile-count limit) hit by an observed region.
class OfflineRegionErrorEvent extends EngineEvent {
  const OfflineRegionErrorEvent(this.regionId, this.message) : super(0);

  final int regionId;
  final String message;
}

/// Result of a [TakeSnapshotCommand]: tightly correlated by [requestId],
/// carrying premultiplied RGBA8 pixels at physical size, or an error.
class SnapshotResultEvent extends EngineEvent {
  const SnapshotResultEvent(
    super.sessionId,
    this.requestId, {
    this.rgba,
    this.width = 0,
    this.height = 0,
    this.stride = 0,
    this.error,
  });

  final int requestId;
  final Uint8List? rgba;
  final int width;
  final int height;

  /// Bytes per pixel row (may exceed width * 4).
  final int stride;
  final String? error;
}
