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
        channelHandler: OfflineChannelHandler
    ) {
        // Prepare downloader
        let downloader = OfflinePackDownloader(
            result: result,
            channelHandler: channelHandler,
            regionDefintion: definition,
            metadata: metadata
        )

        // Download region
        let id = downloader.download()
        // retain downloader by its generated id
        activeDownloaders[id] = downloader
    }

    static func mergeRegions(result: @escaping FlutterResult, path: String) {
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
                result(FlutterError(code: "mergeOfflineRegions", message: error.localizedDescription, details: nil))
                return
            }
            let importedPacks = (packs ?? []).filter {
                !preexisting.contains(packIdentityKey(for: $0))
            }
            let regionsArgs = importedPacks.compactMap(regionDictionary(for:))
            guard let regionsArgsJsonData = try? JSONSerialization.data(withJSONObject: regionsArgs),
                  let regionsArgsJsonString = String(data: regionsArgsJsonData, encoding: .utf8)
            else {
                result(FlutterError(code: "mergeOfflineRegions", message: "Failed to serialize merged regions", details: nil))
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
        // Normal path: pack was created by this Flutter plugin — context holds
        // {"id": <int>, "metadata": <dict>}.
        if let region = OfflineRegion.fromOfflinePack(pack) {
            return region.toDictionary()
        }
        // Fallback for packs with unknown/missing context (e.g. imported from an
        // external DB or from Android). Mirror Android's metadataBytesToMap: try
        // to parse the context bytes as a JSON dict, fall back to empty dict.
        // Use a deterministic ID so the same pack always receives the same ID
        // across sessions (pack.context is read-only, so we cannot persist it).
        guard let id = deterministicPackId(for: pack),
              let tileRegion = pack.region as? MLNTilePyramidOfflineRegion else { return nil }
        let metadata: [String: Any]
        if let contextObj = try? JSONSerialization.jsonObject(with: pack.context),
           let contextDict = contextObj as? [String: Any] {
            metadata = contextDict
        } else {
            metadata = [:]
        }
        let definition = OfflineRegionDefinition(
            bounds: [tileRegion.bounds.sw, tileRegion.bounds.ne].map { [$0.latitude, $0.longitude] },
            mapStyleUrl: tileRegion.styleURL,
            minZoom: tileRegion.minimumZoomLevel,
            maxZoom: tileRegion.maximumZoomLevel
        )
        return OfflineRegion(id: id, metadata: metadata, definition: definition).toDictionary()
    }

    static func regionsList(result: @escaping FlutterResult) {
        let offlineStorage = MLNOfflineStorage.shared
        guard let packs = offlineStorage.packs else {
            result("[]")
            return
        }
        let regionsArgs = packs.compactMap { pack in
            OfflineRegion.fromOfflinePack(pack)?.toDictionary()
        }
        guard let regionsArgsJsonData = try? JSONSerialization.data(withJSONObject: regionsArgs),
              let regionsArgsJsonString = String(data: regionsArgsJsonData, encoding: .utf8)
        else {
            result(FlutterError(code: "RegionListError", message: nil, details: nil))
            return
        }
        result(regionsArgsJsonString)
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
                    code: "ClearAmbientCacheError",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    static func resetOfflineDatabase(result: @escaping FlutterResult) {
        // Any tracked in-progress downloads are invalidated by the reset.
        for (_, pack) in activePacks {
            pack.suspend()
        }
        // Terminate the Dart-side subscriptions so their Futures resolve.
        for (_, downloader) in activeDownloaders {
            downloader.terminate(
                errorCode: "DatabaseReset",
                errorMessage: "Offline database was reset before the download completed"
            )
        }
        activePacks.removeAll()
        activeDownloaders.removeAll()

        MLNOfflineStorage.shared.resetDatabase { error in
            if let error = error {
                result(FlutterError(
                    code: "ResetDatabaseError",
                    message: error.localizedDescription,
                    details: nil
                ))
                return
            }
            // resetDatabase wipes the underlying SQLite DB but leaves the
            // in-memory MLNOfflineStorage.packs array populated with stale
            // pack references. Without a reload, a follow-up getListOfRegions
            // call would still report the pre-reset regions as downloaded.
            // reloadPacks is async — observe the KVO `packs` change before
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
        let offlineStorage = MLNOfflineStorage.shared
        guard let pacs = offlineStorage.packs else {
            result(FlutterError(
                code: "DeleteRegionError",
                message: "Offline packs are unavailable",
                details: nil
            ))
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
                errorCode: "RegionDeleted",
                errorMessage: "Region was deleted before the download completed"
            )
            activePacks.removeValue(forKey: id)
            OfflineManagerUtils.releaseDownloader(id: id)

            offlineStorage.removePack(packToRemoveUnwrapped) { error in
                if let error = error {
                    result(FlutterError(
                        code: "DeleteRegionError",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }
        } else {
            result(FlutterError(
                code: "DeleteRegionError",
                message: "There is no region with given id to delete",
                details: nil
            ))
        }
    }

    /// Removes downloader from cache so it's memory can be deallocated
    static func releaseDownloader(id: Int) {
        activeDownloaders.removeValue(forKey: id)
    }

    // MARK: Pause / Resume

    static func pauseRegion(result: @escaping FlutterResult, id: Int) {
        if let pack = findPack(id: id) {
            pack.suspend()
            result(nil)
        } else {
            result(FlutterError(
                code: "PauseRegionError",
                message: "There is no active region with given id to pause",
                details: nil
            ))
        }
    }

    static func resumeRegion(result: @escaping FlutterResult, id: Int) {
        if let pack = findPack(id: id) {
            pack.resume()
            result(nil)
        } else {
            result(FlutterError(
                code: "ResumeRegionError",
                message: "There is no active region with given id to resume",
                details: nil
            ))
        }
    }

    // MARK: Region Status

    static func getRegionStatus(result: @escaping FlutterResult, id: Int) {
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
                result(FlutterError(code: "GetRegionStatusError", message: "Failed to serialize status", details: nil))
                return
            }
            result(jsonString)
        } else {
            result(FlutterError(
                code: "GetRegionStatusError",
                message: "There is no region with given id",
                details: nil
            ))
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
        }
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = sessionConfig
        result(nil)
    }

    // MARK: Pack Lookup

    /// Finds a pack by region ID, checking active packs first then falling back to storage
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
