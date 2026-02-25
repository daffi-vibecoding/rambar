// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RamBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RamBar", targets: ["RamBar"])
    ],
    targets: [
        .executableTarget(
            name: "RamBar",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
