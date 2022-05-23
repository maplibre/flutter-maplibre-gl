import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:maplibre_gl/mapbox_gl.dart';

/// Adds an asset image to the currently displayed style
Future<void> addImageFromAsset(
    MaplibreMapController controller, String name, String assetName) async {
  final ByteData bytes = await rootBundle.load(assetName);
  final Uint8List list = bytes.buffer.asUint8List();
  return controller.addImage(name, list);
}
