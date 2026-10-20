# setLayerFilter reads these fields by reflection to report why the map
# rejected a filter. Keep their names in minified release builds.
-keepclassmembers class org.maplibre.android.log.Logger {
    private static org.maplibre.android.log.LoggerDefinition logger;
    private static int logLevel;
}

# FusedLocationEngineProvider looks GmsLocationSupport up by name, and the class is
# missing altogether in builds with maplibre_gl.playServicesLocation=false.
-keep class org.maplibre.maplibregl.GmsLocationSupport { <init>(); }
