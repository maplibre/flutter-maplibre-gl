// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "maplibre_gl",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "maplibre-gl", targets: ["maplibre_gl"])
    ],
    dependencies: [
        // When updating the dependency version,
        // make sure to also update the version in maplibre_gl.podspec.
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", exact: "6.31.0"),
    ],
    targets: [
        .target(
            name: "maplibre_gl",
            dependencies: [
                "maplibre_gl_objc",
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution")
            ]
        ),
        // Catches the Objective-C exceptions MapLibre raises, which Swift cannot.
        .target(name: "maplibre_gl_objc")
    ]
)
