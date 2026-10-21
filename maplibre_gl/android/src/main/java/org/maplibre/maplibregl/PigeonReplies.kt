package org.maplibre.maplibregl

/** Replies to the events sent to Dart through a Pigeon Flutter API. */
internal object PigeonReplies {
    /**
     * Drops the reply, as the method channel did for the events it sent
     * without a result. The Java callers pass it to the generated methods.
     */
    @JvmField
    val IGNORE: (Result<Unit>) -> Unit = { }
}
