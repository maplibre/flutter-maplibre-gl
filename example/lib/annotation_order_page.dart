import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';
import 'package:maplibre_gl_example/main.dart';

import 'common/util.dart';

class AnnotationOrderPage extends StatefulWidget {
  const AnnotationOrderPage({super.key});

  @override
  State<AnnotationOrderPage> createState() => _AnnotationOrderPageState();
}

class _AnnotationOrderPageState extends State<AnnotationOrderPage> {
  late MaplibreMapController controllerOne;
  late MaplibreMapController controllerTwo;

  final LatLng center = const LatLng(36.580664, 32.5563837);

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.annotationOrder,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 0.0),
              child: Column(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                        'This map has polygons (fill) above all other annotations (default behavior)'),
                  ),
                  Flexible(
                    child: MaplibreMap(
                      onMapCreated: onMapCreatedOne,
                      onStyleLoadedCallback: () => onStyleLoaded(controllerOne),
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: 5.0,
                      ),
                      annotationOrder: const [
                        AnnotationType.line,
                        AnnotationType.symbol,
                        AnnotationType.circle,
                        AnnotationType.fill,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 0.0),
              child: Column(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5.0, top: 5.0),
                    child: Text(
                        'This map has polygones (fill) under all other anotations'),
                  ),
                  Flexible(
                    child: MaplibreMap(
                      onMapCreated: onMapCreatedTwo,
                      onStyleLoadedCallback: () => onStyleLoaded(controllerTwo),
                      initialCameraPosition: CameraPosition(
                        target: center,
                        zoom: 5.0,
                      ),
                      annotationOrder: const [
                        AnnotationType.fill,
                        AnnotationType.line,
                        AnnotationType.symbol,
                        AnnotationType.circle,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onMapCreatedOne(MaplibreMapController controller) {
    controllerOne = controller;
  }

  void onMapCreatedTwo(MaplibreMapController controller) {
    controllerTwo = controller;
  }

  void onStyleLoaded(MaplibreMapController controller) async {
    await addImageFromAsset(
        controller, "custom-marker", "assets/symbols/custom-marker.png");
    controller.addSymbol(
      SymbolOptions(
        geometry: LatLng(
          center.latitude,
          center.longitude,
        ),
        iconImage: "custom-marker", // "airport-15",
      ),
    );
    controller.addLine(
      const LineOptions(
        draggable: false,
        lineColor: "#ff0000",
        lineWidth: 7.0,
        lineOpacity: 1,
        geometry: [
          LatLng(35.3649902, 32.0593003),
          LatLng(34.9475098, 31.1187944),
          LatLng(36.7108154, 30.7040582),
          LatLng(37.6995850, 33.6512083),
          LatLng(35.8648682, 33.6969227),
          LatLng(35.3814697, 32.0546447),
        ],
      ),
    );
    controller.addFill(
      const FillOptions(
        draggable: false,
        fillColor: "#008888",
        fillOpacity: 0.3,
        geometry: [
          [
            LatLng(35.3649902, 32.0593003),
            LatLng(34.9475098, 31.1187944),
            LatLng(36.7108154, 30.7040582),
            LatLng(37.6995850, 33.6512083),
            LatLng(35.8648682, 33.6969227),
            LatLng(35.3814697, 32.0546447),
          ]
        ],
      ),
    );
  }
}
