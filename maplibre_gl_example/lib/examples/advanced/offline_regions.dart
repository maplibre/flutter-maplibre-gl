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
  southwest: const LatLng(-33.5597, -70.49102),
  northeast: const LatLng(-33.33282, -70.40102),
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
    required this.name,
    required this.estimatedTiles,
  });

  final OfflineRegionDefinition offlineRegionDefinition;
  final int? downloadedId;
  final bool isDownloading;
  final String name;
  final int estimatedTiles;

  OfflineRegionListItem copyWith({
    int? downloadedId,
    bool? isDownloading,
  }) =>
      OfflineRegionListItem(
        offlineRegionDefinition: offlineRegionDefinition,
        name: name,
        estimatedTiles: estimatedTiles,
        downloadedId: downloadedId,
        isDownloading: isDownloading ?? this.isDownloading,
      );

  bool get isDownloaded => downloadedId != null;
}

final List<OfflineRegionListItem> allRegions = [
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[0],
    downloadedId: null,
    isDownloading: false,
    name: regionNames[0],
    estimatedTiles: 61,
  ),
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[1],
    downloadedId: null,
    isDownloading: false,
    name: regionNames[1],
    estimatedTiles: 3580,
  ),
  OfflineRegionListItem(
    offlineRegionDefinition: regionDefinitions[2],
    downloadedId: null,
    isDownloading: false,
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
    return _items.isEmpty
        ? const Center(
            child: CircularProgressIndicator(),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
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
                          color: item.isDownloaded
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item.isDownloaded
                              ? Icons.cloud_done
                              : Icons.cloud_download,
                          color: item.isDownloaded
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      subtitle: Text(
                        'Estimated tiles: ${item.estimatedTiles}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      trailing: item.isDownloading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
                            child: item.isDownloaded
                                ? ExampleButton(
                                    label: 'Delete',
                                    icon: Icons.delete_outline,
                                    onPressed: item.isDownloading
                                        ? null
                                        : () => _deleteRegion(item, index),
                                    style: ExampleButtonStyle.destructive,
                                  )
                                : ExampleButton(
                                    label: 'Download',
                                    icon: Icons.download,
                                    onPressed: item.isDownloading
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
            },
          );
  }

  Future<void> _updateListOfRegions() async {
    final offlineRegions = await getListOfRegions();
    final regionItems = <OfflineRegionListItem>[];
    for (final item in allRegions) {
      final offlineRegion = offlineRegions.firstWhereOrNull(
          (offlineRegion) => offlineRegion.metadata['name'] == item.name);
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
      _items.removeAt(index);
      _items.insert(index, item.copyWith(isDownloading: true));
    });

    try {
      final downloadingRegion = await downloadOfflineRegion(
        item.offlineRegionDefinition,
        metadata: {
          'name': regionNames[index],
        },
      );
      setState(() {
        _items.removeAt(index);
        _items.insert(
            index,
            item.copyWith(
              isDownloading: false,
              downloadedId: downloadingRegion.id,
            ));
      });
    } on Exception catch (_) {
      setState(() {
        _items.removeAt(index);
        _items.insert(
            index,
            item.copyWith(
              isDownloading: false,
              downloadedId: null,
            ));
      });
      return;
    }
  }

  Future<void> _deleteRegion(OfflineRegionListItem item, int index) async {
    setState(() {
      _items.removeAt(index);
      _items.insert(index, item.copyWith(isDownloading: true));
    });

    await deleteOfflineRegion(
      item.downloadedId!,
    );

    setState(() {
      _items.removeAt(index);
      _items.insert(
          index,
          item.copyWith(
            isDownloading: false,
            downloadedId: null,
          ));
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
