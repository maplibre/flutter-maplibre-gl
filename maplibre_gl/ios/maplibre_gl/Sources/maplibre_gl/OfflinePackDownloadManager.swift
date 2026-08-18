//
//  OfflinePackDownloadManager.swift
//  location
//
//  Created by Patryk on 03/06/2020.
//

import Flutter
import Foundation
import MapLibre

class OfflinePackDownloader {
    // MARK: Properties

    private let result: FlutterResult
    private let channelHandler: OfflineChannelHandler
    private let regionDefinition: OfflineRegionDefinition
    private let metadata: [String: Any]

    /// Currently managed pack
    private var pack: MLNOfflinePack?

    /// This variable is set to true when this downloader has finished downloading and called the result method. It is used to prevent
    /// the result method being called multiple times
    private var isCompleted = false

    // MARK: Initializers

    init(
        result: @escaping FlutterResult,
        channelHandler: OfflineChannelHandler,
        regionDefintion: OfflineRegionDefinition,
        metadata: [String: Any]
    ) {
        self.result = result
        self.channelHandler = channelHandler
        regionDefinition = regionDefintion
        self.metadata = metadata

        setupNotifications()
    }

    deinit {
        print("Removing offline pack notification observers")
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public methods

    /// Signals the awaiting Dart side that this download will not produce
    /// further events. Used when the caller invalidates the download via
    /// delete or reset before it can complete naturally.
    func terminate(errorCode: String, errorMessage: String) {
        guard !isCompleted else { return }
        isCompleted = true
        channelHandler.onError(
            errorCode: errorCode,
            errorMessage: errorMessage,
            errorDetails: nil
        )
    }

    func download() -> Int {
        let storage = MLNOfflineStorage.shared
        let tilePyramidRegion = regionDefinition.toMLNTilePyramidOfflineRegion()

        // Downloading the same area twice would otherwise create a second, duplicate
        // pack (addPack does not deduplicate). Remove any existing pack covering the
        // same region first, so a re-download replaces it rather than piling up.
        //
        // Note: existingPack reads MLNOfflineStorage.shared.packs, which may be nil
        // or stale until reloadPacks completes (e.g. right after launch). If the
        // duplicate isn't loaded yet the dedup simply no-ops and a fresh pack is
        // created, the same behavior as before this feature, never a crash.
        let duplicate = existingPack(matching: tilePyramidRegion, in: storage)

        // A replacement keeps the ID the Dart side already knows. Apps pair their own
        // data to a region ID (the offline database itself cannot carry custom
        // metadata when built by the native CLI tooling), so handing back a fresh ID
        // for the same area would silently orphan those pairings. While the Android
        // SDK generates a region ID in createOfflineRegion, the iOS SDK does not, so
        // a genuinely new region still gets one here.
        let id = duplicate.flatMap { OfflineManagerUtils.dartVisibleId(for: $0) }
            ?? UUID().hashValue
        let regionData = OfflineRegion(id: id, metadata: metadata, definition: regionDefinition)

        if let duplicate = duplicate {
            // Tear down any tracking and in-flight download tied to the old pack so
            // we don't leak state or leave a Dart subscription hanging when we
            // replace it. Its progress events go to its own channel, which is named
            // per download call, so reusing the ID does not cross the two streams.
            releaseDuplicate(duplicate)
            duplicate.suspend()
            storage.removePack(duplicate) { [weak self] error in
                if let error = error {
                    print("Failed to remove duplicate offline pack: \(error.localizedDescription)")
                }
                // Add the new pack whether or not removal succeeded, so the Dart
                // Future always resolves. Worst case a stale duplicate lingers,
                // which is better than a hung download.
                self?.addPack(tilePyramidRegion, context: regionData.prepareContext())
            }
        } else {
            addPack(tilePyramidRegion, context: regionData.prepareContext())
        }
        return id
    }

    /// Clears any tracking/in-flight download tied to a pack we're about to
    /// replace, so re-downloading an area does not orphan the previous pack's
    /// `activePacks`/`activeDownloaders` entries or leave its Dart subscription
    /// waiting forever.
    private func releaseDuplicate(_ pack: MLNOfflinePack) {
        guard let oldId = OfflineRegion.fromOfflinePack(pack)?.id else { return }
        OfflineManagerUtils.activeDownloaders[oldId]?.terminate(
            errorCode: "RegionReplaced",
            errorMessage: "Region was replaced by a new download of the same area"
        )
        OfflineManagerUtils.activePacks.removeValue(forKey: oldId)
        OfflineManagerUtils.releaseDownloader(id: oldId)
    }

    private func addPack(_ region: MLNTilePyramidOfflineRegion, context: Data) {
        MLNOfflineStorage.shared
            .addPack(for: region, withContext: context) { [weak self] pack, error in
                if let pack = pack {
                    self?.onPackCreated(pack: pack)
                } else {
                    self?.onPackCreationError(error: error)
                }
            }
    }

    /// Finds an already-stored pack covering the same tile-pyramid region
    /// (style, bounds and zoom range), if any.
    private func existingPack(
        matching region: MLNTilePyramidOfflineRegion,
        in storage: MLNOfflineStorage
    ) -> MLNOfflinePack? {
        return storage.packs?.first { pack in
            guard let existing = pack.region as? MLNTilePyramidOfflineRegion else {
                return false
            }
            // Coordinates round-trip through JSON as doubles, so compare with a
            // small tolerance rather than requiring exact equality.
            func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }
            return existing.styleURL == region.styleURL
                // A region with a different ideograph setting is not equivalent
                // (different downloaded font data), so it is not a duplicate.
                && existing.includesIdeographicGlyphs == region.includesIdeographicGlyphs
                && close(existing.minimumZoomLevel, region.minimumZoomLevel)
                && close(existing.maximumZoomLevel, region.maximumZoomLevel)
                && close(existing.bounds.sw.latitude, region.bounds.sw.latitude)
                && close(existing.bounds.sw.longitude, region.bounds.sw.longitude)
                && close(existing.bounds.ne.latitude, region.bounds.ne.latitude)
                && close(existing.bounds.ne.longitude, region.bounds.ne.longitude)
        }
    }

    // MARK: Pack management

    private func onPackCreated(pack: MLNOfflinePack) {
        if let region = OfflineRegion.fromOfflinePack(pack),
           let regionData = try? JSONSerialization.data(withJSONObject: region.toDictionary())
        {
            // Start downloading
            self.pack = pack
            // Track pack for pause/resume support
            OfflineManagerUtils.activePacks[region.id] = pack
            pack.resume()
            // Provide region with generated
            result(String(data: regionData, encoding: .utf8))
            channelHandler.onStart()
        } else {
            onPackCreationError(error: OfflinePackError.InvalidPackData)
        }
    }

    private func onPackCreationError(error: Error?) {
        // Reset downloading state
        channelHandler.onError(
            errorCode: "invalidRegionDefinition",
            errorMessage: error?.localizedDescription,
            errorDetails: nil
        )
        result(FlutterError(
            code: "invalidRegionDefinition",
            message: error?.localizedDescription,
            details: nil
        ))
    }

    // MARK: Progress obseration

    @objc private func onPackDownloadProgress(notification: NSNotification) {
        // Verify if correct pack is checked
        guard let pack = notification.object as? MLNOfflinePack,
              verifyPack(pack: pack) else { return }
        // Calculate progress of downloading
        let packProgress = pack.progress
        let downloadProgress = calculateDownloadingProgress(
            requiredResourceCount: packProgress.countOfResourcesExpected,
            completedResourceCount: packProgress.countOfResourcesCompleted
        )
        // Check if downloading is complete
        if pack.state == .complete {
            // set download state to inactive
            // This can be called multiple times but result can only be called once. We use this
            // check to ensure that
            guard !isCompleted else { return }
            isCompleted = true
            channelHandler.onSuccess()
            result(nil)
            if let region = OfflineRegion.fromOfflinePack(pack) {
                OfflineManagerUtils.activePacks.removeValue(forKey: region.id)
                OfflineManagerUtils.releaseDownloader(id: region.id)
            }
        } else {
            channelHandler.onProgress(
                progress: downloadProgress,
                completedResourceCount: packProgress.countOfResourcesCompleted,
                requiredResourceCount: packProgress.countOfResourcesExpected,
                completedResourceSize: packProgress.countOfBytesCompleted
            )
        }
    }

    @objc private func onPackDownloadError(notification: NSNotification) {
        guard let pack = notification.object as? MLNOfflinePack,
              verifyPack(pack: pack) else { return }
        let error = notification.userInfo?[MLNOfflinePackUserInfoKey.error] as? NSError
        print("Pack download error: \(String(describing: error?.localizedDescription))")
        // set download state to inactive
        isCompleted = true
        channelHandler.onError(
            errorCode: "Downloading error",
            errorMessage: error?.localizedDescription,
            errorDetails: nil
        )
        result(FlutterError(
            code: "Downloading error",
            message: error?.localizedDescription,
            details: nil
        ))
        if let region = OfflineRegion.fromOfflinePack(pack) {
            OfflineManagerUtils.activePacks.removeValue(forKey: region.id)
            OfflineManagerUtils.deleteRegion(result: result, id: region.id)
        }
    }

    @objc private func onMaximumAllowedMapboxTiles(notification: NSNotification) {
        guard let pack = notification.object as? MLNOfflinePack,
              verifyPack(pack: pack) else { return }
        let maximumCount = (notification.userInfo?[MLNOfflinePackUserInfoKey.maximumCount]
            as AnyObject).uint64Value ?? 0
        print("MapLibre tile count limit exceeded: \(maximumCount)")
        // set download state to inactive
        isCompleted = true
        channelHandler.onError(
            errorCode: "tileCountLimitExceeded",
            errorMessage: "MapLibre tile count limit exceeded: \(maximumCount)",
            errorDetails: nil
        )
        result(FlutterError(
            code: "tileCountLimitExceeded",
            message: "MapLibre tile count limit exceeded: \(maximumCount)",
            details: nil
        ))
        if let region = OfflineRegion.fromOfflinePack(pack) {
            OfflineManagerUtils.activePacks.removeValue(forKey: region.id)
            OfflineManagerUtils.deleteRegion(result: result, id: region.id)
        }
    }

    // MARK: Util methods

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPackDownloadProgress(notification:)),
            name: NSNotification.Name.MLNOfflinePackProgressChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPackDownloadError(notification:)),
            name: NSNotification.Name.MLNOfflinePackError,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onMaximumAllowedMapboxTiles(notification:)),
            name: NSNotification.Name.MLNOfflinePackMaximumMapboxTilesReached,
            object: nil
        )
    }

    /// Since NotificationCenter will send notifications about all packs downloads we need to make sure we only handle packs
    /// managed by this downloader. So this method checks if the pack we got from a notification is the same as the pack being
    /// managed by this downloader and if it is it returns true. Otherwise it returns false
    private func verifyPack(pack: MLNOfflinePack) -> Bool {
        guard let currentlyManagedPack = self.pack else {
            // No pack is being managed yet
            return false
        }
        // We can tell whether 2 packs are the same by comparing metadata we assigned earlier
        return pack.state != .invalid && pack.context == currentlyManagedPack.context
    }

    private func calculateDownloadingProgress(
        requiredResourceCount: UInt64,
        completedResourceCount: UInt64
    ) -> Double {
        return requiredResourceCount > 0
            ? 100.0 * Double(completedResourceCount) / Double(requiredResourceCount)
            : 0.0
    }
}

enum OfflinePackError: Error {
    case InvalidPackData
}
