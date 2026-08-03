cmake_minimum_required(VERSION 3.22)
project(maplibre_gl_native_shim C)

# shim.c uses stdatomic.h and _Atomic, which are C11.
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

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

# Hidden by default: the shim's whole ABI is the mln_shim_* functions (marked
# visibility("default") in shim.c) and the JNI entry points (JNIEXPORT).
# dart_api_dl.c in particular defines dozens of WRITABLE Dart_*_DL function
# pointers that must not be reachable, or patchable, through the dynamic
# symbol table; Dart never looks them up here, it calls mln_shim_dart_init,
# which fills them within this library.
target_compile_options(maplibre_gl_native_shim PRIVATE -fvisibility=hidden)

# The warning set is ours to satisfy, so it applies to shim.c only:
# dart_api_dl.c is the Dart SDK's file and trips -Wunused-parameter.
set_source_files_properties(shim.c PROPERTIES
  COMPILE_OPTIONS "-Wall;-Wextra;-Wthread-safety")

# The version script is the backstop for anything a header exports by
# attribute despite the flag above (Dart_InitializeApiDL is DART_EXPORT, but
# its only caller is mln_shim_dart_init in this same library): the dynamic
# symbol table ends up with exactly the two families named here, which is
# exactly what the Dart lookups in vsync_pulse.dart / render_thread.dart and
# the JVM's JNI resolution need. Generated at configure time so the exported
# surface is documented next to the flags that enforce it.
set(SHIM_VERSION_SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/shim_exports.map)
file(WRITE ${SHIM_VERSION_SCRIPT} "{
  global:
    Java_org_maplibre_maplibreglnative_*;
    mln_shim_*;
  local:
    *;
};
")

# -z defs: an undefined symbol is a link error here, not a dlopen crash on a
# user's device. --exclude-libs ALL: nothing re-exported from static inputs.
target_link_options(maplibre_gl_native_shim PRIVATE
  -Wl,--version-script=${SHIM_VERSION_SCRIPT}
  -Wl,--exclude-libs,ALL
  -Wl,-z,defs)
set_target_properties(maplibre_gl_native_shim PROPERTIES
  LINK_DEPENDS ${SHIM_VERSION_SCRIPT})

# vulkan + android: Vulkan bootstrap, ANativeWindow access, ALooper and
# AChoreographer for the vsync pulse service; log for shim diagnostics.
target_link_libraries(maplibre_gl_native_shim maplibre-native-c vulkan android log)
