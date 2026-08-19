// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

/// Copies the offline database at [sourcePath] to [destinationPath], including
/// its SQLite `-wal`/`-shm` sidecars if present.
///
/// The offline store runs in WAL mode, so recent writes may still live in the
/// `-wal` sidecar rather than the main file; copying the sidecars alongside
/// keeps the exported database consistent instead of missing recent data.
///
/// Returns the destination path on success, or `null` if the source database
/// does not exist yet (nothing has been downloaded).
Future<String?> copyOfflineDatabase(
  String sourcePath,
  String destinationPath,
) async {
  final source = File(sourcePath);
  if (!source.existsSync()) return null;
  await source.copy(destinationPath);
  for (final suffix in const ['-wal', '-shm']) {
    final sidecar = File('$sourcePath$suffix');
    if (sidecar.existsSync()) {
      await sidecar.copy('$destinationPath$suffix');
    }
  }
  return destinationPath;
}
