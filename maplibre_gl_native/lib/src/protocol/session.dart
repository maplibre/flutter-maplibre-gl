/// Session lifecycle: creating, resizing and tearing down the render
/// session behind one map.
///
/// Part of the protocol library; see protocol.dart for the sendability rule.
part of 'protocol.dart';

/// Render backend of a session's native surface. Must match the backend the
/// bundled MapLibre Native library was compiled with.
enum SessionBackend { opengl, vulkan }

/// Creates a map plus its render session over an existing native surface.
/// Replies with the engine-assigned session id.
///
/// One subtype per render backend: the context handles a backend needs are
/// non-null by construction, so the engine reads them without asserting that
/// the right constructor was used.
sealed class CreateSessionQuery extends EngineQuery<int> {
  const CreateSessionQuery({
    required this.textureId,
    required this.surface,
    required this.logicalWidth,
    required this.logicalHeight,
    required this.scaleFactor,
  });

  final int textureId;

  /// Backend surface handle: an EGLSurface or a VkSurfaceKHR.
  final int surface;

  final int logicalWidth;
  final int logicalHeight;
  final double scaleFactor;
}

/// Session over an EGL window surface (OpenGL build of the native library).
final class OpenGlSessionQuery extends CreateSessionQuery {
  const OpenGlSessionQuery({
    required super.textureId,
    required super.surface,
    required this.eglDisplay,
    required this.eglConfig,
    required this.eglContext,
    required super.logicalWidth,
    required super.logicalHeight,
    required super.scaleFactor,
  });

  final int eglDisplay;
  final int eglConfig;

  /// EGLContext whose share group the render session joins.
  final int eglContext;
}

/// Session over a VkSurfaceKHR (Vulkan build of the native library).
final class VulkanSessionQuery extends CreateSessionQuery {
  const VulkanSessionQuery({
    required super.textureId,
    required super.surface,
    required this.vkInstance,
    required this.vkPhysicalDevice,
    required this.vkDevice,
    required this.vkQueue,
    required this.vkQueueFamilyIndex,
    required this.vkGetInstanceProcAddr,
    required this.vkGetDeviceProcAddr,
    required super.logicalWidth,
    required super.logicalHeight,
    required super.scaleFactor,
  });

  final int vkInstance;
  final int vkPhysicalDevice;
  final int vkDevice;
  final int vkQueue;

  /// Queue family index of [vkQueue].
  final int vkQueueFamilyIndex;
  final int vkGetInstanceProcAddr;
  final int vkGetDeviceProcAddr;
}

/// The platform destroyed the producer surface; detach the render target.
class SurfaceLostCommand extends SessionCommand {
  const SurfaceLostCommand(super.sessionId);
}

/// Re-attaches the render target to a freshly recreated EGL surface.
class AttachSurfaceCommand extends SessionCommand {
  const AttachSurfaceCommand(super.sessionId, {required this.eglSurface});

  final int eglSurface;
}

/// Resizes the render target; the EGL surface was recreated by the platform.
class ResizeSessionCommand extends SessionCommand {
  const ResizeSessionCommand(
    super.sessionId, {
    required this.logicalWidth,
    required this.logicalHeight,
    required this.scaleFactor,
    required this.eglSurface,
  });

  final int logicalWidth;
  final int logicalHeight;
  final double scaleFactor;
  final int eglSurface;
}

/// Tears down the render session and the map.
class DisposeSessionCommand extends SessionCommand {
  const DisposeSessionCommand(super.sessionId);
}

/// Marks the session dirty so the next tick renders a frame.
class RequestRenderCommand extends SessionCommand {
  const RequestRenderCommand(super.sessionId);
}
