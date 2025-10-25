// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StreamHaven",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17)
    ],
    products: [
        // Library product for modular reuse
        .library(
            name: "StreamHaven",
            targets: ["StreamHaven"]
        ),
        // iOS application product to enable reliable UI testing in CI
        .iOSApplication(
            name: "StreamHaven",
            targets: ["StreamHaven"],
            bundleIdentifier: "com.asrawiee.StreamHaven",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            supportedDeviceFamilies: [ .phone, .pad ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeLeft,
                .landscapeRight
            ]
        ),
        // tvOS application product for tvOS UI testing
        .tvOSApplication(
            name: "StreamHavenTV",
            targets: ["StreamHaven"],
            bundleIdentifier: "com.asrawiee.StreamHaven.tv",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon")
        )
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
        // UI tests are organized under StreamHavenUITests. Xcode will run these as UI tests.
        .testTarget(
            name: "StreamHavenUITests",
            dependencies: ["StreamHaven"],
            path: "StreamHavenUITests"
        ),
    ]
)
