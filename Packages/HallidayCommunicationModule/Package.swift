// swift-tools-version: 5.9
// Filippos Pirpilidis
// Sr iOS Engineer
// f.pirpilidis@gmail.com
import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let opusLibPath = packageRoot + "/Sources/HallidayObjC/lib/libopus.a"

let package = Package(
    name: "HallidayCommunicationModule",
    platforms: [
        .iOS(.v16),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "HallidayCommunicationModule",
            targets: ["HallidayCommunicationModule"]
        )
    ],
    dependencies: [
        .package(name: "Core", path: "../Core")
    ],
    targets: [
        .target(
            name: "HallidayObjC",
            dependencies: [],
            path: "Sources/HallidayObjC",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .unsafeFlags([opusLibPath])
            ]
        ),
        .target(
            name: "HallidayCommunicationModule",
            dependencies: ["Core", "HallidayObjC"],
            path: "Sources/HallidayCommunicationModule"
        )
    ]
)
