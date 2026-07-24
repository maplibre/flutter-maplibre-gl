cmake_minimum_required(VERSION 3.22)
project(maplibre_gl_native_shim C)

# Prebuilt MapLibre Native C API library, copied into jniLibs by the spike
# setup (see the package README). Linking it here also makes Gradle load it
# as a dependency of the shim.
add_library(maplibre-native-c SHARED IMPORTED)
set_target_properties(maplibre-native-c PROPERTIES
  IMPORTED_LOCATION
  ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmaplibre-native-c.so)

# Dart API dynamic-linking stubs, compiled straight from the Flutter/Dart SDK
# performing this build (path injected by android/build.gradle), so the stubs
# always match the Dart VM shipped in the same app. Used by the vsync pulse
# service to post to a Dart native port from the choreographer thread.
if(NOT DEFINED DART_SDK_INCLUDE_DIR)
  message(FATAL_ERROR
    "DART_SDK_INCLUDE_DIR not set (android/build.gradle derives it from "
    "flutter.sdk in local.properties)")
endif()
add_library(maplibre_gl_native_shim SHARED
  shim.c ${DART_SDK_INCLUDE_DIR}/dart_api_dl.c)
target_include_directories(maplibre_gl_native_shim PRIVATE
  ${DART_SDK_INCLUDE_DIR})
# vulkan + android: Vulkan bootstrap, ANativeWindow access, ALooper and
# AChoreographer for the vsync pulse service; log for shim diagnostics.
target_link_libraries(maplibre_gl_native_shim maplibre-native-c vulkan android log)
