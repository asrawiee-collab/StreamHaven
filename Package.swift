// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StreamHaven",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "StreamHaven",
            targets: ["StreamHaven"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StreamHaven",
            dependencies: [],
            path: "StreamHaven"
        ),
        .testTarget(
            name: "StreamHavenTests",
            dependencies: ["StreamHaven"],
            path: "StreamHaven/Tests",
            resources: [
                .copy("../Resources")
            ]
        ),
    ]
)
