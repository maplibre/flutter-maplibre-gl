part of '../maplibre_gl.dart';

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

class Error extends DownloadRegionStatus {
  final PlatformException cause;

  Error(this.cause);

  @override
  String toString() =>
      "Instance of 'DownloadRegionStatus.Error', cause = $cause";
}
