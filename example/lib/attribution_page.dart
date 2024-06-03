import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:maplibre_gl_example/main.dart';
import 'package:maplibre_gl_example/common/example_scaffold.dart';

class AttributionPage extends StatefulWidget {
  const AttributionPage({super.key});

  @override
  State<AttributionPage> createState() => _AttributionPageState();
}

class _AttributionPageState extends State<AttributionPage> {
  AttributionButtonPosition? attributionButtonPosition;
  bool useDefaultAttributionPosition = true;

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      page: ExamplePage.attribution,
      body: Column(
        children: [
          const Text("Set attribution position"),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                buildDefaultPositionButton(),
                buildPositionButton(null),
                buildPositionButton(AttributionButtonPosition.topRight),
                buildPositionButton(AttributionButtonPosition.topLeft),
                buildPositionButton(AttributionButtonPosition.bottomRight),
                buildPositionButton(AttributionButtonPosition.bottomLeft),
              ],
            ),
          ),
          Expanded(
            child: buildMap(
              attributionButtonPosition,
              useDefaultAttributionPosition,
            ),
          ),
        ],
      ),
    );
  }

  ElevatedButton buildDefaultPositionButton() {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          attributionButtonPosition = null;
          useDefaultAttributionPosition = true;
        });
      },
      child: const Text("Default"),
    );
  }

  ElevatedButton buildPositionButton(AttributionButtonPosition? position) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          attributionButtonPosition = position;
          useDefaultAttributionPosition = false;
        });
      },
      child: Text(position?.name ?? "Null (=platform default)"),
    );
  }

  MaplibreMap buildMap(
    AttributionButtonPosition? attributionButtonPosition,
    bool useDefaultAttributionPosition,
  ) {
    if (useDefaultAttributionPosition) {
      return MaplibreMap(
        key: UniqueKey(),
        initialCameraPosition: const CameraPosition(
          target: LatLng(-33.852, 151.211),
          zoom: 11.0,
        ),
        styleString: "assets/osm_style.json",
      );
    } else {
      return MaplibreMap(
        key: UniqueKey(),
        initialCameraPosition: const CameraPosition(
          target: LatLng(-33.852, 151.211),
          zoom: 11.0,
        ),
        styleString: "assets/osm_style.json",
        attributionButtonPosition: attributionButtonPosition,
      );
    }
  }
}
