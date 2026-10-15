# setLayerFilter reads these fields by reflection to report why the map
# rejected a filter. Keep their names in minified release builds.
-keepclassmembers class org.maplibre.android.log.Logger {
    private static org.maplibre.android.log.LoggerDefinition logger;
    private static int logLevel;
}
