// swift-tools-version: 6.0
// Nuvio pin of AetherEngine 7.34.1 with local FFmpegBuild integrations.

import PackageDescription

let package = Package(
    name: "AetherEngine",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
        .macOS(.v15),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "AetherEngine",
            type: .static,
            targets: ["AetherEngine"]
        ),
        .library(
            name: "AetherEngineSMB",
            targets: ["AetherEngineSMB"]
        ),
    ],
    dependencies: [
        .package(path: "../FFmpegBuild"),
        .package(url: "https://github.com/kishikawakatsumi/SMBClient", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/superuser404notfound/LibDovi", .upToNextMinor(from: "2.1.0")),
        // 2.3.0: faster decode; 2.2.1+ exports rust_eh_personality weak (AE#752 link fix).
        .package(url: "https://github.com/superuser404notfound/LibTrueHD", .upToNextMinor(from: "2.3.0")),
        // DTS:X object decoder (AE PR #755, not yet merged upstream).
        .package(url: "https://github.com/kristofferR/LibDTSX", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "AetherEngine",
            dependencies: [
                .product(name: "AetherFFmpegBuild", package: "FFmpegBuild"),
                .product(name: "Dovi", package: "LibDovi"),
                .product(name: "TrueHD", package: "LibTrueHD"),
                .product(name: "DTSX", package: "LibDTSX"),
            ],
            // Silent E-AC-3 Atmos that `AtmosOutputActivator` loops beside an APAC track on tvOS.
            resources: [.copy("Resources/silent-atmos.mp4")],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("AudioToolbox"),
            ]
        ),
        .target(
            name: "AetherEngineSMB",
            dependencies: [
                "AetherEngine",
                .product(name: "SMBClient", package: "SMBClient"),
            ],
            path: "Sources/AetherEngineSMB"
        ),
        .executableTarget(
            name: "aetherctl",
            dependencies: ["AetherEngine", "AetherEngineSMB"],
            path: "Sources/aetherctl"
        ),
        .target(
            name: "ExampleSources",
            dependencies: ["AetherEngine"],
            path: "Examples",
            exclude: ["README.md", "DemoPlayerMac"]
        ),
        .testTarget(
            name: "AetherEngineTests",
            dependencies: ["AetherEngine"],
            path: "Tests/AetherEngineTests"
        ),
        .testTarget(
            name: "AetherEngineSMBTests",
            dependencies: ["AetherEngineSMB"],
            path: "Tests/AetherEngineSMBTests"
        ),
    ]
)
