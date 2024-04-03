// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PotentiometerView",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "PotentiometerView",
            targets: ["PotentiometerView"]),
    ],
    targets: [
        .target(
            name: "PotentiometerView"),
        .testTarget(
            name: "PotentiometerViewTests",
            dependencies: ["PotentiometerView"]),
    ]
)
