// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlapMacClone",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SlapMacClone",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .unsafeFlags([
                    "-F/System/Library/PrivateFrameworks",
                    "-framework", "MultitouchSupport",
                ]),
            ]
        )
    ]
)
