// Files for the tests that load data from the device. Android and iOS only:
// import it through temp_file.dart so the web build still compiles.
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [contents] to a new file in a new temporary directory whose name
/// holds a space, and returns the path of the file.
Future<String> writeFileInDirectoryWithSpace(String contents) async {
  final temporary = await getTemporaryDirectory();
  final directory = await temporary.createTemp('maplibre gl ');
  final file = File('${directory.path}/data.geojson');
  await file.writeAsString(contents);
  return file.path;
}
