import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _buildIntroBanner(context),
        const SizedBox(height: 12),
        ControlGroup(
          title: 'Regions',
          vertical: true,
          children: [
            for (var index = 0; index < _items.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              _buildCard(_items[index], index),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ControlGroup(
          title: 'Transfer between databases',
          children: [
            ExampleButton(
              label: 'Merge regions from file',
              icon: Icons.merge_outlined,
              onPressed: _handleMergeRegions,
              style: ExampleButtonStyle.tonal,
            ),
            ExampleButton(
              label: 'Export database',
              icon: Icons.ios_share_outlined,
              onPressed: _handleExportDatabase,
              style: ExampleButtonStyle.outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ControlGroup(
          title: 'Maintenance',
          children: [
            ExampleButton(
              label: 'Clear ambient cache',
              icon: Icons.cleaning_services_outlined,
              onPressed: _handleClearAmbientCache,
              style: ExampleButtonStyle.outlined,
            ),
            ExampleButton(
              label: 'Reset database',
              icon: Icons.delete_forever_outlined,
              onPressed: _handleResetDatabase,
              style: ExampleButtonStyle.destructive,
            ),
          ],
        ),
      ],
    );
  }

  /// Header that summarises the screen and opens the step-by-step guide.
  Widget _buildIntroBanner(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: InkWell(
        onTap: _showGuide,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Download areas for offline use',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    Text(
                      'Tap for a step-by-step guide.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Explains the full offline workflow, including the export/merge round-trip
  /// that lets a database be moved between devices.
  Future<void> _showGuide() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget step(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline regions guide',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Android and iOS only — the web has no offline API.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                step(
                  Icons.download,
                  '1. Download a region',
                  'Pick one of the sample areas below and tap Download. '
                      'Tiles are fetched in the background; the card shows '
                      'live progress and lets you pause or resume.',
                ),
                step(
                  Icons.map_outlined,
                  '2. View it offline',
                  'Tap View Map to open the downloaded area. Once cached, the '
                      'map keeps working without a network connection.',
                ),
                step(
                  Icons.ios_share_outlined,
                  '3. Export the database',
                  'Export database copies the whole offline store to a file '
                      'and opens the share sheet. This exports every region '
                      'plus the ambient cache, not a single region.',
                ),
                step(
                  Icons.merge_outlined,
                  '4. Merge on another device',
                  'On a second device, tap Merge regions from file and pick '
                      'the exported .db. Its regions are imported into the '
                      'local store and appear in the list.',
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(OfflineRegionListItem item, int index) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
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
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.isDownloaded ? Icons.cloud_done : Icons.cloud_download,
                color:
                    item.isDownloaded
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              item.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              item.isDownloading
                  ? 'Downloading… ${item.downloadProgress.toStringAsFixed(1)}%'
                  : item.isDownloaded
                  ? 'Downloaded · ~${item.estimatedTiles} tiles'
                  : '~${item.estimatedTiles} tiles',
              style: theme.textTheme.bodyMedium,
            ),
            trailing:
                item.isDownloading
                    ? IconButton(
                      tooltip: item.isPaused ? 'Resume' : 'Pause',
                      icon: Icon(
                        item.isPaused ? Icons.play_arrow : Icons.pause,
                      ),
                      onPressed:
                          item.downloadedId != null
                              ? () => _togglePause(item, index)
                              : null,
                    )
                    : null,
          ),
          if (item.isDownloading)
            LinearProgressIndicator(
              value:
                  item.downloadProgress > 0
                      ? item.downloadProgress / 100.0
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

  // Exports a copy of the offline database so it can be shared off-device and
  // fed back into "Merge regions from file". exportOfflineDatabase copies the
  // whole store (all regions plus the ambient cache, including SQLite sidecars)
  // — the native SDKs expose no per-region export. Android/iOS only; this page
  // is gated behind !kIsWeb.
  Future<void> _handleExportDatabase() async {
    try {
      // Export into the temp dir under a friendly name; the returned path is
      // null when nothing has been downloaded yet.
      final tmpDir = await getTemporaryDirectory();
      final exportPath = '${tmpDir.path}/offline_regions_export.db';
      final exported = await exportOfflineDatabase(exportPath);
      if (exported == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No offline database to export')),
        );
        return;
      }

      if (!mounted) return;
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(exported)],
            subject: 'Offline regions database',
          ),
        );
      } finally {
        // The DB copy is tens of MB; delete it and its sidecars once the share
        // sheet is done so they don't accumulate in temporary storage.
        for (final path in [exported, '$exported-wal', '$exported-shm']) {
          final f = File(path);
          if (f.existsSync()) await f.delete();
        }
      }
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _handleMergeRegions() async {
    // mergeOfflineRegions imports every region contained in an external offline
    // database into the app's own store. There is no way to *produce* such a
    // file from the plugin (the native SDKs expose no per-region export), so we
    // let the user pick a `.db` they already have. This is Android/iOS only;
    // web has no offline storage, and this whole page is gated behind !kIsWeb.
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Select an offline database to merge',
      // Some platforms/file providers report .db with no MIME type, so fall
      // back to `any` rather than risk hiding valid files behind a filter.
      type: FileType.any,
    );
    final path = picked?.files.singleOrNull?.path;
    if (path == null) return; // user cancelled

    try {
      final merged = await mergeOfflineRegions(path);
      if (!mounted) return;
      // Reflect any merged region whose metadata name matches a known card.
      await _updateListOfRegions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Merged ${merged.length} region(s) from database',
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merge failed: $e')),
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
