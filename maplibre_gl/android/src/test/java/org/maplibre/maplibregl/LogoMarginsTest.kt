package org.maplibre.maplibregl

import org.junit.Assert.assertArrayEquals
import org.junit.Test
import org.maplibre.android.maps.MapLibreMapOptions

/** The logo margins push the logo away from the corner it sits in, as the compass ones do. */
class LogoMarginsTest {
    /** The left, top, right and bottom margins the builder hands the map for [position]. */
    private fun logoMargins(position: Int?): IntArray {
        val builder = MapLibreMapBuilder()
        position?.let { builder.setLogoViewGravity(it) }
        builder.setLogoViewMargins(16, 8)
        val options = MapLibreMapBuilder::class.java.getDeclaredField("options")
        options.isAccessible = true
        return (options.get(builder) as MapLibreMapOptions).logoMargins
    }

    @Test
    fun theMarginsFollowThePosition() {
        assertArrayEquals(intArrayOf(16, 8, 0, 0), logoMargins(0)) // top left
        assertArrayEquals(intArrayOf(0, 8, 16, 0), logoMargins(1)) // top right
        assertArrayEquals(intArrayOf(16, 0, 0, 8), logoMargins(2)) // bottom left
        assertArrayEquals(intArrayOf(0, 0, 16, 8), logoMargins(3)) // bottom right
        // Bottom left is where the logo sits by default.
        assertArrayEquals(intArrayOf(16, 0, 0, 8), logoMargins(null))
    }
}
