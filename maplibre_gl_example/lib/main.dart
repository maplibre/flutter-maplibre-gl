import 'dart:async' show unawaited;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Page system
import 'page.dart';

// Basics examples
import 'examples/basics/full_map_example.dart';
import 'examples/basics/multi_style_switch.dart';
import 'examples/basics/get_map_state.dart';
import 'examples/basics/gps_location_page.dart';

// Camera examples
import 'examples/camera/camera_controls_example.dart';
import 'examples/camera/camera_bounds_example.dart';

// Interaction examples
import 'examples/interaction/map_controls_example.dart';
import 'examples/interaction/map_gestures_example.dart';

// Annotations examples
import 'examples/annotations/annotations_example.dart';
import 'examples/annotations/annotation_order_example.dart';
import 'examples/annotations/annotation_properties_example.dart';
import 'examples/annotations/custom_marker.dart';

// Layers examples
import 'examples/layers/circle_layer_example.dart';
import 'examples/layers/fill_layer_example.dart';
import 'examples/layers/line_layer_example.dart';
import 'examples/layers/symbol_layer_example.dart';
import 'examples/layers/various_sources.dart';

// Advanced examples
import 'examples/advanced/map_snapshot.dart';
import 'examples/advanced/offline_regions.dart';
import 'examples/advanced/pmtiles.dart';
import 'examples/advanced/translucent_full_map.dart';

void main() {
  runApp(const MapLibreExampleApp());
}

class MapLibreExampleApp extends StatelessWidget {
  const MapLibreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapLibre Examples',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MapsDemo(),
    );
  }
}

final List<ExamplePage> _allPages = <ExamplePage>[
  // Basics
  const FullMapExample(),
  const MultiStyleSwitchPage(),
  const GpsLocationPage(),
  const GetMapInfoPage(),

  // Camera
  const CameraControlsExample(),
  const CameraBoundsExample(),

  // Interaction
  const MapControlsExample(),
  const MapGesturesExample(),

  // Annotations
  const AnnotationsExample(),
  const AnnotationPropertiesExample(),
  const AnnotationOrderExample(),
  const CustomMarkerPage(),

  // Layers
  const SymbolLayerExample(),
  const CircleLayerExample(),
  const FillLayerExample(),
  const LineLayerExample(),
  const VariousSources(),

  // Advanced
  const MapSnapshotPage(),
  const PMTilesPage(),
  const OfflineRegionsPage(),
  const TranslucentFullMapPage(),
];

class MapsDemo extends StatefulWidget {
  const MapsDemo({super.key});

  @override
  State<MapsDemo> createState() => _MapsDemoState();
}

class _MapsDemoState extends State<MapsDemo> {
  @override
  void initState() {
    super.initState();
    unawaited(initHybridComposition());
  }

  /// Determine the android version of the phone and turn off HybridComposition
  /// on older sdk versions to improve performance for these
  ///
  /// !!! Hybrid composition is currently broken do no use !!!
  Future<void> initHybridComposition() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 29) {
        MapLibreMap.useHybridComposition = true;
      } else {
        MapLibreMap.useHybridComposition = false;
      }
    }
  }

  Future<void> _pushPage(BuildContext context, ExamplePage page) async {
    if (!kIsWeb && page.needsLocationPermission) {
      final location = Location();
      final hasPermissions = await location.hasPermission();
      if (hasPermissions != PermissionStatus.granted) {
        await location.requestPermission();
      }
    }
    if (context.mounted) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(page.title)),
          body: page,
        ),
      ));
    }
  }

  Map<ExampleCategory, List<ExamplePage>> _groupByCategory() {
    final grouped = <ExampleCategory, List<ExamplePage>>{};
    for (final page in _allPages) {
      grouped.putIfAbsent(page.category, () => []).add(page);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedPages = _groupByCategory();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(
            title: Text('MapLibre Examples'),
            floating: true,
            snap: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Explore ${_allPages.length} interactive examples',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Learn how to use MapLibre GL with Flutter through categorized examples.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                const categories = ExampleCategory.values;
                if (index >= categories.length) {
                  // About tile at the end
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: AboutListTile(
                      icon: Icon(Icons.info),
                      applicationName: "MapLibre GL Flutter",
                      aboutBoxChildren: [
                        Text(
                            'MapLibre GL Flutter is an open-source Flutter plugin for embedding interactive maps using the MapLibre GL Native library.'),
                        SizedBox(height: 8),
                        Text(
                            'This example app showcases various features and capabilities of the MapLibre GL Flutter plugin through interactive examples.'),
                      ],
                    ),
                  );
                }

                final category = categories[index];
                final pages = groupedPages[category] ?? [];

                if (pages.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 4.0),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: Icon(
                        category.icon,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        category.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('${pages.length} examples'),
                      children: pages
                          .map((page) => ListTile(
                                leading: page.leading,
                                title: Text(page.title),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _pushPage(context, page),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
              childCount: ExampleCategory.values.length + 1,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }
}
