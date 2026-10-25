// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuietNumbersCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "QuietNumbersCore", targets: ["QuietNumbersCore"]),
    ],
    targets: [
        .target(name: "QuietNumbersCore"),
        .testTarget(name: "QuietNumbersCoreTests", dependencies: ["QuietNumbersCore"]),
    ]
)
