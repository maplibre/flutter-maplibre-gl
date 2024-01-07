import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'page.dart';
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart';

class StyleInfo {
  final String name;
  final String baseStyle;
  final Future<void> Function(MaplibreMapController) addDetails;
  final CameraPosition position;

  const StyleInfo(
      {required this.name,
      required this.baseStyle,
      required this.addDetails,
      required this.position});
}

class Sources extends ExamplePage {
  const Sources({super.key}) : super(const Icon(Icons.map), 'Various Sources');

  @override
  Widget build(BuildContext context) {
    return const FullMap();
  }
}

class FullMap extends StatefulWidget {
  const FullMap({super.key});

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  MaplibreMapController? controller;
  final watercolorRasterId = "watercolorRaster";
  int selectedStyleId = 0;

  _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;
  }

  static Future<void> addRaster(MaplibreMapController controller) async {
    await controller.addSource(
      "watercolor",
      const RasterSourceProperties(
          tiles: [
            'https://stamen-tiles.a.ssl.fastly.net/watercolor/{z}/{x}/{y}.jpg'
          ],
          tileSize: 256,
          attribution:
              'Map tiles by <a target="_top" rel="noopener" href="http://stamen.com">Stamen Design</a>, under <a target="_top" rel="noopener" href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>. Data by <a target="_top" rel="noopener" href="http://openstreetmap.org">OpenStreetMap</a>, under <a target="_top" rel="noopener" href="http://creativecommons.org/licenses/by-sa/3.0">CC BY SA</a>'),
    );
    await controller.addLayer(
        "watercolor", "watercolor", const RasterLayerProperties());
  }

  static Future<void> addGeojsonCluster(
      MaplibreMapController controller) async {
    await controller.addSource(
        "earthquakes",
        const GeojsonSourceProperties(
            data:
                'https://docs.mapbox.com/mapbox-gl-js/assets/earthquakes.geojson',
            cluster: true,
            clusterMaxZoom: 14, // Max zoom to cluster points on
            clusterRadius:
                50 // Radius of each cluster when clustering points (defaults to 50)
            ));
    await controller.addLayer(
        "earthquakes",
        "earthquakes-circles",
        const CircleLayerProperties(circleColor: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          '#51bbd6',
          100,
          '#f1f075',
          750,
          '#f28cb1'
        ], circleRadius: [
          Expressions.step,
          [Expressions.get, 'point_count'],
          20,
          100,
          30,
          750,
          40
        ]));
    await controller.addLayer(
        "earthquakes",
        "earthquakes-count",
        const SymbolLayerProperties(
          textField: [Expressions.get, 'point_count_abbreviated'],
          textFont: ['Open Sans Semibold'],
          textSize: 12,
        ));
  }

  static Future<void> addVector(MaplibreMapController controller) async {
    await controller.addSource(
        "terrain",
        const VectorSourceProperties(
          url: "https://demotiles.maplibre.org/tiles/tiles.json",
        ));

    await controller.addLayer(
        "terrain",
        "contour",
        const LineLayerProperties(
          lineColor: "#ff69b4",
          lineWidth: 1,
          lineCap: "round",
          lineJoin: "round",
        ),
        sourceLayer: "countries");
  }

  static Future<void> addImage(MaplibreMapController controller) async {
    await controller.addSource(
        "radar",
        const ImageSourceProperties(
            url: "https://docs.mapbox.com/mapbox-gl-js/assets/radar.gif",
            coordinates: [
              [-80.425, 46.437],
              [-71.516, 46.437],
              [-71.516, 37.936],
              [-80.425, 37.936]
            ]));

    await controller.addRasterLayer(
      "radar",
      "radar",
      const RasterLayerProperties(rasterFadeDuration: 0),
    );
  }

  static Future<void> addVideo(MaplibreMapController controller) async {
    await controller.addSource(
        "video",
        const VideoSourceProperties(urls: [
          'https://static-assets.mapbox.com/mapbox-gl-js/drone.mp4',
          'https://static-assets.mapbox.com/mapbox-gl-js/drone.webm'
        ], coordinates: [
          [-122.51596391201019, 37.56238816766053],
          [-122.51467645168304, 37.56410183312965],
          [-122.51309394836426, 37.563391708549425],
          [-122.51423120498657, 37.56161849366671]
        ]));

    await controller.addRasterLayer(
      "video",
      "video",
      const RasterLayerProperties(),
    );
  }

  static Future<void> addHeatMap(MaplibreMapController controller) async {
    await controller.addSource(
        'earthquakes-heatmap-source',
        const GeojsonSourceProperties(
            data:
                'https://maplibre.org/maplibre-gl-js/docs/assets/earthquakes.geojson'));

    await controller.addLayer(
      'earthquakes-heatmap-source',
      'earthquakes-heatmap-layer',
      const HeatmapLayerProperties(
        // Increase the heatmap weight based on frequency and property magnitude
        heatmapWeight: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.get, 'mag'],
          0,
          0,
          6,
          1,
        ],
        // Increase the heatmap color weight weight by zoom level
        // heatmap-intensity is a multiplier on top of heatmap-weight
        heatmapIntensity: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          0,
          1,
          9,
          3
        ],
        // Color ramp for heatmap.  Domain is 0 (low) to 1 (high).
        // Begin color ramp at 0-stop with a 0-transparancy color
        // to create a blur-like effect.
        heatmapColor: [
          Expressions.interpolate,
          ['linear'],
          ['heatmap-density'],
          0,
          'rgba(33.0, 102.0, 172.0, 0.0)',
          0.2,
          'rgb(103.0, 169.0, 207.0)',
          0.4,
          'rgb(209.0, 229.0, 240.0)',
          0.6,
          'rgb(253.0, 219.0, 119.0)',
          0.8,
          'rgb(239.0, 138.0, 98.0)',
          1,
          'rgb(178.0, 24.0, 43.0)',
        ],
        // Adjust the heatmap radius by zoom level
        heatmapRadius: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          0,
          2,
          9,
          20,
        ],
        // Transition from heatmap to circle layer by zoom level
        heatmapOpacity: [
          Expressions.interpolate,
          ['linear'],
          [Expressions.zoom],
          7,
          1,
          9,
          0
        ],
      ),
      maxzoom: 9,
    );
  }

  static Future<void> addDem(MaplibreMapController controller) async {
    // TODO: adapt example?
    // await controller.addSource(
    //     "dem",
    //     RasterDemSourceProperties(
    //         url: "mapbox://mapbox.mapbox-terrain-dem-v1"));

    // await controller.addLayer(
    //   "dem",
    //   "hillshade",
    //   HillshadeLayerProperties(
    //       hillshadeExaggeration: 1,
    //       hillshadeShadowColor: Colors.blue.toHexStringRGB()),
    // );
  }

  final _stylesAndLoaders = [
    const StyleInfo(
      name: "Vector",
      baseStyle: MaplibreStyles.DEMO,
      addDetails: addVector,
      position: CameraPosition(target: LatLng(33.3832, -118.4333), zoom: 6),
    ),
    const StyleInfo(
      name: "Default style",
      // Using the raw github file version of MaplibreStyles.DEMO here, because we need to
      // specify a different baseStyle for consecutive elements in this list,
      // otherwise the map will not update
      baseStyle:
          "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json",
      addDetails: addDem,
      position: CameraPosition(target: LatLng(33.5, -118.1), zoom: 8),
    ),
    const StyleInfo(
      name: "Geojson cluster",
      baseStyle: MaplibreStyles.DEMO,
      addDetails: addGeojsonCluster,
      position: CameraPosition(target: LatLng(33.5, -118.1), zoom: 5),
    ),
    const StyleInfo(
      name: "Raster",
      baseStyle:
          "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json",
      addDetails: addRaster,
      position: CameraPosition(target: LatLng(40, -100), zoom: 3),
    ),
    const StyleInfo(
      name: "Image",
      baseStyle:
          "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json?",
      addDetails: addImage,
      position: CameraPosition(target: LatLng(43, -75), zoom: 6),
    ),
    const StyleInfo(
      name: "Heatmap",
      baseStyle:
          "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json",
      addDetails: addHeatMap,
      position: CameraPosition(target: LatLng(33.5, -118.1), zoom: 2),
    ),
    //video only supported on web
    if (kIsWeb)
      const StyleInfo(
        name: "Video",
        baseStyle:
            "https://raw.githubusercontent.com/maplibre/demotiles/gh-pages/style.json",
        addDetails: addVideo,
        position: CameraPosition(
            target: LatLng(37.562984, -122.514426), zoom: 17, bearing: -96),
      ),
  ];

  _onStyleLoadedCallback() async {
    final styleInfo = _stylesAndLoaders[selectedStyleId];
    styleInfo.addDetails(controller!);
    controller!
        .animateCamera(CameraUpdate.newCameraPosition(styleInfo.position));
  }

  @override
  Widget build(BuildContext context) {
    final styleInfo = _stylesAndLoaders[selectedStyleId];
    final nextName =
        _stylesAndLoaders[(selectedStyleId + 1) % _stylesAndLoaders.length]
            .name;
    return Scaffold(
        floatingActionButton: Padding(
          padding: const EdgeInsets.all(32.0),
          child: FloatingActionButton.extended(
            icon: const Icon(Icons.swap_horiz),
            label: SizedBox(
                width: 120, child: Center(child: Text("To $nextName"))),
            onPressed: () => setState(
              () => selectedStyleId =
                  (selectedStyleId + 1) % _stylesAndLoaders.length,
            ),
          ),
        ),
        body: Stack(
          children: [
            MaplibreMap(
              styleString: styleInfo.baseStyle,
              onMapCreated: _onMapCreated,
              initialCameraPosition: styleInfo.position,
              onStyleLoadedCallback: _onStyleLoadedCallback,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.topCenter,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Current source ${styleInfo.name}",
                    textScaleFactor: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
