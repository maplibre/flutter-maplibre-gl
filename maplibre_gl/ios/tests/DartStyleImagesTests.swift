import XCTest
@testable import StyleImageRetention

final class DartStyleImagesTests: XCTestCase {
    func testRegisteredImagesAreRetainedAndAssetsMayBeRemoved() {
        let images = DartStyleImages()
        images.register("dart-icon")
        XCTAssertFalse(images.canRemoveUnused("dart-icon"))
        XCTAssertTrue(images.canRemoveUnused("asset-icon"))
    }

    func testClearingStyleReleasesAllRegistrations() {
        let images = DartStyleImages()
        images.register("first")
        images.register("second")
        XCTAssertFalse(images.canRemoveUnused("first"))
        images.clear()
        XCTAssertTrue(images.canRemoveUnused("first"))
        XCTAssertTrue(images.canRemoveUnused("second"))
    }

    func testNextStyleCanRegisterOldAndNewNames() {
        let images = DartStyleImages()
        images.register("old")
        images.clear()
        images.register("new")
        XCTAssertTrue(images.canRemoveUnused("old"))
        XCTAssertFalse(images.canRemoveUnused("new"))
        images.register("old")
        XCTAssertFalse(images.canRemoveUnused("old"))
    }

    func testRepeatedRegistrationKeepsOwnership() {
        let images = DartStyleImages()
        XCTAssertTrue(images.register("same"))
        XCTAssertFalse(images.register("same"))
        XCTAssertFalse(images.canRemoveUnused("same"))
    }

    func testFailedNewRegistrationCanRollBackWithoutReleasingOthers() {
        let images = DartStyleImages()
        images.register("valid")
        images.register("failed")
        images.unregister("failed")
        XCTAssertTrue(images.canRemoveUnused("failed"))
        XCTAssertFalse(images.canRemoveUnused("valid"))
        // A failed update must not release an earlier successful registration.
        let introduced = images.register("valid")
        if introduced { images.unregister("valid") }
        XCTAssertFalse(images.canRemoveUnused("valid"))
    }

    func testControllersHaveIndependentRegistrations() {
        let first = DartStyleImages()
        let second = DartStyleImages()
        first.register("shared-name")
        XCTAssertFalse(first.canRemoveUnused("shared-name"))
        XCTAssertTrue(second.canRemoveUnused("shared-name"))
    }
}
