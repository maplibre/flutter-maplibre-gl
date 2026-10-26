package org.maplibre.maplibregl

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Region metadata is read and written without crashing, and the SDK callbacks answer once. */
class OfflineManagerUtilsTest {
    private fun answers(block: (MethodChannel.Result) -> Unit): List<Result<String>> {
        val answers = mutableListOf<Result<String>>()
        block(PigeonMethodResult.string { answers.add(it) })
        return answers
    }

    @Test
    fun readsTheMetadataOfAJsonObject() {
        assertEquals(
            mapOf("name" to "Rome", "zoom" to 12.0),
            OfflineManagerUtils.metadataBytesToMap("""{"name":"Rome","zoom":12}""".toByteArray()),
        )
    }

    @Test
    fun readsMetadataThatIsNotAJsonObjectAsEmpty() {
        for (metadata in listOf("[]", "42", "\"text\"", "not json", "{", "", "null")) {
            assertEquals(metadata, emptyMap<String, Any>(), OfflineManagerUtils.metadataBytesToMap(metadata.toByteArray()))
        }
        assertEquals(emptyMap<String, Any>(), OfflineManagerUtils.metadataBytesToMap(null))
    }

    @Test
    fun writesMetadataAsJson() {
        val answers = mutableListOf<Result<String>>()
        val result = PigeonMethodResult.string { answers.add(it) }

        assertEquals("""{"name":"Rome"}""", OfflineManagerUtils.metadataToJson(mapOf("name" to "Rome"), result))
        assertEquals("{}", OfflineManagerUtils.metadataToJson(null, result))
        assertTrue(answers.isEmpty())
    }

    @Test
    fun metadataJsonCannotHoldIsAnInvalidArgument() {
        val answers = answers { assertNull(OfflineManagerUtils.metadataToJson(mapOf("zoom" to Double.NaN), it)) }

        val error = answers.single().exceptionOrNull() as PigeonError
        assertEquals("INVALID_ARGUMENT", error.code)
        assertEquals("Metadata is not JSON serializable", error.message)
    }

    @Test
    fun aCallbackThatThrowsAnswersWithCodeError() {
        val answers = answers { OfflineManagerUtils.guard(it) { throw IllegalStateException("boom") } }

        val error = answers.single().exceptionOrNull() as PigeonError
        assertEquals("error", error.code)
        assertEquals("boom", error.message)
        assertTrue((error.details as String).contains("IllegalStateException"))
    }

    @Test
    fun aCallbackThatThrowsAfterItsAnswerDoesNotAnswerAgain() {
        val answers = answers { result ->
            OfflineManagerUtils.guard(result) {
                result.success("[]")
                throw IllegalStateException("late")
            }
        }

        assertEquals(listOf("[]"), answers.map { it.getOrThrow() })
    }

    @Test
    fun aCallbackWithoutAResultThatThrowsDoesNotCrash() {
        OfflineManagerUtils.guard(null) { throw IllegalStateException("boom") }
    }
}
