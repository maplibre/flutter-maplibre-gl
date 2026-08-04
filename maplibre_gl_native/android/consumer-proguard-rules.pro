# The shim binds its JNI functions by the default naming convention
# (Java_org_maplibre_maplibreglnative_MapLibreGlNativePlugin_native*), which
# encodes the fully qualified class name: an app build that renames or moves
# the class (R8 with -repackageclasses, aggressive obfuscation) makes every
# native method fail to bind and the release app dies with
# UnsatisfiedLinkError on the first map. Keep the class name and the names of
# its native methods; everything else may still be shrunk and optimized.
-keepclasseswithmembernames class org.maplibre.maplibreglnative.MapLibreGlNativePlugin {
    native <methods>;
}
