import 'package:flutter/material.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class AttributionPage extends ExamplePage {
  const AttributionPage({super.key})
      : super(const Icon(Icons.thumb_up), 'Attribution');

  @override
  Widget build(BuildContext context) {
    return const AttributionBody();
  }
}

class AttributionBody extends StatefulWidget {
  const AttributionBody({super.key});

  @override
  State<AttributionBody> createState() => _AttributionBodyState();
}

class _AttributionBodyState extends State<AttributionBody> {
  AttributionButtonPosition? attributionButtonPosition;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Set attribution position"),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  attributionButtonPosition =
                      AttributionButtonPosition.TopRight;
                });
              },
              child: const Text('TopRight'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  attributionButtonPosition = AttributionButtonPosition.TopLeft;
                });
              },
              child: const Text('TopLeft'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  attributionButtonPosition =
                      AttributionButtonPosition.BottomRight;
                });
              },
              child: const Text('BottomRight'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  attributionButtonPosition =
                      AttributionButtonPosition.BottomLeft;
                });
              },
              child: const Text('BottomLeft'),
            ),
          ],
        ),
        Expanded(
          child: MaplibreMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(-33.852, 151.211),
              zoom: 11.0,
            ),
            styleString: "/assets/assets/osm_style.json",
            attributionButtonPosition: attributionButtonPosition,
          ),
        ),
      ],
    );
  }
}
