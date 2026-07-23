import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import 'engine_core.dart';
import 'engine_protocol.dart';
import 'texture_bridge.dart';

/// Root-isolate configuration shared by the engine hosts: applied when a
/// host boots and kept in sync afterwards.
class FfiEngineConfig {
  FfiEngineConfig._();

  /// The live engine host, if one has been bootstrapped.
  static EngineHost? activeHost;

  /// Process-global HTTP headers for engine resource requests
  /// (MapLibreGlNative.setGlobalHttpHeaders).
  static Map<String, String> globalHttpHeaders = const {};

  /// Resolves the platform cache directory once (persistent tile cache).
  static Future<String?> resolveCacheDir() async {
    try {
      return await MapLibreGlNativeBridge.getCacheDir();
    } catch (error) {
      debugPrint(
        '[maplibre_gl_native] no platform cache directory, '
        'using an in-memory tile cache: $error',
      );
      return null;
    }
  }

  /// Pushes the pending global configuration to a freshly booted host.
  static void applyTo(EngineHost host) {
    activeHost = host;
    if (globalHttpHeaders.isNotEmpty) {
      host.send(SetHttpHeadersCommand(globalHttpHeaders));
    }
  }
}

/// Transport-agnostic handle to the engine core used by the presentation
/// side (widget, gestures, `MapLibrePlatform` adapter).
///
/// Phase 2 of the render-isolate plan ships [LocalEngineHost] (direct calls
/// on the root isolate). Phase 3 adds an isolate-backed implementation over
/// SendPorts behind this same interface.
abstract class EngineHost {
  /// Whether the engine drives its own frame loop. When true the widget must
  /// not tick; when false the widget's ticker calls [tick] every frame.
  bool get drivesFrames;

  /// Registers a listener for events pushed by the engine.
  void addEventListener(void Function(EngineEvent event) listener);

  /// Removes a previously registered event listener.
  void removeEventListener(void Function(EngineEvent event) listener);

  /// Sends a fire-and-forget mutation.
  void send(EngineCommand command);

  /// Executes a read and completes with its reply.
  Future<R> query<R>(EngineQuery<R> query);

  /// Pumps the runtime and renders the session if dirty; returns whether a
  /// frame was rendered. Frame driving is presentation-owned in phase 2
  /// (widget ticker); an isolate-backed host drives frames internally and
  /// these two methods become cheap no-op signals.
  bool tick(int sessionId);

  /// Pumps the runtime without rendering; returns whether the session has a
  /// frame pending (low-frequency idle pump).
  bool pumpAndCheckRenderPending(int sessionId);
}

/// Phase-2 host: the engine core lives on the root isolate and every call is
/// a direct synchronous invocation.
class LocalEngineHost implements EngineHost {
  LocalEngineHost._(this._core) {
    _core.onEvent = _dispatchEvent;
  }

  static LocalEngineHost? _instance;

  final FfiEngineCore _core;
  final List<void Function(EngineEvent)> _listeners =
      <void Function(EngineEvent)>[];

  /// Initializes the Android services and the shared engine core.
  static Future<LocalEngineHost> ensure() async {
    final existing = _instance;
    if (existing != null) return existing;
    // mln_android_init must run before the first runtime is created.
    await MapLibreGlNativeBridge.init();
    final cacheDir = await FfiEngineConfig.resolveCacheDir();
    final host = LocalEngineHost._(FfiEngineCore.ensure(cachePath: cacheDir));
    _instance = host;
    FfiEngineConfig.applyTo(host);
    return host;
  }

  @override
  bool get drivesFrames => false;

  void _dispatchEvent(EngineEvent event) {
    for (final listener in List.of(_listeners)) {
      listener(event);
    }
  }

  @override
  void addEventListener(void Function(EngineEvent event) listener) {
    _listeners.add(listener);
  }

  @override
  void removeEventListener(void Function(EngineEvent event) listener) {
    _listeners.remove(listener);
  }

  @override
  void send(EngineCommand command) => _core.handleCommand(command);

  @override
  Future<R> query<R>(EngineQuery<R> query) =>
      Future<R>.value(_core.handleQuery(query));

  @override
  bool tick(int sessionId) => _core.tick(sessionId);

  @override
  bool pumpAndCheckRenderPending(int sessionId) =>
      _core.pumpAndCheckRenderPending(sessionId);
}
