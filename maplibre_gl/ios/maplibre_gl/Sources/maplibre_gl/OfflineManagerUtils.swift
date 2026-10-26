//
//  OfflineManagerUtils.swift
//  location
//
//  Created by Patryk on 02/06/2020.
//

import Flutter
import Foundation
import MapLibre

class OfflineManagerUtils {
    static var activeDownloaders: [Int: OfflinePackDownloader] = [:]
    static var activePacks: [Int: MLNOfflinePack] = [:]

    static func downloadRegion(
        definition: OfflineRegionDefinition,
        metadata: [String: Any],
        result: @escaping FlutterResult,
        registrar _: FlutterPluginRegistrar,
        channelHandler: OfflineDownloadEvents
    ) {
        // The pack context is JSON. JSONSerialization raises an NSException,
        // which Swift cannot catch, for a value that is not, such as bytes or NaN.
        guard JSONSerialization.isValidJSONObject(metadata) else {
            result(FlutterError(
                code: OfflineErrorCode.invalidArgument,
                message: "Metadata is not JSON serializable",
                details: nil
            ))
            return
        }
        let downloader = OfflinePackDownloader(
            result: result,
            channelHandler: channelHandler,
            regionDefintion: definition,
            metadata: metadata
        )

        // The duplicate check in download() reads the stored packs, so wait for
        // them: before they load it would miss an existing pack of the same area.
        whenPacksLoaded {
            downloader.download()
        }
    }

    static func mergeRegions(result: @escaping FlutterResult, path: String) {
        // The snapshot below is only meaningful once the stored packs have loaded:
        // taken earlier it is empty and every pack would be reported as imported.
        whenPacksLoaded {
            addContents(result: result, path: path)
        }
    }

    private static func addContents(result: @escaping FlutterResult, path: String) {
        let url = URL(fileURLWithPath: path)
        // addContentsOfURL's completion hands back *all known* packs, not just the
        // ones imported from `url` (see MLNOfflineStorage.h). Snapshot the packs
        // that already exist so we can return only the newly imported ones.
        //
        // We key by a content-derived identity (context bytes + geometry) rather
        // than object identity: MLNOfflineStorage may hand back fresh MLNOfflinePack
        // instances for pre-existing packs after the merge, which would make an
        // ObjectIdentifier snapshot match nothing and report every pack as imported.
        let preexisting = Set(
            (MLNOfflineStorage.shared.packs ?? []).map(packIdentityKey(for:))
        )
        MLNOfflineStorage.shared.addContents(of: url, withCompletionHandler: { _, packs, error in
            if let error = error {
                result(databaseError(error.localizedDescription))
                return
            }
            let importedPacks = (packs ?? []).filter {
                !preexisting.contains(packIdentityKey(for: $0))
            }
            let regionsArgs = importedPacks.compactMap(regionDictionary(for:))
            guard let regionsArgsJsonData = try? JSONSerialization.data(withJSONObject: regionsArgs),
                  let regionsArgsJsonString = String(data: regionsArgsJsonData, encoding: .utf8)
            else {
                result(databaseError("Failed to serialize the merged regions"))
                return
            }
            result(regionsArgsJsonString)
        })
    }

    /// A stable, content-derived identity for a pack, used to tell pre-existing
    /// packs apart from newly imported ones across an `addContents` call (which
    /// may return fresh instances). Combines the raw context bytes with the
    /// region geometry so distinct packs never collide.
    private static func packIdentityKey(for pack: MLNOfflinePack) -> String {
        let contextKey = pack.context.base64EncodedString()
        let geometryKey = deterministicPackId(for: pack).map(String.init) ?? "nil"
        return "\(contextKey)|\(geometryKey)"
    }

    /// Converts a pack into the `[id, metadata, definition]` dictionary the Dart
    /// side expects, or `nil` if the pack is not a tile-pyramid region.
    private static func regionDictionary(for pack: MLNOfflinePack) -> [String: Any]? {
        // Normal path: pack was created by this Flutter plugin, so context holds
        // {"id": <int>, "metadata": <dict>}.
        if let region = OfflineRegion.fromOfflinePack(pack) {
            return region.toDictionary()
        }
        // Fallback for packs with unknown/missing context (e.g. imported from an
        // external DB or from Android). Mirror Android's metadataBytesToMap: try
        // to parse the context bytes as a JSON dict, fall back to empty dict.
        // Use a deterministic ID so the same pack always receives the same ID
        // across sessions without writing to its context; once the app sets
        // metadata on it, updateRegionMetadata stores that ID in the context.
        guard let id = deterministicPackId(for: pack),
              let tileRegion = pack.region as? MLNTilePyramidOfflineRegion else { return nil }
        let metadata: [String: Any]
        if let contextObj = try? JSONSerialization.jsonObject(with: pack.context),
           let contextDict = contextObj as? [String: Any] {
            metadata = contextDict
        } else {
            metadata = [:]
        }
        return OfflineRegion(
            id: id,
            metadata: metadata,
            definition: regionDefinition(for: tileRegion)
        ).toDictionary()
    }

    private static func regionDefinition(
        for tileRegion: MLNTilePyramidOfflineRegion
    ) -> OfflineRegionDefinition {
        return OfflineRegionDefinition(
            bounds: [tileRegion.bounds.sw, tileRegion.bounds.ne].map { [$0.latitude, $0.longitude] },
            mapStyleUrl: tileRegion.styleURL,
            minZoom: tileRegion.minimumZoomLevel,
            maxZoom: tileRegion.maximumZoomLevel
        )
    }

    static func regionsList(result: @escaping FlutterResult) {
        // Right after launch `packs` is still nil while the store loads, and
        // answering then reported no regions at all (#381).
        whenPacksLoaded {
            let packs = MLNOfflineStorage.shared.packs ?? []
            listRegions(result: result, packs: packs)
        }
    }

    private static func listRegions(result: @escaping FlutterResult, packs: [MLNOfflinePack]) {
        let regionsArgs = packs.compactMap(regionDictionary(for:))
        guard let regionsArgsJsonData = try? JSONSerialization.data(withJSONObject: regionsArgs),
              let regionsArgsJsonString = String(data: regionsArgsJsonData, encoding: .utf8)
        else {
            result(databaseError("Failed to serialize the regions"))
            return
        }
        result(regionsArgsJsonString)
    }

    static func updateRegionMetadata(
        result: @escaping FlutterResult,
        id: Int,
        metadata: [String: Any]
    ) {
        whenPacksLoaded {
            setRegionMetadata(result: result, id: id, metadata: metadata)
        }
    }

    private static func setRegionMetadata(
        result: @escaping FlutterResult,
        id: Int,
        metadata: [String: Any]
    ) {
        // Error codes and messages mirror Android's updateRegionMetadata.
        guard let pack = findPack(id: id),
              let tileRegion = pack.region as? MLNTilePyramidOfflineRegion
        else {
            result(missingRegionError(id: id))
            return
        }
        // The pack context is JSON, so metadata that is not cannot be stored.
        guard JSONSerialization.isValidJSONObject(metadata) else {
            result(FlutterError(
                code: OfflineErrorCode.invalidArgument,
                message: "Metadata is not JSON serializable",
                details: nil
            ))
            return
        }
        // The context keeps the shape it is created with at download time, so
        // the region keeps its ID. A pack imported without a Flutter context
        // gets the ID it was already listed under written into it.
        let region = OfflineRegion(
            id: id,
            metadata: metadata,
            definition: regionDefinition(for: tileRegion)
        )
        pack.setContext(region.prepareContext()) { error in
            if let error = error {
                result(databaseError(error.localizedDescription))
                return
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: region.toDictionary()),
                  let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                result(databaseError("Failed to serialize the updated region"))
                return
            }
            result(jsonString)
        }
    }

    static func setOfflineTileCountLimit(result: @escaping FlutterResult, maximumCount: UInt64) {
        let offlineStorage = MLNOfflineStorage.shared
        offlineStorage.setMaximumAllowedMapboxTiles(maximumCount)
        result(nil)
    }

    static func clearAmbientCache(result: @escaping FlutterResult) {
        MLNOfflineStorage.shared.clearAmbientCache { error in
            if let error = error {
                result(FlutterError(
                    code: OfflineErrorCode.ambientCacheError,
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    static func setMaximumAmbientCacheSize(result: @escaping FlutterResult, bytes: UInt64) {
        MLNOfflineStorage.shared.setMaximumAmbientCacheSize(UInt(bytes)) { error in
            if let error = error {
                result(FlutterError(
                    code: OfflineErrorCode.ambientCacheError,
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    static func resetOfflineDatabase(result: @escaping FlutterResult) {
        // The reload below waits for the next KVO change of `packs`. Before the
        // stored packs have loaded, that change could be the first load rather
        // than the reload, answering Dart while the stale packs are still
        // listed. Waiting also keeps the reset behind calls queued before it.
        whenPacksLoaded {
            resetLoadedOfflineDatabase(result: result)
        }
    }

    private static func resetLoadedOfflineDatabase(result: @escaping FlutterResult) {
        // Any tracked in-progress downloads are invalidated by the reset.
        for (_, pack) in activePacks {
            pack.suspend()
        }
        // Terminate the Dart-side subscriptions so their Futures resolve.
        for (_, downloader) in activeDownloaders {
            downloader.terminate(
                errorCode: OfflineErrorCode.databaseReset,
                errorMessage: "Offline database was reset before the download completed"
            )
        }
        activePacks.removeAll()
        activeDownloaders.removeAll()

        MLNOfflineStorage.shared.resetDatabase { error in
            if let error = error {
                result(databaseError(error.localizedDescription))
                return
            }
            // resetDatabase wipes the underlying SQLite DB but leaves the
            // in-memory MLNOfflineStorage.packs array populated with stale
            // pack references. Without a reload, a follow-up getListOfRegions
            // call would still report the pre-reset regions as downloaded.
            // reloadPacks is async: observe the KVO `packs` change before
            // returning to Dart so the next getListOfRegions sees fresh state.
            let storage = MLNOfflineStorage.shared
            let observer = PacksReloadObserver {
                result(nil)
            }
            observer.target = storage
            storage.addObserver(observer, forKeyPath: "packs", options: [.new], context: nil)
            storage.reloadPacks()
        }
    }

    static func deleteRegion(result: @escaping FlutterResult, id: Int) {
        whenPacksLoaded {
            removeRegion(result: result, id: id)
        }
    }

    private static func removeRegion(result: @escaping FlutterResult, id: Int) {
        let offlineStorage = MLNOfflineStorage.shared
        guard let pacs = offlineStorage.packs else {
            result(missingRegionError(id: id))
            return
        }
        let packToRemove = pacs.first(where: { pack -> Bool in
            if let contextJsonObject = try? JSONSerialization.jsonObject(with: pack.context),
               let contextJsonDict = contextJsonObject as? [String: Any],
               let regionId = contextJsonDict["id"] as? Int {
                return regionId == id
            }
            // Fallback for external packs without a Flutter-format context.
            return deterministicPackId(for: pack) == id
        })
        if let packToRemoveUnwrapped = packToRemove {
            // deletion is only safe if the download is suspended
            packToRemoveUnwrapped.suspend()
            // Terminate the Dart-side subscription if a download is in flight.
            activeDownloaders[id]?.terminate(
                errorCode: OfflineErrorCode.regionDeleted,
                errorMessage: "Region was deleted before the download completed"
            )
            activePacks.removeValue(forKey: id)
            OfflineManagerUtils.releaseDownloader(id: id)

            offlineStorage.removePack(packToRemoveUnwrapped) { error in
                if let error = error {
                    result(databaseError(error.localizedDescription))
                } else {
                    result(nil)
                }
            }
        } else {
            result(missingRegionError(id: id))
        }
    }

    /// Removes downloader from cache so it's memory can be deallocated
    static func releaseDownloader(id: Int) {
        activeDownloaders.removeValue(forKey: id)
    }

    // MARK: Pause / Resume

    static func pauseRegion(result: @escaping FlutterResult, id: Int) {
        whenPacksLoaded { pauseLoadedRegion(result: result, id: id) }
    }

    private static func pauseLoadedRegion(result: @escaping FlutterResult, id: Int) {
        if let pack = findPack(id: id) {
            pack.suspend()
            result(nil)
        } else {
            result(missingRegionError(id: id))
        }
    }

    static func resumeRegion(result: @escaping FlutterResult, id: Int) {
        whenPacksLoaded { resumeLoadedRegion(result: result, id: id) }
    }

    private static func resumeLoadedRegion(result: @escaping FlutterResult, id: Int) {
        if let pack = findPack(id: id) {
            // Resuming a complete pack would only show it active until MapLibre
            // reports it complete again. A pack with no download of this session
            // behind it resumes without events.
            if pack.state != .complete {
                pack.resume()
            }
            result(nil)
        } else {
            result(missingRegionError(id: id))
        }
    }

    // MARK: Region Status

    static func getRegionStatus(result: @escaping FlutterResult, id: Int) {
        whenPacksLoaded { returnRegionStatus(result: result, id: id) }
    }

    private static func returnRegionStatus(result: @escaping FlutterResult, id: Int) {
        if let pack = findPack(id: id) {
            let progress = pack.progress
            let completedCount = progress.countOfResourcesCompleted
            let expectedCount = progress.countOfResourcesExpected
            let downloadProgress = expectedCount > 0
                ? 100.0 * Double(completedCount) / Double(expectedCount)
                : 0.0

            let statusDict: [String: Any] = [
                "completedResourceCount": completedCount,
                "requiredResourceCount": expectedCount,
                "completedResourceSize": progress.countOfBytesCompleted,
                "isComplete": pack.state == .complete,
                "downloadProgress": downloadProgress,
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: statusDict),
                  let jsonString = String(data: jsonData, encoding: .utf8)
            else {
                result(databaseError("Failed to serialize the status"))
                return
            }
            result(jsonString)
        } else {
            result(missingRegionError(id: id))
        }
    }

    // MARK: Concurrency Control

    static func setMaxConcurrentRequests(result: @escaping FlutterResult, maxRequestsPerHost: Int?) {
        // Read the existing config so protocolClasses (e.g. MapLibreHeadersProtocol)
        // registered at startup are preserved when we write back.
        let sessionConfig = MLNNetworkConfiguration.sharedManager.sessionConfiguration
            ?? URLSessionConfiguration.default
        if let maxPerHost = maxRequestsPerHost {
            sessionConfig.httpMaximumConnectionsPerHost = maxPerHost
            // With custom headers set, MapLibreHeadersProtocol intercepts the
            // request and opens the connection on a session of its own, so the
            // limit above does not apply to it and has to be relayed.
            MapLibreHeadersProtocol.setMaxConnectionsPerHost(maxPerHost)
        }
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig
        result(nil)
    }

    // MARK: Errors

    /// The error for a region `findPack` did not find: `REGION_NOT_FOUND`, or
    /// `OFFLINE_DATABASE_ERROR` when the stored packs never loaded.
    private static func missingRegionError(id: Int) -> FlutterError {
        if MLNOfflineStorage.shared.packs == nil {
            return databaseError("The offline regions could not be loaded")
        }
        return FlutterError(
            code: OfflineErrorCode.regionNotFound,
            message: "There is no offline region with id \(id).",
            details: nil
        )
    }

    /// A failure of the offline database, with what MapLibre reported.
    private static func databaseError(_ message: String?) -> FlutterError {
        FlutterError(code: OfflineErrorCode.offlineDatabaseError, message: message, details: nil)
    }

    // MARK: Pack Lookup

    /// How long `whenPacksLoaded` waits for the stored packs before giving up.
    private static let packsLoadTimeout: TimeInterval = 10

    /// Calls waiting in `whenPacksLoaded`, oldest first. Only touched on the
    /// main queue.
    private static var pendingUntilPacksLoaded: [() -> Void] = []

    /// The one observer waiting for the packs while calls are queued.
    private static var packsLoadedObserver: PacksLoadedObserver?

    /// Runs `completion` on the main queue once `MLNOfflineStorage.shared.packs`
    /// has loaded. The store loads its packs asynchronously, so right after
    /// launch the property is still nil and every lookup would miss. Runs at
    /// once when the packs are already there and no earlier call is waiting;
    /// otherwise queues it behind the earlier ones. A single observer waits for
    /// the KVO change and then runs the queue in the order the calls were made,
    /// like Android answers them, since separate KVO observers are not
    /// notified in a guaranteed order. After `packsLoadTimeout` the queue runs
    /// with whatever is available, so a store that never loads cannot leave a
    /// call unanswered.
    static func whenPacksLoaded(_ completion: @escaping () -> Void) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { whenPacksLoaded(completion) }
            return
        }
        let storage = MLNOfflineStorage.shared
        // Even with the packs loaded, wait behind calls that are still queued:
        // running now would answer this call before them.
        if pendingUntilPacksLoaded.isEmpty, storage.packs != nil {
            completion()
            return
        }
        pendingUntilPacksLoaded.append(completion)
        guard packsLoadedObserver == nil else { return }
        let observer = PacksLoadedObserver(storage: storage, timeout: packsLoadTimeout) {
            packsLoadedObserver = nil
            runPendingUntilPacksLoaded()
        }
        packsLoadedObserver = observer
        observer.start()
    }

    /// Runs the queued calls in FIFO order. Takes them one at a time, so a call
    /// that queues another one while it runs lands behind those still waiting.
    private static func runPendingUntilPacksLoaded() {
        while !pendingUntilPacksLoaded.isEmpty {
            let next = pendingUntilPacksLoaded.removeFirst()
            next()
        }
    }

    /// Finds a pack by region ID, checking active packs first then falling back to storage.
    /// Call it from `whenPacksLoaded`, or a stored pack can be missed right after launch.
    private static func findPack(id: Int) -> MLNOfflinePack? {
        // Check active packs first (in-progress downloads)
        if let pack = activePacks[id] {
            return pack
        }
        // Fall back to storage (completed/paused regions)
        let offlineStorage = MLNOfflineStorage.shared
        guard let packs = offlineStorage.packs else { return nil }
        return packs.first { pack in
            if let contextJsonObject = try? JSONSerialization.jsonObject(with: pack.context),
               let contextJsonDict = contextJsonObject as? [String: Any],
               let regionId = contextJsonDict["id"] as? Int {
                return regionId == id
            }
            // Fallback for external packs without a Flutter-format context.
            return deterministicPackId(for: pack) == id
        }
    }

    /// The ID the Dart side sees for `pack`: the one carried in its Flutter context
    /// when present, otherwise the geometry-derived fallback used for packs imported
    /// from an external database.
    static func dartVisibleId(for pack: MLNOfflinePack) -> Int? {
        if let region = OfflineRegion.fromOfflinePack(pack) { return region.id }
        return deterministicPackId(for: pack)
    }

    /// Returns a stable integer ID derived from a pack's geographic properties.
    /// Used for packs imported from external databases that lack a Flutter-assigned
    /// context ID. Uses djb2 so the result is deterministic across app sessions,
    /// unlike Swift's randomised `hashValue`.
    ///
    /// Coordinates are quantized to the precision the duplicate check in
    /// `OfflinePackDownloadManager` tolerates (1e-9). Without that the two would
    /// disagree on what "the same region" means: the dedup would treat two packs as
    /// one while this hash gave them different IDs. Values sitting astride a bucket
    /// boundary can still land apart, so this aligns the two rather than proving
    /// them equivalent.
    private static func deterministicPackId(for pack: MLNOfflinePack) -> Int? {
        guard let region = pack.region as? MLNTilePyramidOfflineRegion else { return nil }
        // Explicitly unlocalised: a locale that writes decimals with a comma would
        // otherwise produce a different ID for the same region.
        func quantize(_ value: Double) -> String {
            String(format: "%.9f", locale: nil, value)
        }
        let key = [
            region.styleURL.absoluteString,
            quantize(region.bounds.sw.latitude),
            quantize(region.bounds.sw.longitude),
            quantize(region.bounds.ne.latitude),
            quantize(region.bounds.ne.longitude),
            quantize(region.minimumZoomLevel),
            quantize(region.maximumZoomLevel),
        ].joined(separator: "|")
        // djb2: hash * 33 + byte, deterministic across sessions unlike hashValue.
        return key.utf8.reduce(5381) { (33 &* $0) &+ Int($1) }
    }
}

/// One-shot KVO observer that waits for `MLNOfflineStorage.packs` to become
/// non-nil, or for a timeout, whichever comes first, and then calls `onLoaded`
/// exactly once, on the main queue. `OfflineManagerUtils` keeps it alive while
/// it waits.
private final class PacksLoadedObserver: NSObject {
    private let storage: MLNOfflineStorage
    private let timeout: TimeInterval
    private let onLoaded: () -> Void
    private var finished = false

    init(storage: MLNOfflineStorage, timeout: TimeInterval, onLoaded: @escaping () -> Void) {
        self.storage = storage
        self.timeout = timeout
        self.onLoaded = onLoaded
        super.init()
    }

    func start() {
        // .initial reports the current value as soon as the observer is added,
        // so packs that load between the caller's check and this call are not
        // missed.
        storage.addObserver(self, forKeyPath: "packs", options: [.initial, .new], context: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish()
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "packs" else { return }
        // KVO can fire on any thread, and synchronously inside addObserver for
        // .initial: hop to the main queue so `finished` is only touched there
        // and the observer is never removed from within its own registration.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.storage.packs != nil else { return }
            self.finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        storage.removeObserver(self, forKeyPath: "packs")
        onLoaded()
    }
}

/// One-shot KVO observer for `MLNOfflineStorage.packs`. Retains itself until
/// the first change notification fires, then deregisters and invokes `onChange`.
private final class PacksReloadObserver: NSObject {
    private let onChange: () -> Void
    private var fired = false
    private var retainCycle: PacksReloadObserver?
    weak var target: MLNOfflineStorage?

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init()
        retainCycle = self
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of _: Any?,
        change _: [NSKeyValueChangeKey: Any]?,
        context _: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "packs", !fired else { return }
        fired = true
        target?.removeObserver(self, forKeyPath: "packs")
        target = nil
        let callback = onChange
        retainCycle = nil
        callback()
    }
}

/// The error codes of the offline calls and download events, the same as on
/// Android.
enum OfflineErrorCode {
    /// No offline region has the id the call was given.
    static let regionNotFound = "REGION_NOT_FOUND"
    /// The offline database failed an operation, with MapLibre's message.
    static let offlineDatabaseError = "OFFLINE_DATABASE_ERROR"
    /// The ambient cache failed an operation, with MapLibre's message.
    static let ambientCacheError = "AMBIENT_CACHE_ERROR"
    /// An argument the call cannot use, such as a negative limit.
    static let invalidArgument = "INVALID_ARGUMENT"
    /// A region definition MapLibre cannot download.
    static let invalidRegionDefinition = "INVALID_REGION_DEFINITION"
    /// The download needs more tiles than the offline tile count limit.
    static let tileCountLimitExceeded = "TILE_COUNT_LIMIT_EXCEEDED"
    /// The region was deleted before its download completed.
    static let regionDeleted = "REGION_DELETED"
    /// A download of the same area replaced the region before it completed.
    static let regionReplaced = "REGION_REPLACED"
    /// The offline database was reset before the download completed.
    static let databaseReset = "DATABASE_RESET"
}
