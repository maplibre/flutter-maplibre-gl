import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'offline_region_map.dart';
import '../../page.dart';
import '../../shared/shared.dart';

final LatLngBounds hawaiiBounds = LatLngBounds(
  southwest: const LatLng(17.26672, -161.14746),
  northeast: const LatLng(23.76523, -153.74267),
);

final LatLngBounds santiagoBounds = LatLngBounds(
  southwest: const LatLng(-33.65, -70.80),
  northeast: const LatLng(-33.25, -70.40),
);

final LatLngBounds aucklandBounds = LatLngBounds(
  southwest: const LatLng(-36.87838, 174.73205),
  northeast: const LatLng(-36.82838, 174.79745),
);

final List<OfflineRegionDefinition> regionDefinitions = [
  OfflineRegionDefinition(
    bounds: hawaiiBounds,
    minZoom: 3.0,
    maxZoom: 8.0,
    mapStyleUrl: MapLibreStyles.openfreemapLiberty,
  ),
  OfflineRegionDefinition(
    bounds: santiagoBounds,
    minZoom: 10.0,
    maxZoom: 16.0,
    mapStyleUrl: MapLibreStyles.openfreemapLiberty,
  ),
  OfflineRegionDefinition(
    bounds: aucklandBounds,
    minZoom: 13.0,
    maxZoom: 16.0,
    mapStyleUrl: MapLibreStyles.openfreemapLiberty,
  ),
];

final List<String> regionNames = ['Hawaii', 'Santiago', 'Auckland'];

class OfflineRegionListItem {
  OfflineRegionListItem({
    required this.offlineRegionDefinition,
    required this.downloadedId,
    required this.isDownloading,
    required this.isPaused,
    required this.name,
    required this.estimatedTiles,
    this.downloadProgress = 0.0,
  });

  final OfflineRegionDefinition offlineRegionDefinition;
  final int? downloadedId;
  final bool isDownloading;
  final bool isPaused;
  final String name;
  final int estimatedTiles;
  final double downloadProgress;

  static const _sentinel = Object();

  OfflineRegionListItem copyWith({
    Object? downloadedId = _sentinel,
    bool? isDownloading,
    bool? isPaused,
    double? downloadProgress,
  }) => OfflineRegionListItem(
    offlineRegionDefinition: offlineRegionDefinition,
    name: name,
    estimatedTiles: estimatedTiles,
    downloadedId:
        identical(downloadedId, _sentinel)
            ? this.downloadedId
            : downloadedId as int?,
    isDownloading: isDownloading ?? this.isDownloading,
    isPaused: isPaused ?? this.isPaused,
    downloadProgress: downloadProgress ?? this.downloadProgress,
  );

  bool get isDownloaded => downloadedId != null;
}

final List<OfflineRegionListItem> allRegions = [
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[0],
    downloadedId: null,
    isDownloading: false,
    isPaused: false,
    name: regionNames[0],
    estimatedTiles: 61,
  ),
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[1],
    downloadedId: null,
    isDownloading: false,
    isPaused: false,
    name: regionNames[1],
    estimatedTiles: 21000,
  ),
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[2],
    downloadedId: null,
    isDownloading: false,
    isPaused: false,
    name: regionNames[2],
    estimatedTiles: 202,
  ),
];

class OfflineRegionsPage extends ExamplePage {
  const OfflineRegionsPage({super.key})
    : super(
        const Icon(Icons.cloud_off),
        'Offline Regions',
        category: ExampleCategory.advanced,
      );

  @override
  Widget build(BuildContext context) => const _OfflineRegionBody();
}

class _OfflineRegionBody extends StatefulWidget {
  const _OfflineRegionBody();

  @override
  State<_OfflineRegionBody> createState() => _OfflineRegionsBodyState();
}

class _OfflineRegionsBodyState extends State<_OfflineRegionBody> {
  final List<OfflineRegionListItem> _items = [];

  @override
  void initState() {
    super.initState();
    unawaited(_updateListOfRegions());
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: ExampleButton(
                  label: 'Clear Ambient Cache',
                  icon: Icons.cleaning_services_outlined,
                  onPressed: _handleClearAmbientCache,
                  style: ExampleButtonStyle.outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExampleButton(
                  label: 'Reset Database',
                  icon: Icons.delete_forever_outlined,
                  onPressed: _handleResetDatabase,
                  style: ExampleButtonStyle.destructive,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _buildCard(item, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(OfflineRegionListItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    item.isDownloaded
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.isDownloaded ? Icons.cloud_done : Icons.cloud_download,
                color:
                    item.isDownloaded
                        ? Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer
                        : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              item.isDownloading
                  ? 'Progress: ${item.downloadProgress.toStringAsFixed(1)}%'
                  : 'Estimated tiles: ${item.estimatedTiles}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing:
                item.isDownloading
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            item.isPaused ? Icons.play_arrow : Icons.pause,
                          ),
                          onPressed:
                              item.downloadedId != null
                                  ? () => _togglePause(item, index)
                                  : null,
                        ),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    )
                    : null,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ExampleButton(
                    label: 'View Map',
                    icon: Icons.map_outlined,
                    onPressed: () => _goToMap(item),
                    style: ExampleButtonStyle.outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      item.isDownloaded
                          ? ExampleButton(
                            label: 'Delete',
                            icon: Icons.delete_outline,
                            onPressed:
                                item.isDownloading
                                    ? null
                                    : () => _deleteRegion(item, index),
                            style: ExampleButtonStyle.destructive,
                          )
                          : ExampleButton(
                            label: 'Download',
                            icon: Icons.download,
                            onPressed:
                                item.isDownloading
                                    ? null
                                    : () => _downloadRegion(item, index),
                            style: ExampleButtonStyle.filled,
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClearAmbientCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Clear ambient cache?'),
            content: const Text(
              'Removes every cached tile that is not pinned to an offline '
              'region, including tiles left behind by previously deleted '
              'regions. Offline regions themselves are kept.\n\n'
              'After this, re-downloading a region will fetch tiles from '
              'the network instead of reusing the local cache.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await clearAmbientCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ambient cache cleared')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clear ambient cache failed: $e')),
      );
    }
  }

  Future<void> _handleResetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reset offline database?'),
            content: const Text(
              'This will delete all offline regions and clear the ambient '
              'cache. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await resetOfflineDatabase();
      if (!mounted) return;
      await _updateListOfRegions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline database reset')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset database failed: $e')),
      );
    }
  }

  Future<void> _updateListOfRegions() async {
    final offlineRegions = await getListOfRegions();
    final regionItems = <OfflineRegionListItem>[];
    for (final item in allRegions) {
      final offlineRegion = offlineRegions.firstWhereOrNull(
        (offlineRegion) => offlineRegion.metadata['name'] == item.name,
      );
      if (offlineRegion != null) {
        regionItems.add(item.copyWith(downloadedId: offlineRegion.id));
      } else {
        regionItems.add(item);
      }
    }
    setState(() {
      _items.clear();
      _items.addAll(regionItems);
    });
  }

  Future<void> _downloadRegion(OfflineRegionListItem item, int index) async {
    setState(() {
      _items[index] = item.copyWith(isDownloading: true);
    });

    // Use a Completer to wait for the Success/Error event from the EventChannel instead.
    final completer = Completer<void>();

    try {
      final downloadingRegion = await downloadOfflineRegion(
        item.offlineRegionDefinition,
        metadata: {
          'name': regionNames[index],
        },
        onEvent: (status) {
          if (!mounted) return;
          if (status is InProgress) {
            setState(() {
              _items[index] = _items[index].copyWith(
                downloadProgress: status.progress,
              );
            });
          } else if (status is Success && !completer.isCompleted) {
            completer.complete();
          } else if (status is Error && !completer.isCompleted) {
            completer.completeError(status.cause);
          }
        },
      );

      // Region created — set the downloadedId so pause/resume can use it,
      // but keep isDownloading: true until the Success event arrives.
      if (mounted) {
        setState(() {
          _items[index] = _items[index].copyWith(
            downloadedId: downloadingRegion.id,
          );
        });
      }

      // Wait for the actual download to complete via EventChannel.
      await completer.future;

      if (!mounted) return;
      setState(() {
        _items[index] = _items[index].copyWith(
          isDownloading: false,
          downloadedId: downloadingRegion.id,
          isPaused: false,
        );
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        _items[index] = _items[index].copyWith(
          isDownloading: false,
          downloadedId: null,
          isPaused: false,
        );
      });
    }
  }

  Future<void> _togglePause(OfflineRegionListItem item, int index) async {
    final id = item.downloadedId;
    if (id == null) return;
    final shouldResume = item.isPaused;

    try {
      if (shouldResume) {
        await resumeOfflineRegionDownload(id);
      } else {
        await pauseOfflineRegionDownload(id);
      }
      if (!mounted) return;
      setState(() {
        _items[index] = _items[index].copyWith(isPaused: !shouldResume);
      });
    } on Exception catch (_) {
      // Download may have completed between UI update and button press
    }
  }

  Future<void> _deleteRegion(OfflineRegionListItem item, int index) async {
    await deleteOfflineRegion(item.downloadedId!);
    if (!mounted) return;
    setState(() {
      _items[index] = _items[index].copyWith(
        downloadedId: null,
        isPaused: false,
      );
    });
  }

  Future<void> _goToMap(OfflineRegionListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfflineRegionMap(item),
      ),
    );
  }
}
