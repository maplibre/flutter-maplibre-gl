// Stub of temp_file_io.dart for platforms without dart:io (web), so test files
// that import it still compile there. Nothing here is meant to run: the tests
// that use it skip it on web.

/// Writes [contents] to a new file in a new temporary directory whose name
/// holds a space, and returns the path of the file.
Future<String> writeFileInDirectoryWithSpace(String contents) =>
    throw UnsupportedError('writeFileInDirectoryWithSpace needs dart:io.');
