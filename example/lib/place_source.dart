// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

import 'page.dart';

class PlaceSourcePage extends ExamplePage {
  const PlaceSourcePage({super.key})
      : super(const Icon(Icons.place), 'Place source');

  @override
  Widget build(BuildContext context) {
    return const PlaceSymbolBody();
  }
}

class PlaceSymbolBody extends StatefulWidget {
  const PlaceSymbolBody({super.key});

  @override
  State<StatefulWidget> createState() => PlaceSymbolBodyState();
}

class PlaceSymbolBodyState extends State<PlaceSymbolBody> {
  PlaceSymbolBodyState();

  static const sourceId = 'sydney_source';
  static const layerId = 'sydney_layer';

  bool sourceAdded = false;
  bool layerAdded = false;
  bool imageFlag = false;
  late MaplibreMapController controller;

  void _onMapCreated(MaplibreMapController controller) {
    this.controller = controller;
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Adds an asset image as a source to the currently displayed style
  Future<void> addImageSourceFromAsset(
      String imageSourceId, String assetName) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return controller.addImageSource(
      imageSourceId,
      list,
      const LatLngQuad(
        bottomRight: LatLng(-33.86264728692581, 151.19916915893555),
        bottomLeft: LatLng(-33.86264728692581, 151.2288236618042),
        topLeft: LatLng(-33.84322353475214, 151.2288236618042),
        topRight: LatLng(-33.84322353475214, 151.19916915893555),
      ),
    );
  }

  Future<void> removeImageSource(String imageSourceId) {
    return controller.removeSource(imageSourceId);
  }

  Future<void> addLayer(String imageLayerId, String imageSourceId) {
    if (layerAdded) {
      removeLayer(imageLayerId);
    }
    setState(() => layerAdded = true);
    return controller.addImageLayer(imageLayerId, imageSourceId);
  }

  Future<void> addLayerBelow(
      String imageLayerId, String imageSourceId, String belowLayerId) {
    if (layerAdded) {
      removeLayer(imageLayerId);
    }
    setState(() => layerAdded = true);
    return controller.addImageLayerBelow(
        imageLayerId, imageSourceId, belowLayerId);
  }

  Future<void> removeLayer(String imageLayerId) {
    setState(() => layerAdded = false);
    return controller.removeLayer(imageLayerId);
  }

  Future<void> updateImageSourceFromAsset(
      String imageSourceId, String assetName) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return controller.updateImageSource(imageSourceId, list, null);
  }

  String pickImage() {
    return imageFlag ? 'assets/sydney0.png' : 'assets/sydney1.png';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: SizedBox(
            width: 300.0,
            height: 200.0,
            child: MaplibreMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: LatLng(-33.852, 151.211),
                zoom: 11.0,
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    TextButton(
                      onPressed: sourceAdded
                          ? null
                          : () {
                              addImageSourceFromAsset(sourceId, pickImage())
                                  .then((value) {
                                setState(() => sourceAdded = true);
                              });
                            },
                      child: const Text('Add source (asset image)'),
                    ),
                    TextButton(
                      onPressed: sourceAdded
                          ? () async {
                              await removeLayer(layerId);
                              removeImageSource(sourceId).then((value) {
                                setState(() => sourceAdded = false);
                              });
                            }
                          : null,
                      child: const Text('Remove source (asset image)'),
                    ),
                    TextButton(
                      onPressed: sourceAdded
                          ? () => addLayer(layerId, sourceId)
                          : null,
                      child: const Text('Show layer'),
                    ),
                    TextButton(
                      onPressed: sourceAdded
                          ? () => addLayerBelow(layerId, sourceId, 'water')
                          : null,
                      child: const Text('Show layer below water'),
                    ),
                    TextButton(
                      onPressed:
                          sourceAdded ? () => removeLayer(layerId) : null,
                      child: const Text('Hide layer'),
                    ),
                    TextButton(
                      onPressed: sourceAdded
                          ? () async {
                              setState(() => imageFlag = !imageFlag);
                              updateImageSourceFromAsset(sourceId, pickImage());
                            }
                          : null,
                      child: const Text('Change image'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
