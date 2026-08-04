import 'dart:io';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl_platform_interface/maplibre_gl_platform_interface.dart'
    show LatLngQuad;

/// Raw premultiplied RGBA8 pixels plus their size, the shape every engine
/// image command takes.
typedef RgbaImage = (Uint8List bytes, int width, int height);

/// Decodes an encoded image (PNG/JPEG/...) into raw premultiplied RGBA8
/// pixels.
///
/// Decoding on the Flutter side (rather than letting the engine core do it)
/// is deliberate: `dart:ui` covers the same formats as the platform codecs the
/// method-channel backends use, while the engine core rejects anything that is
/// not png/jpeg/webp.
Future<RgbaImage> decodeRgba(Uint8List encoded) async {
  final codec = await ui.instantiateImageCodec(encoded);
  try {
    final image = (await codec.getNextFrame()).image;
    final width = image.width;
    final height = image.height;
    // toByteData defaults to ImageByteFormat.rawRgba, which is premultiplied
    // per its contract (rawStraightRgba is the straight one).
    final data = await image.toByteData();
    image.dispose();
    if (data == null) {
      throw StateError('could not decode image pixels');
    }
    return (
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width,
      height,
    );
  } finally {
    codec.dispose();
  }
}

/// Reads image bytes for an image source: http(s) URLs from the network,
/// anything else from the Flutter asset bundle.
Future<Uint8List> fetchImageBytes(String url) async {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    final client = HttpClient();
    try {
      final uri = Uri.parse(url);
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return builder.takeBytes();
    } finally {
      client.close();
    }
  }
  final data = await rootBundle.load(url);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// Flattens an image source's four corners to the flat lat/lng pairs the
/// engine commands carry.
List<double> imageSourceCorners(LatLngQuad coordinates) => <double>[
  coordinates.topLeft.latitude,
  coordinates.topLeft.longitude,
  coordinates.topRight.latitude,
  coordinates.topRight.longitude,
  coordinates.bottomRight.latitude,
  coordinates.bottomRight.longitude,
  coordinates.bottomLeft.latitude,
  coordinates.bottomLeft.longitude,
];
