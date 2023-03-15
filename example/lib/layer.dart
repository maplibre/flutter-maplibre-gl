import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';
import 'package:maplibre_gl_example/page.dart';

import 'util.dart';

class LayerPage extends ExamplePage {
  LayerPage() : super(const Icon(Icons.share), 'Layer');

  @override
  Widget build(BuildContext context) => LayerBody();
}

class LayerBody extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => LayerState();
}

class LayerState extends State {
  static final LatLng center = const LatLng(-33.86711, 151.1947171);

  late MaplibreMapController controller;
  Timer? bikeTimer;
  Timer? filterTimer;
  int filteredId = 0;

  @override
  Widget build(BuildContext context) {
    return MaplibreMap(
      dragEnabled: false,
      myLocationEnabled: true,
      onMapCreated: _onMapCreated,
      onMapClick: (point, latLong) =>
          print(point.toString() + latLong.toString()),
      onStyleLoadedCallback: _onStyleLoadedCallback,
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 11.0,
      ),
      annotationOrder: const [],
    );
  }

  void _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;

    controller.onFeatureTapped.add(onFeatureTap);
  }

  void onFeatureTap(dynamic featureId, Point<double> point, LatLng latLng) {
    final snackBar = SnackBar(
      content: Text(
        'Tapped feature with id $featureId',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      FillLayerProperties(fillColor: [
        Expressions.interpolate,
        ['exponential', 0.5],
        [Expressions.zoom],
        11,
        'red',
        18,
        'green'
      ], fillOpacity: 0.4),
      belowLayerId: "water",
      filter: ['==', 'id', filteredId],
    );

    await controller.addFillExtrusionLayer(
      "fills",
      "fills-extrusion",
      FillExtrusionLayerProperties(
        fillExtrusionHeight: 300,
        fillExtrusionColor: [
          Expressions.interpolate,
          ['exponential', 0.5],
          [Expressions.zoom],
          11,
          'red',
          18,
          'blue'
        ],
      ),
      belowLayerId: "water",
      filter: ['==', 'id', 2],
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
      SymbolLayerProperties(
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
        iconImage: "custom-marker", // "bicycle-15",
        iconSize: 2,
        iconAllowOverlap: true,
        textAllowOverlap: true,
      ),
      minzoom: 11,
    );

    bikeTimer = Timer.periodic(Duration(milliseconds: 10), (t) {
      controller.setGeoJsonSource("moving", _movingFeature(t.tick / 2000));
    });

    filterTimer = Timer.periodic(Duration(seconds: 3), (t) {
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
    const center_x = 151.1849;
    const center_y = -33.8748;
    return [
      center_x + r * sin(angle),
      center_y + r * cos(angle),
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
      "id": 2,
      "properties": <String, dynamic>{'id': 2},
      "geometry": {
        "type": "Polygon",
        "coordinates": [
          [
            [
              151.121824791363,
              -33.885947459842846
            ],
            [
              151.121824791363,
              -33.89768020458625
            ],
            [
              151.13561641336742,
              -33.89768020458625
            ],
            [
              151.13561641336742,
              -33.885947459842846
            ],
            [
              151.121824791363,
              -33.885947459842846
            ]
          ]
        ],
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
