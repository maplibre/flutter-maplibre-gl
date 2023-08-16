package com.mapbox.mapboxgl

import com.google.gson.Gson
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink

class OfflineChannelHandlerImpl(messenger: BinaryMessenger, channelName: String) :
    EventChannel.StreamHandler {
    private var sink: EventSink? = null
    private val gson = Gson()

    init {
        val eventChannel = EventChannel(messenger, channelName)
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any, events: EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any) {
        sink = null
    }

    fun onError(errorCode: String?, errorMessage: String?, errorDetails: Any?) {
        if (sink == null) return
        sink!!.error(errorCode, errorMessage, errorDetails)
    }

    fun onSuccess() {
        if (sink == null) return
        val body = mapOf("status" to "success")
        sink!!.success(gson.toJson(body))
    }

    fun onStart() {
        if (sink == null) return
        val body = mapOf("status" to "start")
        sink!!.success(gson.toJson(body))
    }

    fun onProgress(progress: Double) {
        if (sink == null) return
        val body = mapOf("status" to "progress", "progress" to progress)

        sink!!.success(gson.toJson(body))
    }
}