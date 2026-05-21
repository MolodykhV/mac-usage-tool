// swift-tools-version:6.0
import PackageDescription

let coreSwiftSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
]

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
            swiftSettings: coreSwiftSettings
        ),
        // The IOReport SPI is exposed as `/usr/lib/libIOReport.dylib` on macOS
        // 26+ (it was a PrivateFramework on earlier releases). The shared
        // library is in the dyld cache; we just link `-lIOReport`. The few
        // entry points we need are declared in Sources/CIOReport/include
        // /CIOReport.h.
        .target(
            name: "CIOReport",
            path: "Sources/CIOReport",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("IOReport")
            ]
        ),
        .target(
            name: "PlumageBarCore",
            dependencies: ["CIOReport"],
            path: "Sources/PlumageBarCore",
            swiftSettings: coreSwiftSettings
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
