cmake_minimum_required(VERSION 3.22)
project(maplibre_gl_native_shim C)

# Prebuilt MapLibre Native C API library, copied into jniLibs by the spike
# setup (see the package README). Linking it here also makes Gradle load it
# as a dependency of the shim.
add_library(maplibre-native-c SHARED IMPORTED)
set_target_properties(maplibre-native-c PROPERTIES
  IMPORTED_LOCATION
  ${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libmaplibre-native-c.so)

# dart/dart_api_dl.c: vendored Dart API dynamic-linking stubs (BSD licensed,
# from the Flutter Dart SDK include dir) used by the vsync pulse service to
# post to a Dart native port from the choreographer thread.
add_library(maplibre_gl_native_shim SHARED shim.c dart/dart_api_dl.c)
target_include_directories(maplibre_gl_native_shim PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/dart)
# vulkan + android: Vulkan bootstrap, ANativeWindow access, ALooper and
# AChoreographer for the vsync pulse service; log for shim diagnostics.
target_link_libraries(maplibre_gl_native_shim maplibre-native-c vulkan android log)
