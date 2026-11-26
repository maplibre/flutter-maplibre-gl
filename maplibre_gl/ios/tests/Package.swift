// swift-tools-version: 5.9
import PackageDescription

// run_style_image_tests.sh copies this harness and the exact production helper
// into a temporary directory, without resolving the iOS SDK or Flutter package.
let package = Package(
    name: "StyleImageRetention",
    products: [.library(name: "StyleImageRetention", targets: ["StyleImageRetention"])],
    targets: [
        .target(name: "StyleImageRetention"),
        .testTarget(name: "StyleImageRetentionTests", dependencies: ["StyleImageRetention"]),
    ]
)
