part of '../maplibre_gl.dart';

abstract class DownloadRegionStatus {}

class Success extends DownloadRegionStatus {}

class InProgress extends DownloadRegionStatus {
  InProgress(this.progress);
  final double progress;

  @override
  String toString() =>
      "Instance of 'DownloadRegionStatus.InProgress', progress = $progress";
}

class Error extends DownloadRegionStatus {
  Error(this.cause);
  final PlatformException cause;

  @override
  String toString() =>
      "Instance of 'DownloadRegionStatus.Error', cause = $cause";
}
