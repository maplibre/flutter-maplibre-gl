/// The events of an offline region download.
///
/// A library of its own rather than part of the platform interface: one of
/// the classes is called [Error], and every library importing the platform
/// interface would otherwise see it in place of `dart:core`'s `Error`.
/// `maplibre_gl` exports it for apps.
library;

import 'package:flutter/services.dart';

abstract class DownloadRegionStatus {}

class Success extends DownloadRegionStatus {}

class InProgress extends DownloadRegionStatus {
  final double progress;
  final int completedResourceCount;
  final int requiredResourceCount;
  final int completedResourceSize;

  InProgress(
    this.progress, {
    this.completedResourceCount = 0,
    this.requiredResourceCount = 0,
    this.completedResourceSize = 0,
  });

  @override
  String toString() =>
      "Instance of 'DownloadRegionStatus.InProgress', progress = $progress, "
      "completedResources = $completedResourceCount/$requiredResourceCount, "
      "bytes = $completedResourceSize";
}

/// The end of a download that did not complete. [cause] says why, with the
/// same code on Android and iOS:
///
/// * `INVALID_REGION_DEFINITION`: MapLibre cannot create a region from the
///   definition. The download call fails with the same error.
/// * `TILE_COUNT_LIMIT_EXCEEDED`: the region needs more tiles than the limit
///   set with `setOfflineTileCountLimit`. The region is deleted.
/// * `REGION_DELETED`: `deleteOfflineRegion` deleted the region first.
/// * `REGION_REPLACED`: a download of the same area replaced the region.
/// * `DATABASE_RESET`: `resetOfflineDatabase` deleted every region.
class Error extends DownloadRegionStatus {
  /// What ended the download, with one of the codes above.
  final PlatformException cause;

  Error(this.cause);

  @override
  String toString() =>
      "Instance of 'DownloadRegionStatus.Error', cause = $cause";
}
