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
    dependencies: [
        // Crash reporting & performance monitoring
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.30.0")
    ],
    targets: [
        .target(
            name: "StreamHaven",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
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
