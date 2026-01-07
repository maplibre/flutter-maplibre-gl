import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../page.dart';

class StyleInfo {
  final String name;
  final String baseStyle;
  final Future<void> Function(MapLibreMapController) addDetails;
  final CameraPosition position;

  const StyleInfo(
      {required this.name,
      required this.baseStyle,
      required this.addDetails,
      required this.position});
}

class VariousSources extends ExamplePage {
  const VariousSources({super.key})
      : super(const Icon(Icons.map), 'Various Sources',
            category: ExampleCategory.layers);

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
  MapLibreMapController? controller;
  final watercolorRasterId = "watercolorRaster";
  int selectedStyleId = 0;

  void _onMapCreated(MapLibreMapController controller) {
    setState(() => this.controller = controller);
  }

  static Future<void> addRaster(MapLibreMapController controller) async {
    await controller.addSource(
      "osm-raster",
      const RasterSourceProperties(
          tiles: [
            'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://b.tile.openstreetmap.org/{z}/{x}/{y}.png',
            'https://c.tile.openstreetmap.org/{z}/{x}/{y}.png'
          ],
          tileSize: 256,
          attribution:
              '<a href="https://www.openstreetmap.org/copyright">© OpenStreetMap contributors</a>'),
    );
    await controller.addLayer(
        "osm-raster", "osm-raster", const RasterLayerProperties());
  }

  static Future<void> addGeojsonCluster(
      MapLibreMapController controller) async {
    await controller.addSource(
      "earthquakes",
      const GeojsonSourceProperties(
          data:
              'https://maplibre.org/maplibre-gl-js/docs/assets/earthquakes.geojson',
          cluster: true,
          clusterMaxZoom: 14, // Max zoom to cluster points on
          clusterRadius:
              50, // Radius of each cluster when clustering points (defaults to 50)
          attribution:
              '<a href="https://maplibre.org">Earthquake data © MapLibre</a>'),
    );
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

  static Future<void> addVector(MapLibreMapController controller) async {
    await controller.addSource(
        "openmaptiles",
        const VectorSourceProperties(
          tiles: [
            'https://demotiles.maplibre.org/tiles/{z}/{x}/{y}.pbf',
          ],
          maxzoom: 14,
          attribution:
              '<a href="https://maplibre.org">© MapLibre contributors</a',
        ));

    await controller.addLayer(
        "openmaptiles",
        "water-fill",
        const FillLayerProperties(
          fillColor: "#0080ff",
          fillOpacity: 0.5,
        ),
        sourceLayer: "water");

    await controller.addLayer(
        "openmaptiles",
        "roads",
        const LineLayerProperties(
          lineColor: "#ff69b4",
          lineWidth: 2,
          lineCap: "round",
          lineJoin: "round",
        ),
        sourceLayer: "transportation");
  }

  static Future<void> addImage(MapLibreMapController controller) async {
    await controller.addSource(
      "radar",
      const ImageSourceProperties(
        url: "https://maplibre.org/maplibre-gl-js/docs/assets/radar.gif",
        coordinates: [
          [-80.425, 46.437],
          [-71.516, 46.437],
          [-71.516, 37.936],
          [-80.425, 37.936]
        ],
      ),
    );

    await controller.addRasterLayer(
      "radar",
      "radar",
      const RasterLayerProperties(rasterFadeDuration: 0),
    );
  }

  static Future<void> addVideo(MapLibreMapController controller) async {
    await controller.addSource(
      "video",
      const VideoSourceProperties(
        urls: [
          'https://static-assets.mapbox.com/mapbox-gl-js/drone.mp4',
          'https://static-assets.mapbox.com/mapbox-gl-js/drone.webm'
        ],
        coordinates: [
          [-122.51596391201019, 37.56238816766053],
          [-122.51467645168304, 37.56410183312965],
          [-122.51309394836426, 37.563391708549425],
          [-122.51423120498657, 37.56161849366671]
        ],
      ),
    );

    await controller.addRasterLayer(
      "video",
      "video",
      const RasterLayerProperties(),
    );
  }

  static Future<void> addHeatMap(MapLibreMapController controller) async {
    await controller.addSource(
      'earthquakes-heatmap-source',
      const GeojsonSourceProperties(
        data:
            'https://maplibre.org/maplibre-gl-js/docs/assets/earthquakes.geojson',
        attribution:
            '<a href="https://maplibre.org">Earthquake data © MapLibre</a>',
      ),
    );

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

  static Future<void> addCountries(MapLibreMapController controller) async {
    // Add a simple additional layer to demonstrate layering on the default style
    // Remove existing layers/source if they exist (in case of re-loading)
    try {
      await controller.removeLayer("countries-fill");
    } catch (e) {
      // Layer doesn't exist, ignore
    }
    try {
      await controller.removeLayer("countries-outline");
    } catch (e) {
      // Layer doesn't exist, ignore
    }
    try {
      await controller.removeSource("countries-highlight");
    } catch (e) {
      // Source doesn't exist, ignore
    }

    // Source: Natural Earth public domain data
    // Free vector and raster map data @ naturalearthdata.com
    await controller.addSource(
      "countries-highlight",
      const GeojsonSourceProperties(
        data:
            'https://d2ad6b4ur7yvpq.cloudfront.net/naturalearth-3.3.0/ne_110m_admin_0_countries.geojson',
        attribution:
            '<a href="https://www.naturalearthdata.com">GeoJSON data courtesy of Natural Earth</a>',
      ),
    );

    await controller.addLayer(
      "countries-highlight",
      "countries-fill",
      const FillLayerProperties(
        fillColor: "#627BC1",
        fillOpacity: 0.3,
      ),
    );

    await controller.addLayer(
      "countries-highlight",
      "countries-outline",
      const LineLayerProperties(
        lineColor: "#627BC1",
        lineWidth: 2,
      ),
    );
  }

  static Future<void> addDemHillshade(MapLibreMapController controller) async {
    // Remove existing layers/source if they exist
    try {
      await controller.removeLayer("hillshade-layer");
    } catch (e) {
      // Layer doesn't exist, ignore
    }
    try {
      await controller.removeSource("terrarium-dem");
    } catch (e) {
      // Source doesn't exist, ignore
    }

    // Source: Terrarium terrain tiles
    await controller.addSource(
      "terrarium-dem",
      const RasterDemSourceProperties(
        tiles: [
          'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'
        ],
        minzoom: 0,
        maxzoom: 15,
        tileSize: 256,
        encoding: 'terrarium',
        attribution:
            '<a href="https://registry.opendata.aws/terrain-tiles/">Elevation data © AWS Terrain Tiles</a>',
      ),
    );

    await controller.addLayer(
      "terrarium-dem",
      "hillshade-layer",
      HillshadeLayerProperties(
        hillshadeExaggeration: 0.8,
        hillshadeShadowColor: Colors.blue.shade900.toHexStringRGB(),
        hillshadeHighlightColor: Colors.white.toHexStringRGB(),
      ),
    );
  }

  final _stylesAndLoaders = [
    const StyleInfo(
      name: "Vector",
      baseStyle: MapLibreStyles.demo,
      addDetails: addVector,
      position: CameraPosition(target: LatLng(33.3832, -118.4333), zoom: 6),
    ),
    const StyleInfo(
      name: "Countries GeoJSON",
      // Using the raw github file version of MapLibreStyles.DEMO here, because we need to
      // specify a different baseStyle for consecutive elements in this list,
      // otherwise the map will not update
      baseStyle: MapLibreStyles.demo,
      addDetails: addCountries,
      position: CameraPosition(target: LatLng(20, 0), zoom: 2),
    ),
    const StyleInfo(
      name: "DEM Hillshade",
      baseStyle: MapLibreStyles.demo,
      addDetails: addDemHillshade,
      position: CameraPosition(
          target: LatLng(46.5, 8.0), zoom: 8, bearing: 80, tilt: 60),
    ),
    const StyleInfo(
      name: "Geojson cluster",
      baseStyle: MapLibreStyles.demo,
      addDetails: addGeojsonCluster,
      position: CameraPosition(target: LatLng(33.5, -118.1), zoom: 5),
    ),
    const StyleInfo(
      name: "Raster",
      baseStyle: MapLibreStyles.demo,
      addDetails: addRaster,
      position: CameraPosition(target: LatLng(40, -100), zoom: 3),
    ),
    const StyleInfo(
      name: "Image",
      baseStyle: MapLibreStyles.demo,
      addDetails: addImage,
      position: CameraPosition(target: LatLng(43, -75), zoom: 6),
    ),
    const StyleInfo(
      name: "Heatmap",
      baseStyle: MapLibreStyles.demo,
      addDetails: addHeatMap,
      position: CameraPosition(target: LatLng(33.5, -118.1), zoom: 2),
    ),
    //video only supported on web
    if (kIsWeb)
      const StyleInfo(
        name: "Video",
        baseStyle: MapLibreStyles.demo,
        addDetails: addVideo,
        position: CameraPosition(
            target: LatLng(37.562984, -122.514426), zoom: 17, bearing: -96),
      ),
  ];

  Future<void> _loadCurrentSource() async {
    if (controller == null) return;
    final styleInfo = _stylesAndLoaders[selectedStyleId];
    // Reload the style to clear all previous layers/sources
    await controller!.setStyle(styleInfo.baseStyle);
    // Wait for style to load, then add the new source details
    // The onStyleLoadedCallback will be triggered again, but we need to prevent recursion
  }

  Future<void> _onStyleLoadedCallback() async {
    if (controller == null) return;
    final styleInfo = _stylesAndLoaders[selectedStyleId];
    await styleInfo.addDetails(controller!);
    await controller!
        .animateCamera(CameraUpdate.newCameraPosition(styleInfo.position));
  }

  @override
  Widget build(BuildContext context) {
    final styleInfo = _stylesAndLoaders[selectedStyleId];
    final nextName =
        _stylesAndLoaders[(selectedStyleId + 1) % _stylesAndLoaders.length]
            .name;
    return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.swap_horiz),
          label:
              SizedBox(width: 120, child: Center(child: Text("To $nextName"))),
          onPressed: () async {
            setState(() {
              selectedStyleId =
                  (selectedStyleId + 1) % _stylesAndLoaders.length;
            });
            await _loadCurrentSource();
          },
        ),
        body: Stack(
          children: [
            MapLibreMap(
              styleString: styleInfo.baseStyle,
              onMapCreated: _onMapCreated,
              initialCameraPosition: styleInfo.position,
              onStyleLoadedCallback: _onStyleLoadedCallback,
              logoEnabled: true,
              attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            ),
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.topCenter,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Current source: ${styleInfo.name}",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
