import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/page.dart';

import 'util.dart';

class LayerPage extends ExamplePage {
  const LayerPage({super.key}) : super(const Icon(Icons.share), 'Layer');

  @override
  Widget build(BuildContext context) => const LayerBody();
}

class LayerBody extends StatefulWidget {
  const LayerBody({super.key});

  @override
  State<StatefulWidget> createState() => LayerState();
}

class LayerState extends State {
  static const LatLng center = LatLng(-33.86711, 151.1947171);

  late MaplibreMapController controller;
  Timer? bikeTimer;
  Timer? filterTimer;
  int filteredId = 0;
  bool linesVisible = true;
  bool fillsVisible = true;
  bool symbolsVisible = true;
  bool circlesVisible = true;
  bool linesRed = false;
  bool fillsRed = true;
  bool symbolsRed = false;
  bool circlesRed = false;

  @override
  Widget build(BuildContext context) {
    return ListView(children: <Widget>[
      Center(
        child: SizedBox(
            height: 400.0,
            child: MaplibreMap(
              dragEnabled: false,
              myLocationEnabled: true,
              onMapCreated: _onMapCreated,
              onMapClick: (point, latLong) =>
                  debugPrint(point.toString() + latLong.toString()),
              onStyleLoadedCallback: _onStyleLoadedCallback,
              initialCameraPosition: const CameraPosition(
                target: center,
                zoom: 11.0,
              ),
              annotationOrder: const [],
            )),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "lines",
                  LineLayerProperties.fromJson(
                      {"visibility": linesVisible ? "none" : "visible"}))
              .then((value) => setState(() => linesVisible = !linesVisible));
        },
        child: const Text('toggle line visibility'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "lines",
                  LineLayerProperties.fromJson(
                      {"line-color": linesRed ? "#0000ff" : "#ff0000"}))
              .then((value) => setState(() => linesRed = !linesRed));
        },
        child: const Text('toggle line color'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "fills",
                  FillLayerProperties.fromJson(
                      {"visibility": fillsVisible ? "none" : "visible"}))
              .then((value) => setState(() => fillsVisible = !fillsVisible));
        },
        child: const Text('toggle fill visibility'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "fills",
                  FillLayerProperties.fromJson(
                      {"fill-color": fillsRed ? "#0000ff" : "#ff0000"}))
              .then((value) => setState(() => fillsRed = !fillsRed));
        },
        child: const Text('toggle fill color'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "circles",
                  CircleLayerProperties.fromJson(
                      {"visibility": circlesVisible ? "none" : "visible"}))
              .then(
                  (value) => setState(() => circlesVisible = !circlesVisible));
        },
        child: const Text('toggle circle visibility'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "circles",
                  CircleLayerProperties.fromJson(
                      {"circle-color": circlesRed ? "#0000ff" : "#ff0000"}))
              .then((value) => setState(() => circlesRed = !circlesRed));
        },
        child: const Text('toggle circle color'),
      ),
      TextButton(
        onPressed: () {
          controller
              .setLayerProperties(
                  "symbols",
                  SymbolLayerProperties.fromJson(
                      {"visibility": symbolsVisible ? "none" : "visible"}))
              .then(
                  (value) => setState(() => symbolsVisible = !symbolsVisible));
        },
        child: const Text('toggle (non-moving) symbols visibility'),
      ),
    ]);
  }

  void _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;

    controller.onFeatureTapped.add(onFeatureTap);
  }

  void onFeatureTap(dynamic featureId, Point<double> point, LatLng latLng) {
    final snackBar = SnackBar(
      content: Text(
        'Tapped feature with id $featureId',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Theme.of(context).primaryColor,
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _onStyleLoadedCallback() async {
    await addImageFromAsset(
        controller, "custom-marker", "assets/symbols/custom-marker.png");
    await controller.addGeoJsonSource("points", _points);
    await controller.addGeoJsonSource("moving", _movingFeature(0));

    //new style of adding sources
    await controller.addSource("fills", GeojsonSourceProperties(data: _fills));

    await controller.addFillLayer(
      "fills",
      "fills",
      const FillLayerProperties(fillColor: [
        Expressions.interpolate,
        ['exponential', 0.5],
        [Expressions.zoom],
        11,
        'red',
        18,
        'green'
      ], fillOpacity: 0.4),
      filter: ['==', 'id', filteredId],
    );

    await controller.addLineLayer(
      "fills",
      "lines",
      LineLayerProperties(
          lineColor: Colors.lightBlue.toHexStringRGB(),
          lineWidth: [
            Expressions.interpolate,
            ["linear"],
            [Expressions.zoom],
            11.0,
            2.0,
            20.0,
            10.0
          ]),
    );

    await controller.addCircleLayer(
      "fills",
      "circles",
      CircleLayerProperties(
        circleRadius: 4,
        circleColor: Colors.blue.toHexStringRGB(),
      ),
    );

    await controller.addSymbolLayer(
      "points",
      "symbols",
      const SymbolLayerProperties(
        iconImage: "custom-marker", //  "{type}-15",
        iconSize: 2,
        iconAllowOverlap: true,
      ),
    );

    await controller.addSymbolLayer(
      "moving",
      "moving",
      SymbolLayerProperties(
        textField: [Expressions.get, "name"],
        textHaloWidth: 1,
        textSize: 10,
        textHaloColor: Colors.white.toHexStringRGB(),
        textOffset: [
          Expressions.literal,
          [0, 2]
        ],
        iconImage: "custom-marker",
        // "bicycle-15",
        iconSize: 2,
        iconAllowOverlap: true,
        textAllowOverlap: true,
      ),
      minzoom: 11,
    );

    bikeTimer = Timer.periodic(const Duration(milliseconds: 10), (t) {
      controller.setGeoJsonSource("moving", _movingFeature(t.tick / 2000));
    });

    filterTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      filteredId = filteredId == 0 ? 1 : 0;
      controller.setFilter('fills', ['==', 'id', filteredId]);
    });
  }

  @override
  void dispose() {
    bikeTimer?.cancel();
    filterTimer?.cancel();
    super.dispose();
  }
}

Map<String, dynamic> _movingFeature(double t) {
  List<double> makeLatLong(double t) {
    final angle = t * 2 * pi;
    const r = 0.025;
    const centerX = 151.1849;
    const centerY = -33.8748;
    return [
      centerX + r * sin(angle),
      centerY + r * cos(angle),
    ];
  }

  return {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "properties": {"name": "POGAČAR Tadej"},
        "id": 10,
        "geometry": {"type": "Point", "coordinates": makeLatLong(t)}
      },
      {
        "type": "Feature",
        "properties": {"name": "VAN AERT Wout"},
        "id": 11,
        "geometry": {"type": "Point", "coordinates": makeLatLong(t + 0.15)}
      },
    ]
  };
}

final _fills = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": 0, // web currently only supports number ids
      "properties": <String, dynamic>{'id': 0},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [151.178099204457737, -33.901517742631846],
            [151.179025547977773, -33.872845324482071],
            [151.147000529140399, -33.868230472039514],
            [151.150838238009328, -33.883172899638311],
            [151.14223647675135, -33.894158309528244],
            [151.155999294764086, -33.904812805307806],
            [151.178099204457737, -33.901517742631846]
          ],
          [
            [151.162657925954278, -33.879168932438581],
            [151.155323416087612, -33.890737666431583],
            [151.173659690754278, -33.897637567778119],
            [151.162657925954278, -33.879168932438581]
          ]
        ]
      }
    },
    {
      "type": "Feature",
      "id": 1,
      "properties": <String, dynamic>{'id': 1},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [151.18735077583878, -33.891143558434102],
            [151.197374605989864, -33.878357032551868],
            [151.213021560372084, -33.886475683791488],
            [151.204953599518745, -33.899463918807818],
            [151.18735077583878, -33.891143558434102]
          ]
        ]
      }
    }
  ]
};

const _points = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": 2,
      "properties": {
        "type": "restaurant",
      },
      "geometry": {
        "type": "Point",
        "coordinates": [151.184913929732943, -33.874874486427181]
      }
    },
    {
      "type": "Feature",
      "id": 3,
      "properties": {
        "type": "airport",
      },
      "geometry": {
        "type": "Point",
        "coordinates": [151.215730044667879, -33.874616048776858]
      }
    },
    {
      "type": "Feature",
      "id": 4,
      "properties": {
        "type": "bakery",
      },
      "geometry": {
        "type": "Point",
        "coordinates": [151.228803547973598, -33.892188026142584]
      }
    },
    {
      "type": "Feature",
      "id": 5,
      "properties": {
        "type": "college",
      },
      "geometry": {
        "type": "Point",
        "coordinates": [151.186470299174118, -33.902781145804774]
      }
    }
  ]
};
