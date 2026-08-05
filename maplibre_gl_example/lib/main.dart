import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';

// PMTiles protocol registration is JS interop, so it only exists on web; the
// native stub keeps the example compiling for Android and iOS.
import 'pmtiles_protocol_native.dart'
    if (dart.library.js_interop) 'pmtiles_protocol_web.dart'
    as pmtiles_protocol;

// Page system
import 'page.dart';
import 'shared/constants.dart';

// Basics examples
import 'examples/basics/full_map_example.dart';
import 'examples/basics/multi_style_switch.dart';
import 'examples/layers/various_sources.dart';
import 'examples/basics/get_map_state.dart';
import 'examples/basics/gps_location_page.dart';
import 'examples/basics/manual_location_source_page.dart';

// Camera examples
import 'examples/camera/camera_controls_example.dart';
import 'examples/camera/camera_bounds_example.dart';

// Interaction examples
import 'examples/interaction/map_controls_example.dart';
import 'examples/interaction/map_gestures_example.dart';
import 'examples/interaction/hover_effect_example.dart';

// Annotations examples
import 'examples/annotations/annotations_example.dart';
import 'examples/annotations/annotation_order_example.dart';
import 'examples/annotations/annotation_properties_example.dart';
import 'examples/annotations/custom_marker.dart';
import 'examples/annotations/edit_annotation_animated.dart';
import 'examples/annotations/edit_annotation_draggable.dart';

// Layers examples
import 'examples/layers/circle_layer_example.dart';
import 'examples/layers/cluster_properties_example.dart';
import 'examples/layers/fill_layer_example.dart';
import 'examples/layers/line_layer_example.dart';
import 'examples/layers/symbol_layer_example.dart';
import 'examples/layers/edit_style_layer_animated.dart';
import 'examples/layers/edit_style_layer_draggable.dart';

// Advanced examples
import 'examples/advanced/offline_regions.dart';
import 'examples/advanced/pmtiles.dart';
import 'examples/advanced/translucent_full_map.dart';
import 'examples/advanced/map_snapshot.dart';
import 'examples/advanced/map_language.dart';
import 'examples/advanced/large_geojson_stress.dart';

// Doc-only examples (not shown in app home, only reachable via ?example=slug)
import 'examples/docs/doc_full_map.dart';
import 'examples/docs/doc_symbol_layer.dart';
import 'examples/docs/doc_circle_layer.dart';
import 'examples/docs/doc_fill_layer.dart';
import 'examples/docs/doc_line_layer.dart';
import 'examples/docs/doc_cluster.dart';
import 'examples/docs/doc_annotation_markers.dart';
import 'examples/docs/doc_camera.dart';
import 'examples/docs/doc_geojson_source.dart';
import 'examples/docs/doc_pmtiles.dart';
import 'examples/docs/doc_heatmap.dart';
import 'examples/docs/doc_expressions.dart';

String? _initialExampleSlug() {
  if (!kIsWeb) return null;
  return Uri.base.queryParameters['example'];
}

Future<void> main() async {
  // Pre-warm the MapLibre engine to overlap its initialization with Flutter's
  // startup. Deliberately not awaited: overlapping is the whole point, and on
  // web it also starts the download of maplibre-gl-js right away.
  unawaited(MapLibreMap.preWarm());

  if (kIsWeb) {
    // The plugin loads maplibre-gl-js itself, so unlike the old <script> tag
    // setup the maplibregl global does not exist at page parse time, and the
    // PMTiles protocol can no longer be registered by an inline script in
    // index.html. Wait for the library, then register the protocol from Dart
    // before any map is built.
    await MapLibreMap.ensureWebLibraryLoaded();
    pmtiles_protocol.registerPmTilesProtocol(
      'https://demo-bucket.protomaps.com/v4.pmtiles',
    );

    print(
      'Running with WASM: $kIsWasm, in ${kReleaseMode
          ? "release"
          : kProfileMode
          ? "profile"
          : "debug"} mode',
    );
  } else {
    // demotiles.maplibre.org rate-limits aggressively (HTTP 429); pick a
    // reachable default style before the gallery builds any map.
    WidgetsFlutterBinding.ensureInitialized();
    await ExampleConstants.resolveDemoMapStyle();
  }

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
      home:
          [
            ..._allPages,
            ..._docPages,
          ].where((p) => p.slug == _initialExampleSlug()).firstOrNull ??
          const MapsDemo(),
    );
  }
}

final List<ExamplePage> _allPages = <ExamplePage>[
  // Basics
  const FullMapExample(),
  const MultiStyleSwitchPage(),
  const VariousSources(),
  const GpsLocationPage(),
  const ManualLocationSourcePage(),
  const GetMapInfoPage(),

  // Camera
  const CameraControlsExample(),
  const CameraBoundsExample(),

  // Interaction
  const MapControlsExample(),
  const MapGesturesExample(),
  // Feature state is available on web and Android, not on iOS yet.
  if (HoverEffectExample.isSupported) const HoverEffectExample(),

  // Annotations
  const AnnotationsExample(),
  const AnnotationPropertiesExample(),
  const AnnotationOrderExample(),
  const CustomMarkerPage(),
  const EditAnnotationAnimatedExample(),
  const EditAnnotationDraggableExample(),

  // Layers
  const SymbolLayerExample(),
  const CircleLayerExample(),
  const ClusterPropertiesExample(),
  const FillLayerExample(),
  const LineLayerExample(),
  const EditStyleLayerAnimatedExample(),
  const EditStyleLayerDraggableExample(),

  // Advanced
  const MapLanguageExample(),
  const PMTilesPage(),
  // Offline regions are Android/iOS only — MapLibre GL JS has no offline API.
  if (!kIsWeb) const OfflineRegionsPage(),
  const TranslucentFullMapPage(),
  const MapSnapshotPage(),
  const LargeGeojsonStressPage(),
];

// Doc-only pages: not shown in the app home list, only reachable via ?example=<slug>.
// These render mapOnly: true — clean fullscreen map for iframe embeds in the docs site.
final List<ExamplePage> _docPages = [
  const DocFullMapExample(),
  const DocSymbolLayerExample(),
  const DocCircleLayerExample(),
  const DocFillLayerExample(),
  const DocLineLayerExample(),
  const DocClusterExample(),
  const DocAnnotationMarkersExample(),
  const DocCameraExample(),
  const DocGeoJsonSourceExample(),
  const DocPMTilesExample(),
  const DocHeatmapExample(),
  const DocExpressionsExample(),
];

class MapsDemo extends StatefulWidget {
  const MapsDemo({super.key});

  @override
  State<MapsDemo> createState() => _MapsDemoState();
}

class _MapsDemoState extends State<MapsDemo> {
  Future<void> _pushPage(BuildContext context, ExamplePage page) async {
    if (!kIsWeb) {
      // Re-check right before the map loads: demotiles' limiter answers per
      // request, so the startup probe can pass and the page's style request
      // still get a 429 minutes later. A recent success skips the probe.
      await ExampleConstants.resolveDemoMapStyle(
        maxAge: const Duration(seconds: 30),
      );
    }
    if (!kIsWeb && page.needsLocationPermission) {
      final status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        await Permission.locationWhenInUse.request();
      }
    }
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder:
              (_) => Scaffold(
                appBar: AppBar(title: Text(page.title)),
                body: page,
              ),
        ),
      );
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: AboutListTile(
                      icon: Icon(Icons.info),
                      applicationName: "MapLibre GL Flutter",
                      aboutBoxChildren: [
                        Text(
                          'MapLibre GL Flutter is an open-source Flutter plugin for embedding interactive maps using the MapLibre GL Native library.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          'This example app showcases various features and capabilities of the MapLibre GL Flutter plugin through interactive examples.',
                        ),
                      ],
                    ),
                  );
                }

                final category = categories[index];
                final pages = groupedPages[category] ?? [];

                if (pages.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
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
                      children:
                          pages
                              .map(
                                (page) => ListTile(
                                  leading: page.leading,
                                  title: Text(page.title),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _pushPage(context, page),
                                ),
                              )
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
