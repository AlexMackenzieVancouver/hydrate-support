// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EarshotKit",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(name: "EarshotKit", targets: ["EarshotKit"])
    ],
    dependencies: [
        // Canon-authorized dependency. See canon/P4-technical/RFC.md §9.
        // MIT / Apache-2.0. On-device diarization + Parakeet ASR on the ANE.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.6.0")
    ],
    targets: [
        .target(
            name: "EarshotKit",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "EarshotKitTests",
            dependencies: ["EarshotKit"],
            resources: [.copy("Corpus")]
        )
    ]
)
