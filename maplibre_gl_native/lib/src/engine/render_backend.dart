import 'package:maplibre_native_ffi/maplibre_native_ffi.dart' as mln;

/// Render backend the bundled native library was compiled with.
///
/// Part of the engine layer's presentation-facing surface: the map view must
/// know which kind of native surface to prepare (EGLSurface or VkSurfaceKHR)
/// BEFORE a session exists, so this cannot be an engine query.
abstract final class RenderBackendSupport {
  /// Whether the bundled native library supports the Vulkan render backend.
  static bool get vulkan => mln.Maplibre.supportedRenderBackends().contains(
    mln.RenderBackendMask.vulkan,
  );
}
