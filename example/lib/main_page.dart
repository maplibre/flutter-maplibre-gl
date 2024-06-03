import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _categories = <String, List<CategoryItem>>{
  'General': <CategoryItem>[
    CategoryItem(ExamplePage.fullscreen, Icons.fullscreen),
    CategoryItem(ExamplePage.localized, Icons.language),
    CategoryItem(ExamplePage.localStyle, Icons.language),
    CategoryItem(ExamplePage.scrolling, Icons.map_outlined),
    CategoryItem(
        ExamplePage.offlineRegions, Icons.download_for_offline_outlined),
    CategoryItem(ExamplePage.mapState, Icons.info_outline),
    CategoryItem(ExamplePage.noLocationPermission, Icons.gps_off),
    CategoryItem(ExamplePage.variousSources, Icons.layers_outlined),
    CategoryItem(ExamplePage.attribution, Icons.thumb_up_alt_outlined),
  ],
  'Interactivity': <CategoryItem>[
    CategoryItem(ExamplePage.userInterface, Icons.accessibility_new_outlined),
    CategoryItem(ExamplePage.moveCamera, Icons.control_camera),
    CategoryItem(ExamplePage.moveCameraAnimated, Icons.animation),
    CategoryItem(ExamplePage.setMapBounds, Icons.control_camera),
  ],
  'Annotations': <CategoryItem>[
    CategoryItem(ExamplePage.annotationCircle, Icons.circle_outlined),
    CategoryItem(ExamplePage.annotationFill, Icons.format_shapes_outlined),
    CategoryItem(ExamplePage.annotationLayer, Icons.layers_outlined),
    CategoryItem(ExamplePage.annotationLine, Icons.share),
    CategoryItem(ExamplePage.annotationSource, Icons.source_outlined),
    CategoryItem(ExamplePage.annotationSymbol, Icons.place_outlined),
    CategoryItem(ExamplePage.batchOperation, Icons.list_alt),
    CategoryItem(ExamplePage.annotationOrder, Icons.layers_outlined),
    CategoryItem(ExamplePage.customMarker, Icons.place_outlined),
    CategoryItem(ExamplePage.clickAnnotation, Icons.touch_app_outlined),
  ],
};

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  /// Determine the android version of the phone and turn off HybridComposition
  /// on older sdk versions to improve performance for these
  ///
  /// upstream issue: https://github.com/flutter-mapbox-gl/maps/pull/916
  ///
  /// flutter issue: https://github.com/flutter/flutter/issues/97494
  ///
  /// TODO: Hybrid composition is currently broken do no use
  /// https://github.com/flutter-mapbox-gl/maps/issues/1077
  Future<void> initHybridComposition() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      if (sdkVersion >= 29) {
        MaplibreMap.useHybridComposition = true;
      } else {
        MaplibreMap.useHybridComposition = false;
      }
    }
  }

  void _pushPage(BuildContext context, CategoryItem model) async {
    if (!kIsWeb && model.page.needsLocationPermission) {
      final location = Location();
      final hasPermissions = await location.hasPermission();
      if (hasPermissions != PermissionStatus.granted) {
        final _ = await location.requestPermission();
      }
    }
    if (context.mounted) {
      Navigator.of(context).pushNamed(model.page.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      childAspectRatio: 3,
    );
    final slivers = <Widget>[];
    for (final MapEntry(:key, :value) in _categories.entries) {
      slivers.addAll([
        SliverToBoxAdapter(child: ListSectionTitle(key)),
        SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemCount: value.length,
          itemBuilder: (_, int index) => ListTile(
            leading: Icon(value[index].iconData),
            title: Text(value[index].page.title),
            onTap: () => _pushPage(context, value[index]),
          ),
        ),
      ]);
    }
    slivers.addAll([
      const SliverToBoxAdapter(child: ListSectionTitle('About this App')),
      SliverGrid(
        gridDelegate: gridDelegate,
        delegate: SliverChildListDelegate([
          ListTile(
            title: const Text("Show licenses"),
            leading: const Icon(Icons.info_outline),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MapLibre Examples',
            ),
          ),
          ListTile(
            title: const Text("View on pub.dev"),
            leading: const Icon(Icons.flutter_dash),
            onTap: () => launchUrlString(
              "https://pub.dev/packages/maplibre_gl",
            ),
          ),
          ListTile(
            title: const Text("View source code"),
            leading: const Icon(Icons.code),
            onTap: () => launchUrlString(
              "https://github.com/maplibre/flutter-maplibre-gl",
            ),
          ),
        ]),
      ),
    ]);

    return ExampleScaffold(
      page: ExamplePage.main,
      body: CustomScrollView(slivers: slivers),
    );
  }
}

class ListSectionTitle extends StatelessWidget {
  final String title;

  const ListSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 18, color: Theme.of(context).primaryColor),
      ),
    );
  }
}

class CategoryItem {
  final ExamplePage page;
  final IconData iconData;

  const CategoryItem(this.page, this.iconData);
}
