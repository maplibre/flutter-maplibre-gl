import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:maplibre_gl_example/annotation_circle_page.dart';
import 'package:maplibre_gl_example/annotation_fill_page.dart';
import 'package:maplibre_gl_example/annotation_layer_page.dart';
import 'package:maplibre_gl_example/annotation_line_page.dart';
import 'package:maplibre_gl_example/annotation_order_page.dart';
import 'package:maplibre_gl_example/annotation_source_page.dart';
import 'package:maplibre_gl_example/annotation_symbol_page.dart';
import 'package:maplibre_gl_example/attribution_page.dart';
import 'package:maplibre_gl_example/batch_operation_page.dart';
import 'package:maplibre_gl_example/click_annotations_page.dart';
import 'package:maplibre_gl_example/custom_marker_page.dart';
import 'package:maplibre_gl_example/fullscreen_map_page.dart';
import 'package:maplibre_gl_example/local_style_page.dart';
import 'package:maplibre_gl_example/localized_map_page.dart';
import 'package:maplibre_gl_example/main_page.dart';
import 'package:maplibre_gl_example/map_state_page.dart';
import 'package:maplibre_gl_example/move_camera_animated.dart';
import 'package:maplibre_gl_example/move_camera_page.dart';
import 'package:maplibre_gl_example/no_location_permission_page.dart';
import 'package:maplibre_gl_example/offline_regions_page.dart';
import 'package:maplibre_gl_example/scrolling_map_page.dart';
import 'package:maplibre_gl_example/set_map_bounds_page.dart';
import 'package:maplibre_gl_example/user_interface_page.dart';
import 'package:maplibre_gl_example/various_sources_page.dart';

final routes = <String, WidgetBuilder>{
  ExamplePage.main.path: (context) => const MainPage(),
  ExamplePage.userInterface.path: (context) => const UserInterfacePage(),
  ExamplePage.fullscreen.path: (context) => const FullscreenMapPage(),
  ExamplePage.localized.path: (context) => const LocalizedMapPage(),
  ExamplePage.moveCameraAnimated.path: (context) => const AnimateCameraPage(),
  ExamplePage.moveCamera.path: (context) => const MoveCameraPage(),
  ExamplePage.localStyle.path: (context) => const LocalStylePage(),
  ExamplePage.scrolling.path: (context) => const ScrollingMapPage(),
  ExamplePage.offlineRegions.path: (context) => const OfflineRegionsPage(),
  ExamplePage.setMapBounds.path: (context) => const SetMapBoundsPage(),
  ExamplePage.mapState.path: (context) => const MapStatePage(),
  ExamplePage.noLocationPermission.path: (context) =>
      const NoLocationPermissionPage(),
  ExamplePage.annotationSymbol.path: (context) => const AnnotationSymbolPage(),
  ExamplePage.annotationSource.path: (context) => const AnnotationSourcePage(),
  ExamplePage.annotationLine.path: (context) => const AnnotationLinePage(),
  ExamplePage.annotationLayer.path: (context) => const AnnotationLayerPage(),
  ExamplePage.annotationCircle.path: (context) => const AnnotationCirclePage(),
  ExamplePage.annotationFill.path: (context) => const AnnotationFillPage(),
  ExamplePage.batchOperation.path: (context) => const BatchOperationPage(),
  ExamplePage.annotationOrder.path: (context) => const AnnotationOrderPage(),
  ExamplePage.customMarker.path: (context) => const CustomMarkerPage(),
  ExamplePage.clickAnnotation.path: (context) => const ClickAnnotationPage(),
  ExamplePage.variousSources.path: (context) => const VariousSourcesPage(),
  ExamplePage.attribution.path: (context) => const AttributionPage(),
};

enum ExamplePage {
  main('/', 'MapLibre Examples'),
  userInterface('/user-interface', 'User interface'),
  fullscreen('/fullscreen', 'Fullscreen map'),
  localized('/localized', 'Localized map'),
  moveCameraAnimated('/move-camera-animated', 'Move camera animated'),
  moveCamera('/move-camera', 'Move camera'),
  localStyle('/local-style', 'Local style'),
  scrolling('/scrolling', 'Scrolling map'),
  offlineRegions('/offline-regions', 'Offline regions'),
  setMapBounds('/set-map-bounds', 'Set map bounds'),
  mapState('/map-info', 'Get map state'),
  noLocationPermission('/no-location-permission', 'No user location permission',
      needsLocationPermission: false),
  annotationSymbol('/annotation-symbol', 'Symbol'),
  annotationSource('/annotation-source', 'Source'),
  annotationLine('/annotation-line', 'Line'),
  annotationLayer('/annotation-layer', 'Layer'),
  annotationCircle('/annotation-circle', 'Circle'),
  annotationFill('/annotation-fill', 'Fill'),
  batchOperation('/batch-operation', 'Batch operation'),
  annotationOrder('/annotation-order', 'Annotation order'),
  customMarker('/custom-marker', 'Custom marker'),
  clickAnnotation('/click-annotation', 'Click annotation'),
  variousSources('/various-sources', 'Various sources'),
  attribution('/attribution', 'Attribution');

  const ExamplePage(
    this.path,
    this.title, {
    this.needsLocationPermission = true,
  });

  final String path;
  final String title;
  final bool needsLocationPermission;
}

void main() {
  usePathUrlStrategy();
  final materialTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xff295daa),
  );

  runApp(
    MaterialApp(
      theme: materialTheme,
      initialRoute: ExamplePage.main.path,
      routes: routes,
    ),
  );
}
