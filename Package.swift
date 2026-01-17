// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SystemPulse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SystemPulse", targets: ["SystemPulse"])
    ],
    targets: [
        .executableTarget(
            name: "SystemPulse",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit")
            ]
        )
    ]
)
