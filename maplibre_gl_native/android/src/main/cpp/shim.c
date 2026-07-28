// Minimal JNI shim for the maplibre_gl_native spike.
//
// Two responsibilities, both impossible from Kotlin or Dart alone:
//
// 1. mln_android_init: requires a JNIEnv* of an attached thread plus the
//    application Context so the rustls-platform-verifier component can
//    validate TLS certificates with the platform trust store.
// 2. Vulkan bootstrap: Android exposes no Java API for Vulkan, so when the
//    bundled MapLibre Native library is a Vulkan build, the instance/device/
//    queue and the VkSurfaceKHR over the Flutter SurfaceProducer window are
//    created here and handed to Dart as raw handles (all borrowed by the
//    MapLibre Native render session).
//
// Everything else reaches the MapLibre Native C API directly from Dart via
// dart:ffi.

#include <jni.h>
#include <stdint.h>

#include <android/native_window_jni.h>

// Expose the VK_KHR_android_surface types (VkAndroidSurfaceCreateInfoKHR).
#define VK_USE_PLATFORM_ANDROID_KHR
#include <vulkan/vulkan.h>

// From maplibre_native_c/android.h. Declared locally so the shim does not
// depend on the maplibre-native-ffi include path; mln_status is a C enum and
// therefore int-sized, and the function has a stable C ABI.
extern int mln_android_init(void* jni_env, void* jni_class, void* context);

JNIEXPORT jint JNICALL
Java_org_maplibre_maplibreglnative_MapLibreGlNativePlugin_nativeAndroidInit(
    JNIEnv* env, jobject thiz, jobject context) {
  (void)thiz;
  return (jint)mln_android_init(env, NULL, context);
}

// --- Vulkan bootstrap --------------------------------------------------------

// Process-wide Vulkan objects, created once and never destroyed: their
// lifetime is the app process, like the MapLibre runtime that borrows them.
static VkInstance g_instance = VK_NULL_HANDLE;
static VkPhysicalDevice g_physical_device = VK_NULL_HANDLE;
static VkDevice g_device = VK_NULL_HANDLE;
static VkQueue g_queue = VK_NULL_HANDLE;
static uint32_t g_queue_family = 0;

// Returns 0 on success, a negative step marker on failure (for logs).
static int vulkan_ensure_context(void) {
  if (g_device != VK_NULL_HANDLE) {
    return 0;
  }

  const VkApplicationInfo app_info = {
      .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
      .pApplicationName = "maplibre_gl_native",
      .apiVersion = VK_API_VERSION_1_1,
  };
  const char* instance_extensions[] = {
      "VK_KHR_surface",
      "VK_KHR_android_surface",
  };
  const VkInstanceCreateInfo instance_info = {
      .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
      .pApplicationInfo = &app_info,
      .enabledExtensionCount = 2,
      .ppEnabledExtensionNames = instance_extensions,
  };
  if (vkCreateInstance(&instance_info, NULL, &g_instance) != VK_SUCCESS) {
    return -1;
  }

  uint32_t device_count = 0;
  if (vkEnumeratePhysicalDevices(g_instance, &device_count, NULL) !=
          VK_SUCCESS ||
      device_count == 0) {
    return -2;
  }
  VkPhysicalDevice devices[4];
  if (device_count > 4) device_count = 4;
  if (vkEnumeratePhysicalDevices(g_instance, &device_count, devices) !=
      VK_SUCCESS) {
    return -2;
  }
  g_physical_device = devices[0];

  uint32_t family_count = 0;
  vkGetPhysicalDeviceQueueFamilyProperties(g_physical_device, &family_count,
                                           NULL);
  VkQueueFamilyProperties families[16];
  if (family_count > 16) family_count = 16;
  vkGetPhysicalDeviceQueueFamilyProperties(g_physical_device, &family_count,
                                           families);
  uint32_t family = family_count;
  for (uint32_t i = 0; i < family_count; i++) {
    if (families[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) {
      family = i;
      break;
    }
  }
  if (family == family_count) {
    return -3;
  }
  g_queue_family = family;

  // Enable every feature the device supports: the MapLibre renderer decides
  // what it uses, and a borrowed device cannot be re-created later.
  VkPhysicalDeviceFeatures features;
  vkGetPhysicalDeviceFeatures(g_physical_device, &features);

  const float priority = 1.0f;
  const VkDeviceQueueCreateInfo queue_info = {
      .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
      .queueFamilyIndex = family,
      .queueCount = 1,
      .pQueuePriorities = &priority,
  };
  const char* device_extensions[] = {"VK_KHR_swapchain"};
  const VkDeviceCreateInfo device_info = {
      .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
      .queueCreateInfoCount = 1,
      .pQueueCreateInfos = &queue_info,
      .enabledExtensionCount = 1,
      .ppEnabledExtensionNames = device_extensions,
      .pEnabledFeatures = &features,
  };
  if (vkCreateDevice(g_physical_device, &device_info, NULL, &g_device) !=
      VK_SUCCESS) {
    return -4;
  }
  vkGetDeviceQueue(g_device, family, 0, &g_queue);
  return 0;
}

// Returns [instance, physicalDevice, device, queue, queueFamilyIndex,
// getInstanceProcAddr, getDeviceProcAddr] or NULL on failure.
JNIEXPORT jlongArray JNICALL
Java_org_maplibre_maplibreglnative_MapLibreGlNativePlugin_nativeVulkanInit(
    JNIEnv* env, jobject thiz) {
  (void)thiz;
  if (vulkan_ensure_context() != 0) {
    return NULL;
  }
  const jlong values[7] = {
      (jlong)(uintptr_t)g_instance,
      (jlong)(uintptr_t)g_physical_device,
      (jlong)(uintptr_t)g_device,
      (jlong)(uintptr_t)g_queue,
      (jlong)g_queue_family,
      (jlong)(uintptr_t)&vkGetInstanceProcAddr,
      (jlong)(uintptr_t)vkGetInstanceProcAddr(g_instance,
                                              "vkGetDeviceProcAddr"),
  };
  jlongArray result = (*env)->NewLongArray(env, 7);
  if (result == NULL) return NULL;
  (*env)->SetLongArrayRegion(env, result, 0, 7, values);
  return result;
}

// Returns [vkSurfaceKHR, aNativeWindow] or NULL on failure. The window is
// retained and must be released through nativeVulkanDestroySurface.
JNIEXPORT jlongArray JNICALL
Java_org_maplibre_maplibreglnative_MapLibreGlNativePlugin_nativeVulkanCreateSurface(
    JNIEnv* env, jobject thiz, jobject java_surface) {
  (void)thiz;
  if (vulkan_ensure_context() != 0) {
    return NULL;
  }
  ANativeWindow* window = ANativeWindow_fromSurface(env, java_surface);
  if (window == NULL) {
    return NULL;
  }
  PFN_vkCreateAndroidSurfaceKHR create_surface =
      (PFN_vkCreateAndroidSurfaceKHR)vkGetInstanceProcAddr(
          g_instance, "vkCreateAndroidSurfaceKHR");
  if (create_surface == NULL) {
    ANativeWindow_release(window);
    return NULL;
  }
  const VkAndroidSurfaceCreateInfoKHR surface_info = {
      .sType = VK_STRUCTURE_TYPE_ANDROID_SURFACE_CREATE_INFO_KHR,
      .window = window,
  };
  VkSurfaceKHR surface = VK_NULL_HANDLE;
  if (create_surface(g_instance, &surface_info, NULL, &surface) !=
      VK_SUCCESS) {
    ANativeWindow_release(window);
    return NULL;
  }
  const jlong values[2] = {(jlong)surface, (jlong)(uintptr_t)window};
  jlongArray result = (*env)->NewLongArray(env, 2);
  if (result == NULL) return NULL;
  (*env)->SetLongArrayRegion(env, result, 0, 2, values);
  return result;
}

JNIEXPORT void JNICALL
Java_org_maplibre_maplibreglnative_MapLibreGlNativePlugin_nativeVulkanDestroySurface(
    JNIEnv* env, jobject thiz, jlong vk_surface, jlong window) {
  (void)env;
  (void)thiz;
  if (vk_surface != 0 && g_instance != VK_NULL_HANDLE) {
    PFN_vkDestroySurfaceKHR destroy_surface =
        (PFN_vkDestroySurfaceKHR)vkGetInstanceProcAddr(g_instance,
                                                       "vkDestroySurfaceKHR");
    if (destroy_surface != NULL) {
      destroy_surface(g_instance, (VkSurfaceKHR)vk_surface, NULL);
    }
  }
  if (window != 0) {
    ANativeWindow_release((ANativeWindow*)(uintptr_t)window);
  }
}

// --- Display vsync pulse service ---------------------------------------------
//
// Drives the engine isolate's frame loop in phase with the display: a
// dedicated pthread (created once, never exits; "stop" only pauses) owns an
// ALooper plus an AChoreographer and posts each frame-callback timestamp to
// the engine isolate's native port with Dart_PostInteger_DL. Posting to a
// dead port is a documented no-op, which makes hot restart self-healing: the
// old isolate's port dies, the post returns false, the service parks itself
// until the new isolate calls mln_shim_vsync_start with its own port.
//
// THIS THREAD MUST NEVER CALL INTO libmaplibre-native-c: MapLibre handles
// are owner-thread affine to the engine isolate. The only cross-thread call
// allowed here is Dart_PostInteger_DL (any-thread safe by contract).

#include <android/choreographer.h>
#include <android/log.h>
#include <android/looper.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdbool.h>
#include <time.h>

#include "dart_api_dl.h"

#define MLN_SHIM_LOG_TAG "maplibre_gl_native"
#define MLN_SHIM_EXPORT __attribute__((visibility("default")))

static pthread_mutex_t g_vsync_mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t g_vsync_cond = PTHREAD_COND_INITIALIZER;
static pthread_t g_vsync_thread;
static bool g_vsync_thread_started = false;  // pthread_create succeeded
static bool g_vsync_thread_ready = false;    // looper/choreographer published
static bool g_vsync_thread_failed = false;   // no looper or choreographer
static ALooper* g_vsync_looper = NULL;
static AChoreographer* g_vsync_choreographer = NULL;
static Dart_Port_DL g_vsync_port = 0;
static bool g_vsync_running = false;           // deliver + re-post pulses
static bool g_vsync_callback_pending = false;  // a one-shot callback is armed
// API 29+ 64-bit frame callback, dlsym-probed once on the pulse thread; the
// deprecated 32-bit variant (API 24) is the fallback.
static void (*g_post_frame_callback64)(AChoreographer*,
                                       AChoreographer_frameCallback64,
                                       void*) = NULL;

static void vsync_on_frame64(int64_t frame_time_nanos, void* data);
static void vsync_on_frame32(long frame_time_nanos, void* data);

// Re-arms the one-shot choreographer callback. Caller holds g_vsync_mutex;
// must run on the pulse thread (registration is looper-local).
static void vsync_post_locked(void) {
  if (g_vsync_callback_pending || !g_vsync_running ||
      g_vsync_choreographer == NULL) {
    return;
  }
  g_vsync_callback_pending = true;
  if (g_post_frame_callback64 != NULL) {
    g_post_frame_callback64(g_vsync_choreographer, vsync_on_frame64, NULL);
  } else {
    // 'long' is 64-bit on the only shipped ABI (arm64-v8a), so no
    // truncation; the Dart driver paces off its own clock regardless.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AChoreographer_postFrameCallback(g_vsync_choreographer, vsync_on_frame32,
                                     NULL);
#pragma clang diagnostic pop
  }
}

static void vsync_on_frame64(int64_t frame_time_nanos, void* data) {
  (void)data;
  pthread_mutex_lock(&g_vsync_mutex);
  g_vsync_callback_pending = false;
  if (g_vsync_running && g_vsync_port != 0) {
    if (!Dart_PostInteger_DL(g_vsync_port, frame_time_nanos)) {
      // The engine isolate is gone (hot restart): self-park, no spam.
      __android_log_print(ANDROID_LOG_INFO, MLN_SHIM_LOG_TAG,
                          "vsync port closed; parking pulses");
      g_vsync_running = false;
      g_vsync_port = 0;
    }
  }
  vsync_post_locked();
  pthread_mutex_unlock(&g_vsync_mutex);
}

static void vsync_on_frame32(long frame_time_nanos, void* data) {
  vsync_on_frame64((int64_t)frame_time_nanos, data);
}

static void* vsync_thread_main(void* arg) {
  (void)arg;
  ALooper* looper = ALooper_prepare(0);
  AChoreographer* choreographer =
      looper != NULL ? AChoreographer_getInstance() : NULL;
  pthread_mutex_lock(&g_vsync_mutex);
  g_vsync_looper = looper;
  g_vsync_choreographer = choreographer;
  g_vsync_thread_failed = choreographer == NULL;
  g_vsync_thread_ready = true;
  g_post_frame_callback64 =
      (void (*)(AChoreographer*, AChoreographer_frameCallback64, void*))dlsym(
          RTLD_DEFAULT, "AChoreographer_postFrameCallback64");
  pthread_cond_broadcast(&g_vsync_cond);
  pthread_mutex_unlock(&g_vsync_mutex);
  if (choreographer == NULL) {
    return NULL;
  }
  for (;;) {
    // Dispatches choreographer callbacks; blocks indefinitely while parked.
    // A resume arrives as an ALooper_wake from mln_shim_vsync_start.
    ALooper_pollOnce(-1, NULL, NULL, NULL);
    pthread_mutex_lock(&g_vsync_mutex);
    vsync_post_locked();
    pthread_mutex_unlock(&g_vsync_mutex);
  }
}

// Idempotent; data = NativeApi.initializeApiDLData. Returns 0 on success,
// negative on Dart API DL version mismatch.
MLN_SHIM_EXPORT int64_t mln_shim_dart_init(void* data) {
  return (int64_t)Dart_InitializeApiDL(data);
}

// Starts (first call: spawns the pulse thread) or resumes pulses, posting
// each frame time to dart_port. Idempotent; re-targets the port when called
// with a new one. Returns 1 on success, 0 when pulses are unavailable.
MLN_SHIM_EXPORT int32_t mln_shim_vsync_start(int64_t dart_port) {
  pthread_mutex_lock(&g_vsync_mutex);
  if (!g_vsync_thread_started) {
    if (pthread_create(&g_vsync_thread, NULL, vsync_thread_main, NULL) != 0) {
      pthread_mutex_unlock(&g_vsync_mutex);
      __android_log_print(ANDROID_LOG_WARN, MLN_SHIM_LOG_TAG,
                          "vsync pulse thread creation failed");
      return 0;
    }
    g_vsync_thread_started = true;
    pthread_setname_np(g_vsync_thread, "mln-vsync");
  }
  while (!g_vsync_thread_ready) {
    pthread_cond_wait(&g_vsync_cond, &g_vsync_mutex);
  }
  if (g_vsync_thread_failed) {
    pthread_mutex_unlock(&g_vsync_mutex);
    __android_log_print(ANDROID_LOG_WARN, MLN_SHIM_LOG_TAG,
                        "vsync choreographer unavailable");
    return 0;
  }
  g_vsync_port = (Dart_Port_DL)dart_port;
  g_vsync_running = true;
  ALooper* looper = g_vsync_looper;
  pthread_mutex_unlock(&g_vsync_mutex);
  // Nudge the (possibly parked) pulse thread so it re-arms the one-shot
  // frame callback.
  ALooper_wake(looper);
  return 1;
}

// Pauses pulses. After return no NEW post to the port will start; at most
// one already-posted message may still sit in the Dart port queue (the Dart
// driver tolerates a trailing pulse).
MLN_SHIM_EXPORT void mln_shim_vsync_stop(void) {
  pthread_mutex_lock(&g_vsync_mutex);
  g_vsync_running = false;
  g_vsync_port = 0;
  pthread_mutex_unlock(&g_vsync_mutex);
}

// Reads the clock the frame times above are stamped with, so Dart can tell how
// old a pulse is by the time it handles it. AChoreographer uses
// CLOCK_MONOTONIC and Dart's Stopwatch has an unrelated epoch, so subtracting
// one from the other is only meaningful through a shared reader. Any thread;
// returns 0 if the clock is unavailable, which the caller reads as "no
// measurement".
MLN_SHIM_EXPORT int64_t mln_shim_monotonic_nanos(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    return 0;
  }
  return (int64_t)now.tv_sec * 1000000000 + (int64_t)now.tv_nsec;
}
