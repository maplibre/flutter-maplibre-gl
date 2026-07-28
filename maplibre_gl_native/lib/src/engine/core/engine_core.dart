import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

import '../../protocol/protocol.dart';
import 'frame_stats.dart';
import 'geojson_convert.dart';
import 'http_resource_provider.dart';
import 'json_convert.dart';

part 'engine_core_commands.dart';
part 'engine_core_offline.dart';
part 'engine_core_queries.dart';
part 'engine_core_session.dart';
part 'engine_core_snapshots.dart';

/// Style layer id of the location indicator (puck) managed by the engine.
const String _locationIndicatorLayerId = 'maplibre-gl-native-location';

/// Owns every MapLibre Native handle (runtime, maps, render sessions) and is
/// the only file allowed to touch `mln.*` types.
///
/// The presentation side talks to it exclusively through the sendable
/// [EngineMessage]/[EngineEvent] protocol, which is what allows this whole
/// class to live on a dedicated engine isolate with only the transport in
/// between. Runtime, maps, and sessions are OS-thread affine: everything
/// in this file must run on the thread that called [ensure].
class EngineCore {
  EngineCore._(this._runtime);

  static EngineCore? _instance;

  final mln.RuntimeHandle _runtime;
  final Map<int, _EngineSession> _sessions = <int, _EngineSession>{};
  final List<_SnapshotJob> _snapshots = <_SnapshotJob>[];
  final Map<mln.OfflineOperationHandle, _PendingOfflineOp> _offlineOps =
      <mln.OfflineOperationHandle, _PendingOfflineOp>{};
  int _nextSessionId = 1;

  /// Sink for events pushed to the presentation side.
  void Function(EngineEvent event)? onEvent;

  /// Frame cap requested via [SetMaximumFpsCommand]; null means the default
  /// pacing. Read by the engine-isolate frame driver.
  int? maxFps;

  /// Lazily creates the shared runtime. The Android services
  /// (`mln_android_init` via the texture bridge) must be initialized by the
  /// caller BEFORE the first call.
  ///
  /// [cachePath] is the platform cache directory backing the persistent tile
  /// cache database (ambient cache, offline regions); without it the runtime
  /// falls back to an in-memory cache.
  factory EngineCore.ensure({String? cachePath}) {
    final existing = _instance;
    if (existing != null) return existing;
    mln.Maplibre.setLogCallback((record) {
      debugPrint(
        '[MapLibreNative] ${record.severity} ${record.event}: '
        '${record.message}',
      );
    });
    final runtime = mln.RuntimeHandle.create(
      options: mln.RuntimeOptions(
        cachePath: cachePath == null
            ? ':memory:'
            : '$cachePath/maplibre_ffi_cache.db',
      ),
    );
    // Fetch styles/tiles/glyphs/sprites through Dart instead of the built-in
    // Rust HTTP client (whose TLS verification failed on some devices).
    HttpResourceProvider.install(runtime);
    final core = EngineCore._(runtime);
    _instance = core;
    return core;
  }

  void _emit(EngineEvent event) => onEvent?.call(event);

  /// Rebinds the runtime and every handle it owns to the calling OS thread
  /// (local upstream patch; see upstream_patches/0002). Called by the isolate
  /// driver when the VM resumed the engine isolate on a different thread.
  void rebindThread() => _runtime.rebindThread();

  _EngineSession _session(int sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Unknown or disposed engine session $sessionId');
    }
    return session;
  }

  // Frame driving.

  /// Pumps the runtime and renders every dirty session. Returns whether any
  /// frame was actually rendered. Used by the self-driving isolate loop.
  bool frame() {
    pump();
    return renderPending();
  }

  /// Renders every session with a frame pending, plus any queued snapshot, and
  /// reports whether anything was drawn.
  ///
  /// The second half of [frame], separate so the frame driver can time the
  /// drain and the draw as the distinct costs they are (see `FramePathProbe`).
  bool renderPending() {
    var rendered = false;
    for (final session in _sessions.values) {
      rendered = session.renderIfNeeded() || rendered;
    }
    return _renderSnapshots() || rendered;
  }

  /// Pumps the runtime and reports whether any session has a frame pending.
  bool pumpAndCheckAnyRenderPending() {
    pump();
    return _sessions.values.any((session) => session.renderPending);
  }

  /// Drains the runtime's owner-thread work and dispatches queued runtime
  /// events to the sessions they belong to.
  ///
  /// The zero timeout returns as soon as the drain is done instead of parking:
  /// this isolate takes its cadence from the display pulse, and it has to stay
  /// free to service its own port. See [FrameDriver].
  void pump() {
    _runtime.pump();
    while (true) {
      final event = _runtime.pollEvent();
      if (event == null) break;
      if (_handleOfflineEvent(event)) continue;
      final source = event.source;
      if (source is! mln.MapRuntimeEventSource) continue;
      var handled = false;
      for (final session in _sessions.values) {
        if (identical(session.map, source.map)) {
          session.handleEvent(event);
          handled = true;
          break;
        }
      }
      if (!handled) {
        for (final job in List.of(_snapshots)) {
          if (identical(job.map, source.map)) {
            _handleSnapshotEvent(job, event);
            break;
          }
        }
      }
    }
    // A continuous pan/zoom emits a burst of mapCameraIsChanging events per
    // frame; the listener re-reads the current camera each time, so only the
    // last one matters. Coalescing them to a single dispatch here removes the
    // per-event allocation + callback churn that would otherwise dominate the
    // UI thread.
    for (final session in _sessions.values) {
      session.flushCameraChanging();
    }
  }

  // Command dispatch, query handlers, offline regions, offscreen snapshots
  // and their helpers live in the part files listed at the top of this
  // library, one file per concern.
}
