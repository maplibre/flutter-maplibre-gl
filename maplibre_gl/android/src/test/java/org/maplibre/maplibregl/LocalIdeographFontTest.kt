package org.maplibre.maplibregl

import org.junit.Assert.assertEquals
import org.junit.Test
import org.maplibre.android.constants.MapLibreConstants
import org.maplibre.android.maps.MapLibreMapOptions

/**
 * CJK labels are drawn with a device font, as a MapView built from XML
 * attributes does, so they do not need their glyph ranges from the style.
 */
class LocalIdeographFontTest {
    @Test
    fun theBuilderUsesTheDefaultLocalIdeographFont() {
        val builder = MapLibreMapBuilder()
        val field = MapLibreMapBuilder::class.java.getDeclaredField("options")
        field.isAccessible = true
        val options = field.get(builder) as MapLibreMapOptions
        assertEquals(MapLibreConstants.DEFAULT_FONT, options.localIdeographFontFamily)
    }
}
