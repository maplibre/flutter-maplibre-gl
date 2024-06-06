// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "maplibre_gl_ios",
    platforms: [
        .iOS("12.0"),
    ],
    products: [
        .library(name: "maplibre-gl-ios", targets: ["maplibre_gl_ios"])
    ],
    dependencies: [
        // When updating the dependency version,
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", exact: "6.4.2"),
    ],
    targets: [
        .target(
            name: "maplibre_gl_ios",
            dependencies: [
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution")
            ],
            cSettings: [
                .headerSearchPath("include/maplibre_gl_ios")
            ]
        )
    ]
)
