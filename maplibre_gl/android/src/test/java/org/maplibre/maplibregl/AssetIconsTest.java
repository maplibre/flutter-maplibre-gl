package org.maplibre.maplibregl;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

import java.util.Arrays;
import java.util.NavigableSet;
import java.util.TreeSet;

/** AssetIcons picks the variant Flutter's AssetImage picks for the same density. */
public class AssetIconsTest {
  private static NavigableSet<Float> ratios(Float... values) {
    return new TreeSet<>(Arrays.asList(values));
  }

  @Test
  public void exactRatioWins() {
    assertEquals(2f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 2f), 0);
    assertEquals(3f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 3f), 0);
  }

  @Test
  public void belowTwoTheLargerRatioWins() {
    assertEquals(2f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 1.1f), 0);
    assertEquals(2f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 1.5f), 0);
  }

  @Test
  public void aboveTwoTheNearestRatioWins() {
    assertEquals(3f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 2.625f), 0);
    assertEquals(2f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 2.4f), 0);
    // Halfway keeps the smaller one.
    assertEquals(2f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 2.5f), 0);
  }

  @Test
  public void outsideTheRangeTheClosestEndWins() {
    assertEquals(3f, AssetIcons.bestRatio(ratios(1f, 2f, 3f), 3.5f), 0);
    assertEquals(2f, AssetIcons.bestRatio(ratios(2f, 3f), 1f), 0);
  }

  @Test
  public void mainFileAloneIsAlwaysPicked() {
    assertEquals(1f, AssetIcons.bestRatio(ratios(1f), 2.75f), 0);
  }
}
