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

// Unwinds a partially built context so a retry starts clean: the idempotence
// guard above is on g_device, so anything created short of that must not
// survive a failure, or every failed retry would leak a VkInstance.
static int vulkan_fail(int step) {
  if (g_instance != VK_NULL_HANDLE) {
    vkDestroyInstance(g_instance, NULL);
    g_instance = VK_NULL_HANDLE;
  }
  g_physical_device = VK_NULL_HANDLE;
  return step;
}

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
    // The output handle is undefined on failure; there is nothing to destroy.
    g_instance = VK_NULL_HANDLE;
    return -1;
  }

  uint32_t device_count = 0;
  if (vkEnumeratePhysicalDevices(g_instance, &device_count, NULL) !=
          VK_SUCCESS ||
      device_count == 0) {
    return vulkan_fail(-2);
  }
  VkPhysicalDevice devices[4];
  if (device_count > 4) device_count = 4;
  if (vkEnumeratePhysicalDevices(g_instance, &device_count, devices) !=
      VK_SUCCESS) {
    return vulkan_fail(-2);
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
    return vulkan_fail(-3);
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
    return vulkan_fail(-4);
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
  if (result == NULL) {
    // Allocation failure (OOM pending on the JVM side): give the surface and
    // the retained window back like every other error path does, or a retry
    // would leak both.
    PFN_vkDestroySurfaceKHR destroy_surface =
        (PFN_vkDestroySurfaceKHR)vkGetInstanceProcAddr(g_instance,
                                                       "vkDestroySurfaceKHR");
    if (destroy_surface != NULL) {
      destroy_surface(g_instance, surface, NULL);
    }
    ANativeWindow_release(window);
    return NULL;
  }
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

// --- Display-paced render service --------------------------------------------
//
// A dedicated pthread (created once, never exits; "stop" only pauses) owns an
// ALooper plus an AChoreographer, and on each frame callback it renders the
// bound MapLibre render session itself. Dart is not in the frame path: no port
// message per frame, and no Dart work (GC, HTTP, style parse) can delay one.
//
// THIS THREAD CALLS INTO libmaplibre-native-c, which the previous shape of this
// file forbade. What changed is that a render session's owner thread is now the
// thread that attached it rather than the map's, so a session can legitimately
// live here while Dart keeps the runtime and the maps. Two symbols are reached,
// both session-scoped: render_update and the per-session rebind.
//
// Ownership handover. Every session entry point is owner-thread checked, and
// Dart still needs several of them (feature queries, feature state, resize,
// surface replace, detach). So ownership ping-pongs under g_render_mutex: each
// side rebinds the session to itself before calling and holds the mutex for the
// duration. Renders are frequent and queries are rare, so in the common case
// this thread simply keeps it. Dart borrows it through
// mln_shim_render_acquire/mln_shim_render_release, which block this thread's
// next render rather than racing it.
//
// Liveness. With no per-frame port post there is no longer a dead-port signal
// to self-park on, so a failing render_update parks the service instead: on hot
// restart the old isolate's surface dies, the render fails, and pulses park
// until the new isolate binds its own session.

#include <android/choreographer.h>
#include <android/log.h>
#include <android/looper.h>
#include <dlfcn.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <time.h>

#include "dart_api_dl.h"

#define MLN_SHIM_LOG_TAG "maplibre_gl_native"
#define MLN_SHIM_EXPORT __attribute__((visibility("default")))

// From maplibre_native_c/render_session.h. Declared locally for the same
// reason as mln_android_init above: the shim needs no include path, mln_status
// is int-sized, and mln_render_session is a 64-bit generational handle id.
extern int mln_render_session_render_update(uint64_t session,
                                            bool* out_rendered);
extern int mln_render_session_rebind_thread(uint64_t session);

// Guards session ownership. Held across a render here, and across the whole
// borrow when Dart takes the session. Separate from g_vsync_mutex, which only
// protects the pulse bookkeeping: taking that one while blocked on a Dart
// borrow would stall mln_shim_vsync_stop.
//
// Every lock of this mutex is bounded (see render_mutex_lock_or_give_up):
// a hot restart can kill the borrowing isolate between acquire and release,
// and the OS thread that owns the lock lives on in the VM's pool, so an
// unbounded wait here would freeze the display, and the next bind with it,
// until the process dies. Bounded waits turn that into a loud log plus
// skipped frames until the lock comes back (or, if it never does, a park).
//
// LOCK ORDER: g_render_mutex may be held while g_stats_mutex is taken
// (render_bound_session -> stats_record); never take g_render_mutex while
// holding g_stats_mutex. g_vsync_mutex is never held across either (the
// frame callback deliberately renders outside it).
static pthread_mutex_t g_render_mutex = PTHREAD_MUTEX_INITIALIZER;
// The bound session handle id, or 0 (the null handle) when Dart has not
// offered one (or withdrew it).
static uint64_t g_render_session = 0;
// Whether this thread currently holds the session's owner-thread affinity.
static bool g_render_owned_here = false;
// Consecutive failed renders, reset by any success, any bind, and every pulse
// resume. About two seconds at 90 Hz, which no legitimate surface swap comes
// close to. Atomic so the resume path can reset it without taking (and
// possibly blocking on) g_render_mutex.
#define MLN_SHIM_RENDER_FAILURE_LIMIT 180
static _Atomic int32_t g_render_failures = 0;

// Longer than any frame or borrowed call has business taking; short enough
// that a wedged mutex is diagnosed, not waited out.
#define MLN_SHIM_RENDER_LOCK_TIMEOUT_SECONDS 2

// While the mutex is wedged, later attempts wait this long instead: long
// enough to catch a borrower releasing between two pulses, short enough that
// a pulse skipping its render is not itself late.
#define MLN_SHIM_RENDER_LOCK_RETRY_MILLIS 10

// Set when a lock attempt times out, cleared by the next attempt that
// succeeds. A wedged mutex usually means a borrow was never returned (hot
// restart mid-borrow is the known way), but from here that is
// indistinguishable from a borrower that is merely very slow, so the flag
// only shortens later waits; it never writes the lock off for good. If the
// borrower does release, the next attempt takes the lock, clears the flag,
// and the display renders resume.
static _Atomic bool g_render_mutex_wedged = false;

// pthread_mutex_clocklock waits on a caller-chosen clock, so the timeout can
// use CLOCK_MONOTONIC and an NTP step cannot expire it early (or late).
// bionic only exports it from API 30 and minSdk is 24, so it is resolved once
// at runtime; without it the fallback is pthread_mutex_timedlock, whose
// CLOCK_REALTIME deadline a clock jump can distort, which at worst costs the
// frames of one spurious timeout-and-recover cycle.
static int (*g_mutex_clocklock)(pthread_mutex_t*, clockid_t,
                                const struct timespec*) = NULL;
static pthread_once_t g_mutex_clocklock_once = PTHREAD_ONCE_INIT;
static void mutex_clocklock_resolve(void) {
  *(void**)&g_mutex_clocklock = dlsym(RTLD_DEFAULT, "pthread_mutex_clocklock");
}

// Locks g_render_mutex with a bounded wait. False means the lock could not
// be taken in time and the caller must skip its work rather than block: a
// skipped frame (or a refused bind) is recoverable, a display thread parked
// on a mutex whose owner may never return is not.
static bool render_mutex_lock_or_give_up(const char* who) {
  pthread_once(&g_mutex_clocklock_once, mutex_clocklock_resolve);
  const clockid_t clock =
      g_mutex_clocklock != NULL ? CLOCK_MONOTONIC : CLOCK_REALTIME;
  struct timespec deadline;
  if (clock_gettime(clock, &deadline) != 0) {
    // No clock, no bounded wait; give up rather than block unboundedly.
    return false;
  }
  if (atomic_load_explicit(&g_render_mutex_wedged, memory_order_relaxed)) {
    deadline.tv_nsec += MLN_SHIM_RENDER_LOCK_RETRY_MILLIS * 1000000L;
    if (deadline.tv_nsec >= 1000000000L) {
      deadline.tv_sec += 1;
      deadline.tv_nsec -= 1000000000L;
    }
  } else {
    deadline.tv_sec += MLN_SHIM_RENDER_LOCK_TIMEOUT_SECONDS;
  }
  const int rc = g_mutex_clocklock != NULL
                     ? g_mutex_clocklock(&g_render_mutex, clock, &deadline)
                     : pthread_mutex_timedlock(&g_render_mutex, &deadline);
  if (rc == 0) {
    if (atomic_exchange_explicit(&g_render_mutex_wedged, false,
                                 memory_order_relaxed)) {
      __android_log_print(ANDROID_LOG_INFO, MLN_SHIM_LOG_TAG,
                          "%s: render mutex recovered; display renders resume",
                          who);
    }
    return true;
  }
  // Log the transition only, not every fast retry at display rate.
  if (!atomic_exchange_explicit(&g_render_mutex_wedged, true,
                                memory_order_relaxed)) {
    __android_log_print(ANDROID_LOG_ERROR, MLN_SHIM_LOG_TAG,
                        "%s: render mutex held for over %d s (a borrow not "
                        "yet returned; hot restart mid-borrow?); skipping "
                        "display renders until it comes back",
                        who, MLN_SHIM_RENDER_LOCK_TIMEOUT_SECONDS);
  }
  return false;
}
// Frames actually drawn. Dart reads it to tell "the map is still moving" from
// "nothing left to draw", which is what its idle-park decision used to get from
// its own render call. Atomic because it is read without g_render_mutex.
static _Atomic int64_t g_render_frames = 0;

// Per-frame render samples for the benchmark harness, which used to get them by
// timing its own render call. Recording here instead measures the draw on the
// thread that performs it, which is what the numbers are supposed to describe.
//
// Capacity is ~45 s at 90 Hz. A full buffer stops recording and counts the
// misses rather than wrapping, so a truncated run cannot read as a complete one.
#define MLN_SHIM_STATS_CAPACITY 4096
static pthread_mutex_t g_stats_mutex = PTHREAD_MUTEX_INITIALIZER;
static bool g_stats_armed = false;
static int64_t g_stats_start_us[MLN_SHIM_STATS_CAPACITY];
static int64_t g_stats_duration_us[MLN_SHIM_STATS_CAPACITY];
static int32_t g_stats_count = 0;
static int64_t g_stats_dropped = 0;

static int64_t monotonic_micros(void) {
  struct timespec now;
  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    return 0;
  }
  return (int64_t)now.tv_sec * 1000000 + (int64_t)now.tv_nsec / 1000;
}

static void stats_record(int64_t start_us, int64_t duration_us) {
  pthread_mutex_lock(&g_stats_mutex);
  if (!g_stats_armed) {
    pthread_mutex_unlock(&g_stats_mutex);
    return;
  }
  if (g_stats_count >= MLN_SHIM_STATS_CAPACITY) {
    g_stats_dropped += 1;
  } else {
    g_stats_start_us[g_stats_count] = start_us;
    g_stats_duration_us[g_stats_count] = duration_us;
    g_stats_count += 1;
  }
  pthread_mutex_unlock(&g_stats_mutex);
}

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

// Renders the bound session, taking its owner-thread affinity first if Dart
// borrowed it. Returns false when the service should park.
//
// A render is never skipped by the age of its pulse: render_update draws the
// map's CURRENT state and takes no time argument, so a late pulse is a fresh
// picture drawn late. Dropping them by age was tried on device and made every
// gesture visibly jerky while flattering the numbers.
static bool render_bound_session(void) {
  if (!render_mutex_lock_or_give_up("render")) {
    // The lock did not come in time, so this frame is skipped, not the
    // service: the borrower may still return, and the next pulse retries
    // (fast, see MLN_SHIM_RENDER_LOCK_RETRY_MILLIS). Skips share the render
    // failure counter, so a lock that truly never comes back still hits the
    // limit below and parks instead of burning a retry per frame forever.
    const int32_t failures =
        atomic_fetch_add_explicit(&g_render_failures, 1,
                                  memory_order_relaxed) +
        1;
    if (failures < MLN_SHIM_RENDER_FAILURE_LIMIT) {
      return true;
    }
    __android_log_print(ANDROID_LOG_INFO, MLN_SHIM_LOG_TAG,
                        "render lock unavailable %d frames in a row; parking",
                        failures);
    return false;
  }
  const uint64_t session = g_render_session;
  if (session == 0) {
    pthread_mutex_unlock(&g_render_mutex);
    return true;  // Nothing offered yet; keep the pulses coming.
  }
  if (!g_render_owned_here) {
    const int status = mln_render_session_rebind_thread(session);
    if (status != 0) {
      pthread_mutex_unlock(&g_render_mutex);
      __android_log_print(ANDROID_LOG_WARN, MLN_SHIM_LOG_TAG,
                          "render session rebind failed (%d); parking", status);
      return false;
    }
    g_render_owned_here = true;
  }
  bool rendered = false;
  const int64_t started_us = monotonic_micros();
  const int status = mln_render_session_render_update(session, &rendered);
  if (rendered) {
    atomic_fetch_add_explicit(&g_render_frames, 1, memory_order_relaxed);
    stats_record(started_us, monotonic_micros() - started_us);
  }
  if (status == 0) {
    atomic_store_explicit(&g_render_failures, 0, memory_order_relaxed);
    pthread_mutex_unlock(&g_render_mutex);
    return true;
  }
  const int32_t failures =
      atomic_fetch_add_explicit(&g_render_failures, 1, memory_order_relaxed) +
      1;
  pthread_mutex_unlock(&g_render_mutex);

  // A single failure is not a reason to stop: a surface being replaced fails a
  // few frames legitimately, and Dart withdraws the session for the cases it
  // knows about. A long run of them is the hot-restart signature (the old
  // isolate's surface is gone and nobody will withdraw anything), and with no
  // port post per frame this is the only liveness signal left.
  if (failures < MLN_SHIM_RENDER_FAILURE_LIMIT) {
    return true;
  }
  __android_log_print(ANDROID_LOG_INFO, MLN_SHIM_LOG_TAG,
                      "render_update failed %d times in a row (%d); parking",
                      failures, status);
  return false;
}

static void vsync_on_frame64(int64_t frame_time_nanos, void* data) {
  (void)data;
  pthread_mutex_lock(&g_vsync_mutex);
  g_vsync_callback_pending = false;
  const bool running = g_vsync_running;
  pthread_mutex_unlock(&g_vsync_mutex);

  // Rendering outside g_vsync_mutex: it can block on a Dart borrow, and
  // mln_shim_vsync_stop must stay able to park the service meanwhile.
  const bool keep_going = running ? render_bound_session() : true;

  pthread_mutex_lock(&g_vsync_mutex);
  if (g_vsync_running && g_vsync_port != 0) {
    // The pulse still goes to Dart, but it no longer carries the frame: it is
    // the metronome for the runtime pump, which is still Dart's and is still
    // required (a resize reaches the map only when its owner thread pumps, and
    // tile and style work all lands there). That is why it is posted even on a
    // frame whose render failed or never took the lock: a missed draw must
    // not also stop the pump. Rendering first and pumping after costs one
    // frame of staleness against the old pump-then-render turn, and buys a
    // frame path that no Dart work can delay. Posting after the render keeps
    // that ordering explicit.
    if (!Dart_PostInteger_DL(g_vsync_port, frame_time_nanos)) {
      __android_log_print(ANDROID_LOG_INFO, MLN_SHIM_LOG_TAG,
                          "vsync port closed; parking pulses");
      g_vsync_running = false;
      g_vsync_port = 0;
    }
  }
  if (!keep_going) {
    g_vsync_running = false;
  }
  vsync_post_locked();
  pthread_mutex_unlock(&g_vsync_mutex);
}

static void vsync_on_frame32(long frame_time_nanos, void* data) {
  vsync_on_frame64((int64_t)frame_time_nanos, data);
}

static void* vsync_thread_main(void* arg) {
  (void)arg;
  // Named from inside: naming by handle from the spawner would race the
  // (admittedly unlikely) case of this thread exiting first.
  pthread_setname_np(pthread_self(), "mln-vsync");
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
    // Never joined (it lives for the process; "stop" only parks it), so
    // detach up front rather than leaking a joinable thread's bookkeeping.
    pthread_detach(g_vsync_thread);
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
  // A resume forgives past render failures: a service parked at the failure
  // limit would otherwise re-park after a single failure on every wake.
  atomic_store_explicit(&g_render_failures, 0, memory_order_relaxed);
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

// Offers a render session for this thread to draw, or withdraws it with 0.
//
// Idempotent, and safe while the service is rendering: it waits for the frame
// in flight. Withdrawing leaves the session's owner thread as it is, because
// the caller is about to take it back through mln_shim_render_acquire anyway.
//
// bind(0) withdraws UNCONDITIONALLY, whatever is bound; that is for shutdown.
// A caller that means "withdraw MY session" must use mln_shim_render_unbind,
// or with two maps alive it would silently pull the other map's session.
//
// Returns 1 on success, 0 when the render mutex could not be taken in time
// (see render_mutex_lock_or_give_up); on 0 the caller must draw on its own
// thread.
MLN_SHIM_EXPORT int32_t mln_shim_render_bind(int64_t session_handle) {
  if (!render_mutex_lock_or_give_up("bind")) {
    return 0;
  }
  g_render_session = (uint64_t)session_handle;
  g_render_owned_here = false;
  atomic_store_explicit(&g_render_failures, 0, memory_order_relaxed);
  pthread_mutex_unlock(&g_render_mutex);
  return 1;
}

// Withdraws the bound session only if it is the given one. This is the native
// check behind the invariant that a map never withdraws another map's
// session: the Dart side aims for it, but one thread serves many maps, so the
// last word has to be here where the binding actually lives.
//
// Returns 1 when the session matched and was withdrawn; 0 (with a log, and
// nothing changed) on mismatch, or when the render mutex could not be taken
// in time.
MLN_SHIM_EXPORT int32_t mln_shim_render_unbind(int64_t session_handle) {
  if (!render_mutex_lock_or_give_up("unbind")) {
    return 0;
  }
  if (g_render_session != (uint64_t)session_handle) {
    const uint64_t bound = g_render_session;
    pthread_mutex_unlock(&g_render_mutex);
    __android_log_print(ANDROID_LOG_WARN, MLN_SHIM_LOG_TAG,
                        "render unbind ignored: session %" PRIu64
                        " is not the bound one (%" PRIu64 ")",
                        (uint64_t)session_handle, bound);
    return 0;
  }
  g_render_session = 0;
  g_render_owned_here = false;
  pthread_mutex_unlock(&g_render_mutex);
  return 1;
}

// Borrows the bound session for the calling thread, blocking until the frame in
// flight finishes. The caller MUST rebind the session to itself (the C API
// checks the owner thread on every entry point) and MUST call
// mln_shim_render_release when done, or the display stops.
//
// Recursion is not supported: this is a plain mutex, so a nested acquire
// deadlocks. The Dart side keeps the bracket to a single leaf call.
//
// Returns 1 with the mutex held, or 0 when it could not be taken in time; on
// 0 the caller must NOT call mln_shim_render_release.
MLN_SHIM_EXPORT int32_t mln_shim_render_acquire(void) {
  if (!render_mutex_lock_or_give_up("acquire")) {
    return 0;
  }
  // The borrower is about to take the affinity, so this thread has lost it.
  g_render_owned_here = false;
  return 1;
}

// Returns a borrowed session. The next frame re-takes the affinity.
MLN_SHIM_EXPORT void mln_shim_render_release(void) {
  pthread_mutex_unlock(&g_render_mutex);
}

// Frames drawn since process start. Monotonic; any thread. Dart watches it move
// to decide whether the map still has work, which is what it used to learn from
// the return value of its own render call.
MLN_SHIM_EXPORT int64_t mln_shim_render_frame_count(void) {
  return atomic_load_explicit(&g_render_frames, memory_order_relaxed);
}

// Arms or disarms per-frame sample collection, discarding anything held.
MLN_SHIM_EXPORT void mln_shim_render_stats_enable(int32_t enabled) {
  pthread_mutex_lock(&g_stats_mutex);
  g_stats_armed = enabled != 0;
  g_stats_count = 0;
  g_stats_dropped = 0;
  pthread_mutex_unlock(&g_stats_mutex);
}

// Drains collected samples into caller-owned arrays of at least capacity
// entries each, and reports how many were dropped for want of room since the
// last drain. Returns the number written. Collection stays armed.
//
// Its own mutex rather than the render one: draining must not make a display
// frame wait.
MLN_SHIM_EXPORT int32_t mln_shim_render_stats_take(int64_t* out_start_us,
                                                  int64_t* out_duration_us,
                                                  int32_t capacity,
                                                  int64_t* out_dropped) {
  if (out_start_us == NULL || out_duration_us == NULL || capacity <= 0) {
    return 0;
  }
  pthread_mutex_lock(&g_stats_mutex);
  int32_t written = g_stats_count < capacity ? g_stats_count : capacity;
  for (int32_t i = 0; i < written; i++) {
    out_start_us[i] = g_stats_start_us[i];
    out_duration_us[i] = g_stats_duration_us[i];
  }
  // Anything the caller had no room for is a drop from its point of view.
  const int64_t unread = (int64_t)g_stats_count - (int64_t)written;
  if (out_dropped != NULL) {
    *out_dropped = g_stats_dropped + unread;
  }
  g_stats_count = 0;
  g_stats_dropped = 0;
  pthread_mutex_unlock(&g_stats_mutex);
  return written;
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
