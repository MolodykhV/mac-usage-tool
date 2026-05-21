// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PlumageBar",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "PlumageBar", targets: ["PlumageBar"]),
        .library(name: "PlumageBarCore", targets: ["PlumageBarCore"]),
    ],
    targets: [
        .executableTarget(
            name: "PlumageBar",
            dependencies: ["PlumageBarCore"],
            path: "Sources/PlumageBar",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .target(
            name: "PlumageBarCore",
            path: "Sources/PlumageBarCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        ),
        .testTarget(
            name: "PlumageBarCoreTests",
            dependencies: ["PlumageBarCore"],
            path: "Tests/PlumageBarCoreTests",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
    ]
)
