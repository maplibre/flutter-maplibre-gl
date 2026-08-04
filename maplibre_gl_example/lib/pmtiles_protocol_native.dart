/// Stub for Android and iOS, where MapLibre Native handles the `pmtiles://`
/// protocol itself and no registration is needed.
/// The web implementation is in [pmtiles_protocol_web.dart].
void registerPmTilesProtocol(String archiveUrl) {
  // No-op on native platforms.
}
