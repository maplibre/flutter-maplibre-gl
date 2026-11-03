package org.maplibre.maplibregl

/**
 * Sends the events of one offline region download to Dart, tagged with the
 * id Dart chose when it started the download. Dart drops the events of a
 * download nobody listens to.
 *
 * Must be called on the main thread, like every message to Dart.
 */
class OfflineDownloadEvents(
    private val api: MapLibreOfflineDownloadFlutterApi,
    private val downloadId: Long,
    /** False once the engine of [api] is detached: the events are then dropped. */
    private val isAttached: () -> Boolean,
) {
    fun onStart() = send(PgOfflineDownloadEvent(status = PgOfflineDownloadStatus.START))

    fun onProgress(
        progress: Double,
        completedResourceCount: Long,
        requiredResourceCount: Long,
        completedResourceSize: Long,
    ) = send(
        PgOfflineDownloadEvent(
            status = PgOfflineDownloadStatus.PROGRESS,
            progress = progress,
            completedResourceCount = completedResourceCount,
            requiredResourceCount = requiredResourceCount,
            completedResourceSize = completedResourceSize,
        )
    )

    fun onSuccess() = send(PgOfflineDownloadEvent(status = PgOfflineDownloadStatus.SUCCESS))

    fun onError(errorCode: String, errorMessage: String?, errorDetails: Any?) = send(
        PgOfflineDownloadEvent(
            status = PgOfflineDownloadStatus.ERROR,
            errorCode = errorCode,
            errorMessage = errorMessage,
            errorDetails = errorDetails,
        )
    )

    // The reply only says whether Dart received the event; there is nothing to
    // do with it, as with the event channel this replaces.
    private fun send(event: PgOfflineDownloadEvent) {
        if (isAttached()) {
            api.onDownloadEvent(downloadId, event) { }
        }
    }
}
