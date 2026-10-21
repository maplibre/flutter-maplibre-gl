import Flutter
import Foundation
import MapLibre

/// The plugin-wide operations: offline regions, the offline database, the
/// ambient cache and HTTP settings. They do not need a map, so they can run
/// before the first one is created.
class GlobalHostApi: MapLibreGlobalHostApi {
    private let registrar: FlutterPluginRegistrar
    private let downloadEvents: MapLibreOfflineDownloadFlutterApi

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        downloadEvents = MapLibreOfflineDownloadFlutterApi(binaryMessenger: registrar.messenger())
    }

    func preWarm() throws {
        _ = MLNOfflineStorage.shared
    }

    func installOfflineMapTiles(tilesDb: String) throws {
        let tilesUrl = GlobalHostApi.getTilesUrl()
        let bundlePath = getTilesDbPath(tilesDb: tilesDb)
        NSLog(
            "Cached tiles not found, copying from bundle... \(String(describing: bundlePath)) ==> \(tilesUrl)"
        )
        do {
            let parentDir = tilesUrl.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: parentDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            if FileManager.default.fileExists(atPath: tilesUrl.path) {
                try FileManager.default.removeItem(atPath: tilesUrl.path)
            }
            try FileManager.default.copyItem(atPath: bundlePath!, toPath: tilesUrl.path)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var url = tilesUrl
            try url.setResourceValues(resourceValues)
        } catch {
            NSLog("Error copying bundled tiles: \(error)")
        }
    }

    func setOffline(offline _: Bool) throws {
        // Dart rejects the call before it gets here: the MapLibre iOS SDK has
        // no switch to force the map offline.
        throw PigeonError(
            code: "UNSUPPORTED",
            message: "setOffline is not available on iOS.",
            details: nil
        )
    }

    func setHttpHeaders(
        headers: [String: String],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        MapLibreCustomHeaders.setHeaders(headers)
        completion(.success(()))
    }

    func mergeOfflineRegions(path: String, completion: @escaping (Result<String, Error>) -> Void) {
        OfflineManagerUtils.mergeRegions(result: stringResult(completion), path: path)
    }

    func getOfflineDatabasePath() throws -> String? {
        // The shared store backing offline packs and the ambient cache. This
        // is the same file mergeOfflineRegions imports from.
        MLNOfflineStorage.shared.databaseURL.path
    }

    func getListOfRegions(completion: @escaping (Result<String, Error>) -> Void) {
        // Reads the database only; nothing is downloaded.
        OfflineManagerUtils.regionsList(result: stringResult(completion))
    }

    func updateOfflineRegionMetadata(
        id: Int64,
        metadata: [String: Any?],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        OfflineManagerUtils.updateRegionMetadata(
            result: stringResult(completion),
            id: Int(id),
            metadata: nonOptionalValues(metadata)
        )
    }

    func setOfflineTileCountLimit(
        limit: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard limit >= 0 else {
            completion(.failure(PigeonError(
                code: "SetOfflineTileCountLimitError",
                message: "The tile count limit cannot be negative.",
                details: nil
            )))
            return
        }
        OfflineManagerUtils.setOfflineTileCountLimit(
            result: voidResult(completion),
            maximumCount: UInt64(limit)
        )
    }

    func setOfflineMaxConcurrentRequests(
        maxRequests _: Int64?,
        maxRequestsPerHost: Int64?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // iOS has a per-host limit only; maxRequests is Android only.
        OfflineManagerUtils.setMaxConcurrentRequests(
            result: voidResult(completion),
            maxRequestsPerHost: maxRequestsPerHost.map { Int($0) }
        )
    }

    func pauseOfflineRegionDownload(
        id: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        OfflineManagerUtils.pauseRegion(result: voidResult(completion), id: Int(id))
    }

    func resumeOfflineRegionDownload(
        id: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        OfflineManagerUtils.resumeRegion(result: voidResult(completion), id: Int(id))
    }

    func getOfflineRegionStatus(id: Int64, completion: @escaping (Result<String, Error>) -> Void) {
        OfflineManagerUtils.getRegionStatus(result: stringResult(completion), id: Int(id))
    }

    func deleteOfflineRegion(id: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        OfflineManagerUtils.deleteRegion(result: voidResult(completion), id: Int(id))
    }

    func clearAmbientCache(completion: @escaping (Result<Void, Error>) -> Void) {
        OfflineManagerUtils.clearAmbientCache(result: voidResult(completion))
    }

    func setMaximumAmbientCacheSize(
        bytes: Int64,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard bytes >= 0 else {
            completion(.failure(PigeonError(
                code: "SetMaximumAmbientCacheSizeError",
                message: "The ambient cache size cannot be negative.",
                details: nil
            )))
            return
        }
        OfflineManagerUtils.setMaximumAmbientCacheSize(
            result: voidResult(completion),
            bytes: UInt64(bytes)
        )
    }

    func resetOfflineDatabase(completion: @escaping (Result<Void, Error>) -> Void) {
        OfflineManagerUtils.resetOfflineDatabase(result: voidResult(completion))
    }

    func downloadOfflineRegion(
        downloadId: Int64,
        definition: [String: Any?],
        metadata: [String: Any?],
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let regionDefinition = OfflineRegionDefinition
            .fromDictionary(nonOptionalValues(definition))
        else {
            completion(.failure(PigeonError(
                code: "invalidRegionDefinition",
                message: "The region definition needs bounds, mapStyleUrl, minZoom and maxZoom.",
                details: nil
            )))
            return
        }
        OfflineManagerUtils.downloadRegion(
            definition: regionDefinition,
            metadata: nonOptionalValues(metadata),
            result: stringResult(completion),
            registrar: registrar,
            channelHandler: OfflineDownloadEvents(api: downloadEvents, downloadId: downloadId)
        )
    }

    // MARK: Helpers

    private static func getTilesUrl() -> URL {
        guard var cachesUrl = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
            let bundleId = Bundle.main
            .object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String
        else {
            fatalError("Could not get map tiles directory")
        }
        cachesUrl.appendPathComponent(bundleId)
        cachesUrl.appendPathComponent(".mapbox")
        cachesUrl.appendPathComponent("cache.db")
        return cachesUrl
    }

    private func getTilesDbPath(tilesDb: String) -> String? {
        if tilesDb.starts(with: "/") {
            return tilesDb
        }
        let key = registrar.lookupKey(forAsset: tilesDb)
        return Bundle.main.path(forResource: key, ofType: nil)
    }

    /// The offline helpers read these maps the way the method channel handed
    /// them over, where a null value was an NSNull.
    private func nonOptionalValues(_ map: [String: Any?]) -> [String: Any] {
        map.mapValues { $0 ?? NSNull() }
    }
}

/// Answers a Pigeon completion from code written against `FlutterResult`, so
/// the offline helpers keep their signatures. Only the first answer is
/// delivered: a second one would be a second reply to the same message.
private func voidResult(_ completion: @escaping (Result<Void, Error>) -> Void) -> FlutterResult {
    pigeonResult(completion) { _ in () }
}

/// Like `voidResult`, for the helpers that answer with a JSON string.
private func stringResult(_ completion: @escaping (Result<String, Error>) -> Void) -> FlutterResult {
    pigeonResult(completion) { $0 as? String ?? "" }
}

private func pigeonResult<T>(
    _ completion: @escaping (Result<T, Error>) -> Void,
    convert: @escaping (Any?) -> T
) -> FlutterResult {
    var answered = false
    return { value in
        guard !answered else { return }
        answered = true
        if let error = value as? FlutterError {
            completion(.failure(PigeonError(
                code: error.code,
                message: error.message,
                details: error.details as? String
            )))
        } else if let object = value as? NSObject, object === FlutterMethodNotImplemented {
            completion(.failure(PigeonError(
                code: "notImplemented",
                message: "Not implemented on iOS.",
                details: nil
            )))
        } else {
            completion(.success(convert(value)))
        }
    }
}
