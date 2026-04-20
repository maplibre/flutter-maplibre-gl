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
        activePacks.removeAll()
        activeDownloaders.removeAll()

        MLNOfflineStorage.shared.resetDatabase { error in
            if let error = error {
                result(FlutterError(
                    code: "ResetDatabaseError",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }

    static func deleteRegion(result: @escaping FlutterResult, id: Int) {
        let offlineStorage = MLNOfflineStorage.shared
        guard let pacs = offlineStorage.packs else { return }
        let packToRemove = pacs.first(where: { pack -> Bool in
            let contextJsonObject = try? JSONSerialization.jsonObject(with: pack.context)
            let contextJsonDict = contextJsonObject as? [String: Any]
            if let regionId = contextJsonDict?["id"] as? Int {
                return regionId == id
            } else {
                return false
            }
        })
        if let packToRemoveUnwrapped = packToRemove {
            // deletion is only safe if the download is suspended
            packToRemoveUnwrapped.suspend()
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
        let sessionConfig = MLNNetworkConfiguration.sharedManager.sessionConfiguration ?? URLSessionConfiguration.default
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
            guard let contextJsonObject = try? JSONSerialization.jsonObject(with: pack.context),
                  let contextJsonDict = contextJsonObject as? [String: Any],
                  let regionId = contextJsonDict["id"] as? Int
            else { return false }
            return regionId == id
        }
    }
}
