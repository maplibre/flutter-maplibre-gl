// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Web stub: offline storage does not exist on web, so exporting is
/// unsupported. Kept so the conditional import resolves on all platforms.
Future<String?> copyOfflineDatabase(
  String sourcePath,
  String destinationPath,
) {
  throw UnsupportedError('Offline database export is not available on web.');
}
