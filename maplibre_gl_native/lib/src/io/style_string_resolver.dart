import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// Resolves the user-facing style string forms the engine does not
/// understand, mirroring the method-channel backends: raw JSON and http(s)
/// URLs pass through, absolute paths and `file://` URLs are read from disk,
/// and anything without a scheme is treated as a Flutter asset path and read
/// from the asset bundle. The resolved value is always raw JSON or an
/// http(s) URL, the only two forms `mln_map_set_style_*` accepts.
///
/// Must run on the root isolate: the asset bundle is not reachable from the
/// engine isolate.
Future<String> resolveStyleString(String styleString) async {
  final trimmed = styleString.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('{') ||
      trimmed.startsWith('http://') ||
      trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('file://')) {
    return File(Uri.parse(trimmed).toFilePath()).readAsString();
  }
  if (trimmed.startsWith('/')) {
    return File(trimmed).readAsString();
  }
  // Unknown schemes (e.g. mapbox://) pass through so the engine reports
  // them instead of a misleading asset-not-found error.
  if (trimmed.contains('://')) return trimmed;
  return rootBundle.loadString(trimmed);
}
