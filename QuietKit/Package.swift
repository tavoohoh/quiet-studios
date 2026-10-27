// swift-tools-version: 6.0
import PackageDescription

/// Shared by every Quiet Studios app. `QuietCore` is pure logic (no UI, no GameKit) and is
/// tested with `swift test`; `QuietUI` is the design system and services, built by each app.
let package = Package(
    name: "QuietKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "QuietCore", targets: ["QuietCore"]),
        .library(name: "QuietUI", targets: ["QuietUI"]),
    ],
    targets: [
        .target(name: "QuietCore"),
        .target(name: "QuietUI", dependencies: ["QuietCore"]),
        .testTarget(name: "QuietCoreTests", dependencies: ["QuietCore"]),
    ]
)
