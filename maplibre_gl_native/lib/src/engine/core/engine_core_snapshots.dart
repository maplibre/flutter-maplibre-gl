// Offscreen snapshot jobs of the engine core.
//
// A `part` of engine_core.dart: same library, so these members keep access
// to the core's private state. Split for readability only; execution
// semantics are identical.

part of 'engine_core.dart';

extension EngineSnapshots on FfiEngineCore {
  /// Renders pending offscreen snapshot jobs; returns whether any rendered.
  bool _renderSnapshots() {
    var rendered = false;
    for (final job in List.of(_snapshots)) {
      if (job.done || !job.renderPending) continue;
      job.renderPending = false;
      try {
        job.session.renderUpdate();
        rendered = true;
      } on mln.MaplibreException catch (error) {
        _finishSnapshot(job, error: '$error');
      }
    }
    return rendered;
  }

  void _handleSnapshotEvent(_SnapshotJob job, mln.RuntimeEvent event) {
    switch (event.eventType) {
      case mln.RuntimeEventType.mapRenderUpdateAvailable:
        job.renderPending = true;
        // Wake an idle-parked driver so the offscreen render progresses.
        _emit(RenderPendingEvent(job.sourceSessionId));
      case mln.RuntimeEventType.mapRenderFrameFinished:
        final payload = event.payload;
        if (payload is mln.RuntimeEventRenderFrame && payload.needsRepaint) {
          job.renderPending = true;
        }
      case mln.RuntimeEventType.mapStillImageFinished:
        _finishSnapshot(job, error: null);
      case mln.RuntimeEventType.mapStillImageFailed:
      case mln.RuntimeEventType.mapLoadingFailed:
        _finishSnapshot(job, error: event.message ?? 'snapshot render failed');
      default:
        break;
    }
  }

  void _finishSnapshot(_SnapshotJob job, {required String? error}) {
    if (job.done) return;
    job.done = true;
    _snapshots.remove(job);
    try {
      if (error == null) {
        final image = job.session.readPremultipliedRgba8();
        _emit(
          SnapshotResultEvent(
            job.sourceSessionId,
            job.requestId,
            rgba: image.bytes,
            width: image.info.width,
            height: image.info.height,
            stride: image.info.stride,
          ),
        );
      } else {
        _emit(
          SnapshotResultEvent(job.sourceSessionId, job.requestId, error: error),
        );
      }
    } on mln.MaplibreException catch (readError) {
      _emit(
        SnapshotResultEvent(
          job.sourceSessionId,
          job.requestId,
          error: '$readError',
        ),
      );
    } finally {
      job.session.close();
      job.map.close();
    }
  }
}
