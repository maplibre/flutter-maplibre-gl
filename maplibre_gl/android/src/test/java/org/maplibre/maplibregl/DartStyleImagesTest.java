package org.maplibre.maplibregl;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public final class DartStyleImagesTest {
  @Test
  public void registeredImagesAreRetainedAndAssetImagesMayBeRemoved() {
    DartStyleImages images = new DartStyleImages();
    images.register("dart-icon");
    assertFalse(images.canRemoveUnused("dart-icon"));
    assertTrue(images.canRemoveUnused("asset-icon"));
  }

  @Test
  public void clearingAStyleReleasesAllRegistrations() {
    DartStyleImages images = new DartStyleImages();
    images.register("first");
    images.register("second");
    assertFalse(images.canRemoveUnused("first"));
    images.clear();
    assertTrue(images.canRemoveUnused("first"));
    assertTrue(images.canRemoveUnused("second"));
  }

  @Test
  public void nextStyleCanRegisterBothOldAndNewNames() {
    DartStyleImages images = new DartStyleImages();
    images.register("old");
    images.clear();
    images.register("new");
    assertTrue(images.canRemoveUnused("old"));
    assertFalse(images.canRemoveUnused("new"));
    images.register("old");
    assertFalse(images.canRemoveUnused("old"));
  }

  @Test
  public void repeatedRegistrationDoesNotReplaceExistingOwnership() {
    DartStyleImages images = new DartStyleImages();
    assertTrue(images.register("same"));
    assertFalse(images.register("same"));
    assertFalse(images.canRemoveUnused("same"));
  }

  @Test
  public void failedNewRegistrationCanBeRolledBackWithoutReleasingOthers() {
    DartStyleImages images = new DartStyleImages();
    images.register("valid");
    images.register("failed");
    images.unregister("failed");
    assertTrue(images.canRemoveUnused("failed"));
    assertFalse(images.canRemoveUnused("valid"));
    // A failed update must keep an earlier successful registration.
    boolean newlyRegistered = images.register("valid");
    if (newlyRegistered) {
      images.unregister("valid");
    }
    assertFalse(images.canRemoveUnused("valid"));
  }

  @Test
  public void controllersHaveIndependentRegistrations() {
    DartStyleImages first = new DartStyleImages();
    DartStyleImages second = new DartStyleImages();
    first.register("shared-name");
    assertFalse(first.canRemoveUnused("shared-name"));
    assertTrue(second.canRemoveUnused("shared-name"));
  }
}
