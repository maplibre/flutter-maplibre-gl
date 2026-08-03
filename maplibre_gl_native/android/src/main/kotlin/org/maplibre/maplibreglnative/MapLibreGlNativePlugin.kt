package org.maplibre.maplibreglnative

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.os.Build
import android.os.Looper
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Texture shim for the FFI-backed maplibre_gl backend.
 *
 * This plugin is intentionally tiny: it registers external textures with the
 * Flutter engine, wraps their producer surfaces in a render-target surface of
 * the requested backend (EGL window surface for OpenGL builds, VkSurfaceKHR
 * for Vulkan builds of the MapLibre Native library), and hands the raw
 * handles to Dart, where the MapLibre Native C API attaches a surface render
 * session via dart:ffi. It also performs the JNI-only calls of the C API
 * (mln_android_init) and the Vulkan bootstrap (no Java API exists for
 * Vulkan; see shim.c).
 */
class MapLibreGlNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var textureRegistry: TextureRegistry? = null
  private var applicationContext: Context? = null
  private val entries = mutableMapOf<Long, MapTextureEntry>()
  private var nativeInitialized = false

  /**
   * Process-wide Vulkan context created by the shim on first use:
   * [instance, physicalDevice, device, queue, queueFamilyIndex,
   * getInstanceProcAddr, getDeviceProcAddr].
   */
  private var vulkanContext: LongArray? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "maplibre_gl_native")
    channel.setMethodCallHandler(this)
    textureRegistry = binding.textureRegistry
    applicationContext = binding.applicationContext
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    stopLocationUpdates()
    // The shim's render thread may be inside render_update on one of these
    // surfaces: its mutex serializes it against Dart borrows, not against
    // this (platform) thread. Retiring the bound session waits out the frame
    // in flight, so nothing is drawing when the entries destroy their
    // surfaces below.
    if (nativeInitialized) nativeRetireRenderSession()
    entries.values.forEach { it.close() }
    entries.clear()
    textureRegistry = null
    applicationContext = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        "init" -> {
          if (!nativeInitialized) {
            // A missing .so throws UnsatisfiedLinkError, which is an Error,
            // not a RuntimeException: without this catch it would sail past
            // the handler below and crash the app on the platform thread
            // instead of surfacing as a diagnosable result.error on the Dart
            // side. LinkageError also covers the symbol-level variant, where
            // the library loads but a Java_..._native* symbol fails to bind
            // at the nativeAndroidInit call (e.g. R8 renamed the plugin
            // class; see consumer-proguard-rules.pro).
            try {
              // Loading the shim also loads libmaplibre-native-c.so, so the
              // subsequent DynamicLibrary.open on the Dart side binds the
              // already-loaded library.
              System.loadLibrary("maplibre_gl_native_shim")
              val status = nativeAndroidInit(requireNotNull(applicationContext))
              check(status == 0) { "mln_android_init failed with status $status" }
            } catch (error: LinkageError) {
              result.error(
                "maplibre_gl_native",
                "failed to load the native libraries " +
                  "(libmaplibre_gl_native_shim.so / libmaplibre-native-c.so): " +
                  "${error.message}. They are built for arm64-v8a only; check " +
                  "that the APK or App Bundle split installed on this device " +
                  "contains that ABI, and that R8 kept the plugin class name " +
                  "(consumer-proguard-rules.pro).",
                null,
              )
              return
            }
            nativeInitialized = true
          }
          result.success(null)
        }
        "getCacheDir" -> {
          result.success(requireNotNull(applicationContext).cacheDir.absolutePath)
        }
        "openUri" -> {
          // Opens attribution links in the system browser (the ornaments are
          // Flutter widgets, so there is no platform view to delegate to).
          val uri = requireNotNull(call.argument<String>("uri"))
          try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            requireNotNull(applicationContext).startActivity(intent)
            result.success(true)
          } catch (error: Exception) {
            result.success(false)
          }
        }
        "startLocationUpdates" -> {
          startLocationUpdates(result)
        }
        "stopLocationUpdates" -> {
          stopLocationUpdates()
          result.success(null)
        }
        "createTexture" -> {
          val width = requireNotNull(call.argument<Int>("physicalWidth"))
          val height = requireNotNull(call.argument<Int>("physicalHeight"))
          requireSaneTextureSize(width, height)
          val backend = call.argument<String>("backend") ?: "opengl"
          val entry = createTexture(width, height, backend)
          entries[entry.textureId] = entry
          result.success(entry.toHandleMap())
        }
        "resizeTexture" -> {
          val entry = entryFor(call)
          val width = requireNotNull(call.argument<Int>("physicalWidth"))
          val height = requireNotNull(call.argument<Int>("physicalHeight"))
          requireSaneTextureSize(width, height)
          entry.resize(width, height)
          result.success(mapOf("surface" to entry.surfaceHandle))
        }
        "recreateSurface" -> {
          val entry = entryFor(call)
          entry.recreateSurface()
          result.success(mapOf("surface" to entry.surfaceHandle))
        }
        "releaseRetiredSurface" -> {
          entryFor(call).releaseRetiredSurface()
          result.success(null)
        }
        "disposeTexture" -> {
          val textureId = requireNotNull(call.argument<Number>("textureId")).toLong()
          entries.remove(textureId)?.close()
          result.success(null)
        }
        else -> result.notImplemented()
      }
    } catch (error: RuntimeException) {
      result.error("maplibre_gl_native", error.message, null)
    }
  }

  private fun entryFor(call: MethodCall): MapTextureEntry {
    val textureId = requireNotNull(call.argument<Number>("textureId")).toLong()
    return requireNotNull(entries[textureId]) { "unknown texture $textureId" }
  }

  /**
   * Rejects sizes the producer would accept but the GPU never could: a zero
   * or negative dimension crashes deep inside the swapchain, and anything
   * past the ceiling (conservatively GL_MAX_TEXTURE_SIZE / Vulkan
   * maxImageDimension2D on current devices) signals a corrupted layout, not
   * a real map. The throw becomes a result.error through the catch in
   * [onMethodCall].
   */
  private fun requireSaneTextureSize(width: Int, height: Int) {
    require(width in 1..MAX_TEXTURE_DIMENSION && height in 1..MAX_TEXTURE_DIMENSION) {
      "invalid texture size ${width}x${height}"
    }
  }

  private companion object {
    private const val MAX_TEXTURE_DIMENSION = 16384
  }

  private var locationManager: LocationManager? = null
  private var locationListener: LocationListener? = null

  /**
   * Streams platform location fixes to Dart ("onLocationUpdate" callbacks).
   * Only CHECKS the permission; requesting it is the app's responsibility
   * (matching the main plugin's contract for myLocationEnabled).
   */
  private fun startLocationUpdates(result: MethodChannel.Result) {
    val context = requireNotNull(applicationContext)
    val fineGranted =
      Build.VERSION.SDK_INT < 23 ||
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
          PackageManager.PERMISSION_GRANTED
    val coarseGranted =
      Build.VERSION.SDK_INT < 23 ||
        context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
          PackageManager.PERMISSION_GRANTED
    if (!fineGranted && !coarseGranted) {
      result.error(
        "location_permission",
        "location permission not granted; request it before enabling the location component",
        null,
      )
      return
    }
    if (locationListener != null) {
      result.success(null)
      return
    }
    val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    // Listen to every usable provider: indoors, GPS alone may never deliver
    // a first fix while the network provider answers within seconds.
    val providers = mutableListOf<String>()
    if (fineGranted && manager.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
      providers.add(LocationManager.GPS_PROVIDER)
    }
    if (manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
      providers.add(LocationManager.NETWORK_PROVIDER)
    }
    if (providers.isEmpty()) {
      providers.add(LocationManager.PASSIVE_PROVIDER)
    }
    val listener = LocationListener { location -> emitLocation(location) }
    try {
      for (provider in providers) {
        manager.requestLocationUpdates(provider, 1000L, 0f, listener, Looper.getMainLooper())
      }
      // Seed with the freshest cached fix across providers so the puck can
      // appear immediately instead of waiting for the first live fix.
      providers
        .mapNotNull { manager.getLastKnownLocation(it) }
        .maxByOrNull { it.time }
        ?.let { emitLocation(it) }
    } catch (error: SecurityException) {
      manager.removeUpdates(listener)
      result.error("location_permission", error.message, null)
      return
    }
    locationManager = manager
    locationListener = listener
    result.success(null)
  }

  private fun stopLocationUpdates() {
    locationListener?.let { locationManager?.removeUpdates(it) }
    locationListener = null
    locationManager = null
  }

  private fun emitLocation(location: Location) {
    channel.invokeMethod(
      "onLocationUpdate",
      mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "altitude" to if (location.hasAltitude()) location.altitude else null,
        "bearing" to if (location.hasBearing()) location.bearing.toDouble() else null,
        "speed" to if (location.hasSpeed()) location.speed.toDouble() else null,
        "horizontalAccuracy" to
          if (location.hasAccuracy()) location.accuracy.toDouble() else null,
        "verticalAccuracy" to
          if (Build.VERSION.SDK_INT >= 26 && location.hasVerticalAccuracy()) {
            location.verticalAccuracyMeters.toDouble()
          } else {
            null
          },
        "timestamp" to location.time,
      ),
    )
  }

  private fun createTexture(width: Int, height: Int, backend: String): MapTextureEntry {
    val producer = requireNotNull(textureRegistry).createSurfaceProducer()
    // Everything past this point can fail (Vulkan bootstrap, the EGL checks).
    // A failed entry never reaches `entries`, so nothing would ever release
    // the producer: without the catch the orphaned registration would sit in
    // the TextureRegistry for the rest of the engine's life.
    var entry: MapTextureEntry? = null
    try {
      producer.setSize(width, height)
      entry =
        when (backend) {
          "vulkan" -> {
            val context =
              vulkanContext
                ?: requireNotNull(nativeVulkanInit()) { "Vulkan bootstrap failed" }
                  .also { vulkanContext = it }
            VulkanTextureEntry(
              producer = producer,
              context = context,
              createSurface = { surface ->
                requireNotNull(nativeVulkanCreateSurface(surface)) {
                  "creating VkSurfaceKHR failed"
                }
              },
              destroySurface = { vkSurface, window ->
                nativeVulkanDestroySurface(vkSurface, window)
              },
            )
          }
          else -> EglTextureEntry(producer)
        }
      producer.setCallback(
        object : TextureRegistry.SurfaceProducer.Callback {
          override fun onSurfaceAvailable() {
            channel.invokeMethod("onSurfaceAvailable", mapOf("textureId" to producer.id()))
          }

          override fun onSurfaceCleanup() {
            // Flutter destroys the producer surface as soon as this callback
            // returns, and the shim's render thread may be mid-frame on it:
            // retire the bound session first, which waits out the frame in
            // flight. The retirement is unconditional (this side knows
            // textures, not sessions), so with two maps it also pulls the
            // other map's binding; acceptable, because Dart re-offers a live
            // session while processing the surface loss below.
            if (nativeInitialized) nativeRetireRenderSession()
            // Dart detaches the render session before touching the surface
            // again; the backend surface is recreated on demand.
            channel.invokeMethod("onSurfaceDestroyed", mapOf("textureId" to producer.id()))
          }
        }
      )
      return entry
    } catch (error: Throwable) {
      // close() tears down the entry's own EGL/Vulkan handles and releases
      // the producer; before the entry exists the producer is all there is.
      entry?.close() ?: producer.release()
      throw error
    }
  }

  private external fun nativeAndroidInit(context: Context): Int

  private external fun nativeVulkanInit(): LongArray?

  private external fun nativeVulkanCreateSurface(surface: Surface): LongArray?

  private external fun nativeVulkanDestroySurface(vkSurface: Long, window: Long)

  /**
   * Withdraws whatever render session the shim's display thread is bound to,
   * waiting out the frame in flight (see shim.c). The barrier this class must
   * cross before destroying any backend surface: the shim's render mutex
   * serializes its thread against Dart, not against the platform thread.
   */
  private external fun nativeRetireRenderSession()
}

/** One external texture and the backend surface wrapped over its producer. */
private interface MapTextureEntry : AutoCloseable {
  val textureId: Long

  /** Backend surface handle (EGLSurface or VkSurfaceKHR). */
  val surfaceHandle: Long

  fun toHandleMap(): Map<String, Any>

  fun resize(width: Int, height: Int)

  fun recreateSurface()

  /**
   * Destroys the surface retired by the last resize()/recreateSurface(), once
   * the engine has swapped the render session onto the new one. The session
   * presents to the outgoing surface until that swap (and Vulkan additionally
   * requires every swapchain destroyed before its surface), so destruction
   * must wait for it: both backends park the outgoing surface in resize()/
   * recreateSurface() and destroy it here. The default is a no-op only for
   * a hypothetical backend that carries nothing to defer.
   */
  fun releaseRetiredSurface() {}
}

/**
 * Vulkan variant: the shim creates a VkSurfaceKHR over the producer surface;
 * instance/device/queue are process-wide and shared across entries.
 */
private class VulkanTextureEntry(
  val producer: TextureRegistry.SurfaceProducer,
  private val context: LongArray,
  private val createSurface: (Surface) -> LongArray,
  private val destroySurface: (Long, Long) -> Unit,
) : MapTextureEntry {
  private var vkSurface: Long = 0
  private var window: Long = 0
  private var retiredVkSurface: Long = 0
  private var retiredWindow: Long = 0

  init {
    create(producer.surface)
  }

  override val textureId: Long
    get() = producer.id()

  override val surfaceHandle: Long
    get() = vkSurface

  override fun toHandleMap(): Map<String, Any> =
    mapOf(
      "backend" to "vulkan",
      "textureId" to textureId,
      "vkInstance" to context[0],
      "vkPhysicalDevice" to context[1],
      "vkDevice" to context[2],
      "vkQueue" to context[3],
      "vkQueueFamilyIndex" to context[4],
      "vkGetInstanceProcAddr" to context[5],
      "vkGetDeviceProcAddr" to context[6],
      "surface" to vkSurface,
    )

  override fun resize(width: Int, height: Int) {
    retire()
    producer.setSize(width, height)
    create(producer.surface)
  }

  override fun recreateSurface() {
    retire()
    create(producer.surface)
  }

  override fun releaseRetiredSurface() {
    if (retiredVkSurface != 0L || retiredWindow != 0L) {
      destroySurface(retiredVkSurface, retiredWindow)
      retiredVkSurface = 0
      retiredWindow = 0
    }
  }

  private fun create(surface: Surface) {
    val handles = createSurface(surface)
    vkSurface = handles[0]
    window = handles[1]
  }

  /**
   * Parks the current pair for releaseRetiredSurface() instead of destroying
   * it: the render session still holds a swapchain built from this
   * VkSurfaceKHR until the engine swaps targets. A pair already parked (two
   * swaps with no release between them) is destroyed first; by then the
   * session has long since stopped presenting to it.
   */
  private fun retire() {
    releaseRetiredSurface()
    retiredVkSurface = vkSurface
    retiredWindow = window
    vkSurface = 0
    window = 0
  }

  override fun close() {
    releaseRetiredSurface()
    if (vkSurface != 0L || window != 0L) {
      destroySurface(vkSurface, window)
      vkSurface = 0
      window = 0
    }
    producer.release()
  }
}

/**
 * OpenGL variant: an EGL display/config/context plus the EGL window surface
 * created over the producer's Surface. All handles are borrowed by the
 * MapLibre Native render session on the Dart side.
 */
private class EglTextureEntry(val producer: TextureRegistry.SurfaceProducer) : MapTextureEntry {
  private val display: EGLDisplay
  private val config: EGLConfig
  private val context: EGLContext
  private var windowSurface: EGLSurface = EGL14.EGL_NO_SURFACE
  private var retiredSurface: EGLSurface = EGL14.EGL_NO_SURFACE

  init {
    display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
    check(display != EGL14.EGL_NO_DISPLAY) { "EGL display is unavailable" }
    val version = IntArray(2)
    eglCheck(EGL14.eglInitialize(display, version, 0, version, 1), "initialize EGL")
    eglCheck(EGL14.eglBindAPI(EGL14.EGL_OPENGL_ES_API), "bind OpenGL ES EGL API")
    config = chooseConfig(display)
    val contextAttributes = intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 3, EGL14.EGL_NONE)
    context = EGL14.eglCreateContext(display, config, EGL14.EGL_NO_CONTEXT, contextAttributes, 0)
    check(context != EGL14.EGL_NO_CONTEXT) { "creating EGL share context failed" }
    try {
      createWindowSurface(producer.surface)
    } catch (error: Throwable) {
      // A failed construction means close() never runs, so the context must
      // be destroyed here or it leaks. The display is the process-shared
      // default (eglInitialize is refcounted) and the config is not a
      // resource, so the context is the only handle this init owns so far.
      EGL14.eglDestroyContext(display, context)
      throw error
    }
  }

  override val textureId: Long
    get() = producer.id()

  override val surfaceHandle: Long
    get() = windowSurface.nativeHandle

  override fun toHandleMap(): Map<String, Any> =
    mapOf(
      "backend" to "opengl",
      "textureId" to textureId,
      "eglDisplay" to display.nativeHandle,
      "eglConfig" to config.nativeHandle,
      "eglContext" to context.nativeHandle,
      "surface" to surfaceHandle,
    )

  override fun resize(width: Int, height: Int) {
    retire()
    producer.setSize(width, height)
    createWindowSurface(producer.surface)
  }

  override fun recreateSurface() {
    retire()
    createWindowSurface(producer.surface)
  }

  override fun releaseRetiredSurface() {
    if (retiredSurface != EGL14.EGL_NO_SURFACE) {
      EGL14.eglDestroySurface(display, retiredSurface)
      retiredSurface = EGL14.EGL_NO_SURFACE
    }
  }

  /**
   * Parks the current surface for releaseRetiredSurface() instead of
   * destroying it, mirroring [VulkanTextureEntry.retire]: the Dart side calls
   * releaseRetiredSurface only after the engine has swapped the render
   * session onto the new surface, and until that swap the session still
   * presents to the outgoing one, so destroying it here would pull it out
   * from under a frame in flight. A surface already parked (two swaps with
   * no release between them) is destroyed first; by then the session has
   * long since stopped presenting to it.
   */
  private fun retire() {
    releaseRetiredSurface()
    retiredSurface = windowSurface
    windowSurface = EGL14.EGL_NO_SURFACE
  }

  private fun createWindowSurface(surface: Surface) {
    val attributes = intArrayOf(EGL14.EGL_NONE)
    windowSurface = EGL14.eglCreateWindowSurface(display, config, surface, attributes, 0)
    check(windowSurface != EGL14.EGL_NO_SURFACE) { "creating EGL window surface failed" }
  }

  private fun destroyWindowSurface() {
    if (windowSurface != EGL14.EGL_NO_SURFACE) {
      EGL14.eglDestroySurface(display, windowSurface)
      windowSurface = EGL14.EGL_NO_SURFACE
    }
  }

  override fun close() {
    releaseRetiredSurface()
    destroyWindowSurface()
    if (context != EGL14.EGL_NO_CONTEXT) {
      EGL14.eglDestroyContext(display, context)
    }
    producer.release()
  }

  private companion object {
    private const val EGL_OPENGL_ES3_BIT = 0x00000040

    private fun chooseConfig(display: EGLDisplay): EGLConfig {
      val attributes =
        intArrayOf(
          EGL14.EGL_RENDERABLE_TYPE,
          EGL_OPENGL_ES3_BIT,
          EGL14.EGL_SURFACE_TYPE,
          EGL14.EGL_WINDOW_BIT,
          EGL14.EGL_RED_SIZE,
          8,
          EGL14.EGL_GREEN_SIZE,
          8,
          EGL14.EGL_BLUE_SIZE,
          8,
          EGL14.EGL_ALPHA_SIZE,
          8,
          EGL14.EGL_DEPTH_SIZE,
          24,
          EGL14.EGL_STENCIL_SIZE,
          8,
          EGL14.EGL_NONE,
        )
      val configs = arrayOfNulls<EGLConfig>(1)
      val count = IntArray(1)
      eglCheck(
        EGL14.eglChooseConfig(display, attributes, 0, configs, 0, configs.size, count, 0),
        "choose EGL config",
      )
      check(count[0] > 0 && configs[0] != null) {
        "no EGL config supports OpenGL ES 3 window rendering"
      }
      return configs[0]!!
    }

    private fun eglCheck(ok: Boolean, operation: String) {
      if (!ok) {
        error("$operation failed with EGL error 0x${EGL14.eglGetError().toString(16)}")
      }
    }
  }
}
