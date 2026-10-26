package org.maplibre.maplibregl

import io.flutter.plugin.common.MethodChannel
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.lang.reflect.Proxy
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/**
 * The HTTP settings of every call end up in one client, and OkHttp's threads read them while Dart
 * changes them.
 */
class MapLibreHttpRequestUtilTest {
    // Read by the request thread of the last test.
    private val installed = CopyOnWriteArrayList<OkHttpClient>()

    @Before
    fun setUp() {
        MapLibreHttpRequestUtil.resetForTest()
        MapLibreHttpRequestUtil.install = java.util.function.Consumer { installed.add(it) }
    }

    @After
    fun tearDown() {
        MapLibreHttpRequestUtil.resetForTest()
    }

    /** The answers [block] gives through a MethodChannel.Result: a success value or an error. */
    private fun answers(block: (MethodChannel.Result) -> Unit): List<Result<Unit>> {
        val answers = mutableListOf<Result<Unit>>()
        block(PigeonMethodResult.unit { answers.add(it) })
        return answers
    }

    private fun succeeds(block: (MethodChannel.Result) -> Unit) =
        assertTrue(answers(block).single().isSuccess)

    private fun failure(block: (MethodChannel.Result) -> Unit): PigeonError =
        answers(block).single().exceptionOrNull() as PigeonError

    /** The request the network interceptor of [client] sends for [url]. */
    private fun sent(client: OkHttpClient, url: String): Request {
        val sent = AtomicReference<Request>()
        val request = Request.Builder().url(url).header("Keep", "me").build()
        val chain = Proxy.newProxyInstance(
            Interceptor.Chain::class.java.classLoader,
            arrayOf(Interceptor.Chain::class.java),
        ) { _, method, args ->
            when (method.name) {
                "request" -> request
                "proceed" -> {
                    sent.set(args!![0] as Request)
                    Response.Builder()
                        .request(args[0] as Request)
                        .protocol(Protocol.HTTP_1_1)
                        .code(200)
                        .message("OK")
                        .build()
                }
                else -> throw UnsupportedOperationException(method.name)
            }
        } as Interceptor.Chain
        client.networkInterceptors.single().intercept(chain)
        return sent.get()
    }

    @Test
    fun theLimitsKeepTheGlobalHeaders() {
        succeeds { MapLibreHttpRequestUtil.setHttpHeaders(mapOf("Authorization" to "Bearer a"), it) }
        succeeds { MapLibreHttpRequestUtil.setMaxConcurrentRequests(8L, 2L, it) }

        val client = installed.last()
        assertEquals(8, client.dispatcher.maxRequests)
        assertEquals(2, client.dispatcher.maxRequestsPerHost)
        assertEquals("Bearer a", sent(client, "https://tiles.example/1.pbf").header("Authorization"))
    }

    @Test
    fun theCustomHeadersAndTheGlobalHeadersKeepEachOther() {
        succeeds { MapLibreHttpRequestUtil.setMaxConcurrentRequests(null, 3L, it) }
        succeeds {
            MapLibreHttpRequestUtil.setCustomHeaders(
                mapOf("X-Tile" to "t", "Shared" to "custom"),
                listOf("https://tiles\\.example/.*"),
                it,
            )
        }
        succeeds {
            MapLibreHttpRequestUtil.setHttpHeaders(mapOf("X-Global" to "g", "Shared" to "global"), it)
        }

        val client = installed.last()
        assertEquals(3, client.dispatcher.maxRequestsPerHost)
        val tile = sent(client, "https://tiles.example/1.pbf")
        assertEquals("g", tile.header("X-Global"))
        assertEquals("t", tile.header("X-Tile"))
        assertEquals("custom", tile.header("Shared"))
        assertEquals("me", tile.header("Keep"))
        val style = sent(client, "https://styles.example/style.json")
        assertEquals("g", style.header("X-Global"))
        assertNull(style.header("X-Tile"))
        assertEquals("global", style.header("Shared"))
    }

    @Test
    fun anEmptyValueRemovesTheHeader() {
        succeeds { MapLibreHttpRequestUtil.setHttpHeaders(mapOf("Keep" to " "), it) }

        assertNull(sent(installed.last(), "https://tiles.example/1.pbf").header("Keep"))
    }

    @Test
    fun aFilterPatternThatDoesNotCompileMatchesNothing() {
        succeeds { MapLibreHttpRequestUtil.setCustomHeaders(mapOf("X-Tile" to "t"), listOf("(["), it) }

        assertNull(sent(installed.last(), "https://tiles.example/1.pbf").header("X-Tile"))
    }

    @Test
    fun withoutLimitsThePerHostLimitIsTheOneOfTheSdk() {
        succeeds { MapLibreHttpRequestUtil.setHttpHeaders(mapOf("A" to "b"), it) }

        assertEquals(20, installed.last().dispatcher.maxRequestsPerHost)
        assertEquals(64, installed.last().dispatcher.maxRequests)
    }

    @Test
    fun aLimitOutsideAnIntIsRejectedAndChangesNothing() {
        succeeds { MapLibreHttpRequestUtil.setMaxConcurrentRequests(8L, null, it) }
        installed.clear()

        for ((maxRequests, maxRequestsPerHost) in listOf(
            4_294_967_297L to null,
            null to 4_294_967_297L,
            0L to null,
            null to -1L,
        )) {
            val error = failure {
                MapLibreHttpRequestUtil.setMaxConcurrentRequests(maxRequests, maxRequestsPerHost, it)
            }
            assertEquals("INVALID_ARGUMENT", error.code)
        }
        assertEquals(emptyList<OkHttpClient>(), installed)

        succeeds { MapLibreHttpRequestUtil.setHttpHeaders(emptyMap(), it) }
        assertEquals(8, installed.last().dispatcher.maxRequests)
    }

    @Test
    fun aClientThatCannotBeInstalledAnswersHttpClientError() {
        MapLibreHttpRequestUtil.install = java.util.function.Consumer { throw IllegalStateException("no") }

        assertEquals("HTTP_CLIENT_ERROR", failure { MapLibreHttpRequestUtil.setHttpHeaders(emptyMap(), it) }.code)
    }

    @Test
    fun answersTheCustomHeadersAsTheyWereSet() {
        succeeds { MapLibreHttpRequestUtil.setCustomHeaders(mapOf("A" to "1"), emptyList(), it) }
        succeeds { MapLibreHttpRequestUtil.setHttpHeaders(mapOf("B" to "2"), it) }

        assertEquals(mapOf("A" to "1"), MapLibreHttpRequestUtil.getCustomHeaders())
    }

    @Test
    fun requestsReadTheHeadersWhileDartChangesThem() {
        succeeds { MapLibreHttpRequestUtil.setCustomHeaders(mapOf("A" to "0"), listOf(".*"), it) }
        val crash = AtomicReference<Throwable>()
        val running = AtomicBoolean(true)
        val requests = thread {
            try {
                while (running.get()) {
                    sent(installed.last(), "https://tiles.example/1.pbf")
                }
            } catch (e: Throwable) {
                crash.set(e)
            }
        }

        for (i in 1..2_000) {
            val headers = (0..i % 20).associate { "H$it" to "$i" }
            succeeds { MapLibreHttpRequestUtil.setCustomHeaders(headers, listOf(".*", "x$i"), it) }
        }
        running.set(false)
        requests.join()

        assertNull(crash.get())
    }
}
