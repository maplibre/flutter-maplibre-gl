/// Engine-scoped messages: HTTP, network status, the ambient cache, frame
/// pacing, and the offline region database. None of them target a session.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

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

// Offline regions (engine-level, async via OfflineResultEvent).

/// Creates a tile-pyramid offline region and replies with it.
class CreateOfflineRegionCommand extends EngineCommand {
  const CreateOfflineRegionCommand(
    this.requestId, {
    required this.styleUrl,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    this.pixelRatio = 1,
    this.includeIdeographs = false,
    this.metadata,
  });

  final int requestId;
  final String styleUrl;
  final BoundsSpec bounds;
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
