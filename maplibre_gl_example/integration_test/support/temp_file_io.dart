// Files for the tests that load data from the device. Android and iOS only:
// import it through temp_file.dart so the web build still compiles.
import 'dart:io';

/// Writes [contents] to a new file in a new temporary directory whose name
/// holds a space, and returns the path of the file.
Future<String> writeFileInDirectoryWithSpace(String contents) async {
  final directory = await Directory.systemTemp.createTemp('maplibre gl ');
  final file = File('${directory.path}/data.geojson');
  await file.writeAsString(contents);
  return file.path;
}
