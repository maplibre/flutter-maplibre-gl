# setLayerFilter reads these fields by reflection to report why the map
# rejected a filter. Keep their names in minified release builds.
-keepclassmembers class org.maplibre.android.log.Logger {
    private static org.maplibre.android.log.LoggerDefinition logger;
    private static int logLevel;
}

# Google Play Services location is an optional dependency (compileOnly). Apps that
# do not add play-services-location must still build with minify on: the plugin's
# references to it are only reached behind a NoClassDefFoundError guard.
-dontwarn com.google.android.gms.**
