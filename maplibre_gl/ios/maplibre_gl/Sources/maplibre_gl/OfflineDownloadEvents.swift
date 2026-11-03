import Flutter
import Foundation

/// Sends the events of one offline region download to Dart, tagged with the id
/// Dart chose when it started the download. Dart drops the events of a
/// download nobody listens to.
///
/// Must be called on the main thread, like every message to Dart.
class OfflineDownloadEvents {
    private let api: MapLibreOfflineDownloadFlutterApi
    private let downloadId: Int64

    init(api: MapLibreOfflineDownloadFlutterApi, downloadId: Int64) {
        self.api = api
        self.downloadId = downloadId
    }

    func onError(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        send(PgOfflineDownloadEvent(
            status: .error,
            errorCode: errorCode,
            errorMessage: errorMessage,
            errorDetails: errorDetails
        ))
    }

    func onSuccess() {
        send(PgOfflineDownloadEvent(status: .success))
    }

    func onStart() {
        send(PgOfflineDownloadEvent(status: .start))
    }

    func onProgress(
        progress: Double,
        completedResourceCount: UInt64 = 0,
        requiredResourceCount: UInt64 = 0,
        completedResourceSize: UInt64 = 0
    ) {
        send(PgOfflineDownloadEvent(
            status: .progress,
            progress: progress,
            completedResourceCount: Int64(clamping: completedResourceCount),
            requiredResourceCount: Int64(clamping: requiredResourceCount),
            completedResourceSize: Int64(clamping: completedResourceSize)
        ))
    }

    // The reply only says whether Dart received the event; there is nothing to
    // do with it, as with the event channel this replaces.
    private func send(_ event: PgOfflineDownloadEvent) {
        api.onDownloadEvent(downloadId: downloadId, event: event) { _ in }
    }
}
