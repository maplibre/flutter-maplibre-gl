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
