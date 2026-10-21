package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** How PigeonMethodResult hands a MethodChannel.Result answer to a Pigeon callback. */
class PigeonMethodResultTest {
    private val answers = mutableListOf<Result<Any?>>()

    private fun lengthOfString() =
        PigeonMethodResult<Int>({ answers.add(it) }) { (it as String).length }

    private fun singleError(): PigeonError {
        assertEquals(1, answers.size)
        val error = answers.single().exceptionOrNull()
        assertTrue("expected a PigeonError, got $error", error is PigeonError)
        return error as PigeonError
    }

    @Test
    fun successDeliversTheConvertedValue() {
        lengthOfString().success("four")

        assertEquals(listOf(Result.success(4)), answers)
    }

    @Test
    fun aValueConvertCannotReadFailsTheCall() {
        lengthOfString().success(42)

        assertEquals("error", singleError().code)
    }

    @Test
    fun onlyTheFirstSuccessIsDelivered() {
        val result = lengthOfString()

        result.success("one")
        result.success("three")
        result.error("late", "too late", null)
        result.notImplemented()

        assertEquals(listOf(Result.success(3)), answers)
    }

    @Test
    fun onlyTheFirstErrorIsDelivered() {
        val result = lengthOfString()

        result.error("first", "the first error", null)
        result.success("four")
        result.error("second", "the second error", null)
        result.notImplemented()

        assertEquals("first", singleError().code)
    }

    @Test
    fun errorBecomesAPigeonErrorWithItsCodeMessageAndDetails() {
        val details = mapOf("id" to 9)

        lengthOfString().error("UpdateMetadataError", "There is no region with the id 9.", details)

        val error = singleError()
        assertEquals("UpdateMetadataError", error.code)
        assertEquals("There is no region with the id 9.", error.message)
        assertEquals(details, error.details)
    }

    @Test
    fun notImplementedBecomesAPigeonErrorWithCodeNotImplemented() {
        lengthOfString().notImplemented()

        val error = singleError()
        assertEquals("notImplemented", error.code)
        assertEquals("Not implemented on Android.", error.message)
        assertNull(error.details)
    }

    @Test
    fun unitDeliversUnitWhateverTheValue() {
        PigeonMethodResult.unit { answers.add(it) }.success(null)
        PigeonMethodResult.unit { answers.add(it) }.success("ignored")

        assertEquals(listOf(Result.success(Unit), Result.success(Unit)), answers)
    }

    @Test
    fun unitDeliversErrors() {
        PigeonMethodResult.unit { answers.add(it) }.error("code", "message", null)

        assertEquals("code", singleError().code)
    }

    @Test
    fun stringDeliversTheString() {
        PigeonMethodResult.string { answers.add(it) }.success("[{\"id\":1}]")

        assertEquals(listOf(Result.success("[{\"id\":1}]")), answers)
    }

    @Test
    fun stringDeliversErrors() {
        PigeonMethodResult.string { answers.add(it) }.error("code", "message", 42)

        val error = singleError()
        assertEquals("code", error.code)
        assertEquals(42, error.details)
    }

    @Test
    fun stringFailsTheCallOnNull() {
        PigeonMethodResult.string { answers.add(it) }.success(null)

        assertEquals("error", singleError().code)
    }
}
