import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../engine/map_session.dart';
import '../../protocol/protocol.dart';

/// Offscreen snapshots: correlates each request with the engine's reply and
/// turns the raw pixels it sends back into a PNG.
///
/// The engine answers with an event rather than a query reply, because a
/// snapshot needs a render pass to complete, so the pending requests are
/// tracked here by id.
class SnapshotService {
  SnapshotService(this._session);

  /// A snapshot needs at least one render pass, and a cold style needs its
  /// tiles first; beyond this the request is considered lost.
  static const _timeout = Duration(seconds: 30);

  final MapSession Function() _session;

  int _nextRequestId = 1;
  final Map<int, Completer<Uint8List>> _pending = <int, Completer<Uint8List>>{};

  /// Renders a still image of the map, as PNG bytes.
  ///
  /// A null [width]/[height] renders at the live surface size; an explicit
  /// size is honored at the session scale factor with the camera unchanged.
  Future<Uint8List> take({int? width, int? height}) {
    final session = _session();
    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List>();
    _pending[requestId] = completer;
    session.send(
      TakeSnapshotCommand(session.id, requestId, width: width, height: height),
    );
    return completer.future.timeout(
      _timeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw TimeoutException('takeSnapshot timed out');
      },
    );
  }

  /// Fails every request still waiting; called from the platform adapter's
  /// dispose. The engine reply can no longer arrive once the adapter stops
  /// listening, so without this each caller would sit out the full timeout.
  void dispose() {
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final completer in pending) {
      completer.completeError(
        StateError('the map was disposed before the snapshot completed'),
      );
    }
  }

  /// Completes the request [event] answers.
  void resolve(SnapshotResultEvent event) {
    final completer = _pending.remove(event.requestId);
    if (completer == null) return;
    final rgba = event.rgba;
    if (event.error != null || rgba == null) {
      completer.completeError(
        StateError(event.error ?? 'snapshot render produced no image'),
      );
      return;
    }
    unawaited(
      _encodePng(
        event,
      ).then(completer.complete, onError: completer.completeError),
    );
  }

  static Future<Uint8List> _encodePng(SnapshotResultEvent snapshot) async {
    var pixels = snapshot.rgba!;
    final rowBytes = snapshot.width * 4;
    if (snapshot.stride != rowBytes) {
      // The engine renders into a padded buffer; pack the rows before decoding.
      final packed = Uint8List(rowBytes * snapshot.height);
      for (var y = 0; y < snapshot.height; y++) {
        packed.setRange(
          y * rowBytes,
          (y + 1) * rowBytes,
          pixels,
          y * snapshot.stride,
        );
      }
      pixels = packed;
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      snapshot.width,
      snapshot.height,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    final image = await decoded.future;
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('could not encode the snapshot as PNG');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }
}
