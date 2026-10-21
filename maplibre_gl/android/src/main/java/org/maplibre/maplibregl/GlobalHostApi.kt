package org.maplibre.maplibregl

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.net.ConnectivityReceiver
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream

/**
 * The plugin-wide operations: offline regions, the offline database, the
 * ambient cache and HTTP settings. They do not need a map, so they can run
 * before the first one is created.
 */
internal class GlobalHostApi(binding: FlutterPlugin.FlutterPluginBinding) : MapLibreGlobalHostApi {
    private val context: Context = binding.applicationContext
    private val flutterAssets: FlutterPlugin.FlutterAssets = binding.flutterAssets
    private val downloadEvents = MapLibreOfflineDownloadFlutterApi(binding.binaryMessenger)

    // Every entry point touches MapLibre.getInstance first: the offline manager
    // and the HTTP stack expect it to exist, and it is what preWarm warms up.
    private fun ensureMapLibre() {
        MapLibreUtils.getMapLibre(context)
    }

    override fun preWarm() {
        ensureMapLibre()
    }

    override fun installOfflineMapTiles(tilesDb: String) {
        ensureMapLibre()
        val dest = File(context.filesDir, DATABASE_NAME)
        try {
            openTilesDbFile(tilesDb).use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output, BUFFER_SIZE) }
            }
        } catch (e: IOException) {
            Log.e(TAG, "Could not install the offline tiles from $tilesDb", e)
        }
    }

    override fun setOffline(offline: Boolean) {
        ensureMapLibre()
        // null hands the connectivity state back to the system.
        ConnectivityReceiver.instance(context).setConnected(if (offline) false else null)
    }

    override fun setHttpHeaders(headers: Map<String, String>, callback: (Result<Unit>) -> Unit) =
        unit(callback) { MapLibreHttpRequestUtil.setHttpHeaders(headers, it) }

    override fun mergeOfflineRegions(path: String, callback: (Result<String>) -> Unit) =
        string(callback) { OfflineManagerUtils.mergeRegions(it, context, path) }

    override fun getOfflineDatabasePath(): String? {
        ensureMapLibre()
        return File(context.filesDir, DATABASE_NAME).absolutePath
    }

    override fun getListOfRegions(callback: (Result<String>) -> Unit) =
        string(callback) { OfflineManagerUtils.regionsList(it, context) }

    override fun updateOfflineRegionMetadata(
        id: Long,
        metadata: Map<String, Any?>,
        callback: (Result<String>) -> Unit,
    ) = string(callback) { OfflineManagerUtils.updateRegionMetadata(it, context, id, metadata) }

    override fun setOfflineTileCountLimit(limit: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.setOfflineTileCountLimit(it, context, limit) }

    override fun setOfflineMaxConcurrentRequests(
        maxRequests: Long?,
        maxRequestsPerHost: Long?,
        callback: (Result<Unit>) -> Unit,
    ) = unit(callback) {
        MapLibreHttpRequestUtil.setMaxConcurrentRequests(
            maxRequests?.toInt(),
            maxRequestsPerHost?.toInt(),
            it,
        )
    }

    override fun pauseOfflineRegionDownload(id: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.pauseRegion(it, context, id) }

    override fun resumeOfflineRegionDownload(id: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.resumeRegion(it, context, id) }

    override fun getOfflineRegionStatus(id: Long, callback: (Result<String>) -> Unit) =
        string(callback) { OfflineManagerUtils.getRegionStatus(it, context, id) }

    override fun deleteOfflineRegion(id: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.deleteRegion(it, context, id) }

    override fun clearAmbientCache(callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.clearAmbientCache(it, context) }

    override fun setMaximumAmbientCacheSize(bytes: Long, callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.setMaximumAmbientCacheSize(it, context, bytes) }

    override fun resetOfflineDatabase(callback: (Result<Unit>) -> Unit) =
        unit(callback) { OfflineManagerUtils.resetOfflineDatabase(it, context) }

    override fun downloadOfflineRegion(
        downloadId: Long,
        definition: Map<String, Any?>,
        metadata: Map<String, Any?>,
        callback: (Result<String>) -> Unit,
    ) = string(callback) {
        OfflineManagerUtils.downloadRegion(
            it,
            context,
            definition,
            metadata,
            OfflineDownloadEvents(downloadEvents, downloadId),
        )
    }

    /** Runs an operation that answers nothing through a [MethodChannel.Result]. */
    private fun unit(callback: (Result<Unit>) -> Unit, block: (MethodChannel.Result) -> Unit) =
        answer(PigeonMethodResult.unit(callback), block)

    /** Runs an operation that answers a JSON string through a [MethodChannel.Result]. */
    private fun string(callback: (Result<String>) -> Unit, block: (MethodChannel.Result) -> Unit) =
        answer(PigeonMethodResult.string(callback), block)

    // Pigeon does not catch what an asynchronous handler throws: it would reach
    // Dart as a channel-error. Report it with code "error", as the method
    // channel did.
    private fun answer(result: MethodChannel.Result, block: (MethodChannel.Result) -> Unit) {
        try {
            ensureMapLibre()
            block(result)
        } catch (e: RuntimeException) {
            result.error("error", e.message, Log.getStackTraceString(e))
        }
    }

    @Throws(IOException::class)
    private fun openTilesDbFile(tilesDb: String): InputStream {
        if (tilesDb.startsWith("/")) { // Absolute path.
            return FileInputStream(File(tilesDb))
        }
        return context.assets.open(flutterAssets.getAssetFilePathByName(tilesDb))
    }

    companion object {
        private const val TAG = "GlobalHostApi"
        private const val DATABASE_NAME = "mbgl-offline.db"
        private const val BUFFER_SIZE = 1024 * 2
    }
}
