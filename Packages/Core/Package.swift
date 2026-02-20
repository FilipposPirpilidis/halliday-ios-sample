// swift-tools-version: 5.9
// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        )
    ]
)
