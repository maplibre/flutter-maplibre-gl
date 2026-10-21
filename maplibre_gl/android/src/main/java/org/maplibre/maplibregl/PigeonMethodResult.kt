package org.maplibre.maplibregl

import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Answers a Pigeon callback from code written against [MethodChannel.Result],
 * so the offline and HTTP helpers keep their signatures. [convert] turns the
 * success value into the type the Pigeon method returns.
 *
 * Only the first answer is delivered: a second one would be a second reply to
 * the same message.
 */
internal class PigeonMethodResult<T>(
    private val callback: (Result<T>) -> Unit,
    private val convert: (Any?) -> T,
) : MethodChannel.Result {
    private val answered = AtomicBoolean(false)

    override fun success(result: Any?) {
        if (answered.compareAndSet(false, true)) {
            // A value convert cannot read would otherwise leave the call
            // unanswered and Dart waiting forever.
            val value = try {
                convert(result)
            } catch (e: RuntimeException) {
                callback(Result.failure(PigeonError("error", e.message, null)))
                return
            }
            callback(Result.success(value))
        }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        if (answered.compareAndSet(false, true)) {
            callback(Result.failure(PigeonError(errorCode, errorMessage, errorDetails)))
        }
    }

    override fun notImplemented() {
        error("notImplemented", "Not implemented on Android.", null)
    }

    companion object {
        /** For Pigeon methods that return nothing. */
        fun unit(callback: (Result<Unit>) -> Unit) = PigeonMethodResult(callback) { }

        /** For Pigeon methods that return a JSON string. */
        fun string(callback: (Result<String>) -> Unit) =
            PigeonMethodResult(callback) { it as String }
    }
}
