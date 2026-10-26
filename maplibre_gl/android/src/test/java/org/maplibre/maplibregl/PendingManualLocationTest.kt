package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.function.Consumer

/** A manual location sent while the puck is hidden waits for it, and only the newest one does. */
class PendingManualLocationTest {
    private val shown = mutableListOf<String>()
    private val show = Consumer<String> { shown.add(it) }
    private val pending = PendingManualLocation<String>()

    @Test
    fun aVisiblePuckShowsTheLocationAtOnce() {
        pending.offer("rome", true, show)

        assertEquals(listOf("rome"), shown)
    }

    @Test
    fun aHiddenPuckShowsTheNewestLocationOnceVisible() {
        pending.offer("rome", false, show)
        pending.offer("milan", false, show)
        assertEquals(emptyList<String>(), shown)

        pending.flush(show)
        pending.flush(show)

        assertEquals(listOf("milan"), shown)
    }

    @Test
    fun aLocationShownLaterDropsTheOneThatWaited() {
        pending.offer("rome", false, show)
        pending.offer("milan", true, show)

        pending.flush(show)

        assertEquals(listOf("milan"), shown)
    }

    @Test
    fun withNothingWaitingFlushShowsNothing() {
        pending.flush(show)

        assertEquals(emptyList<String>(), shown)
    }
}
