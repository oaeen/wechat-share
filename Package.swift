// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatArchive",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ChatArchive", targets: ["ChatArchiveApp"]),
        .executable(name: "ChatArchiveShare", targets: ["ChatArchiveShare"]),
        .library(name: "ChatArchiveCore", targets: ["ChatArchiveCore"]),
    ],
    targets: [
        .target(
            name: "ChatArchiveCore",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .unsafeFlags(["-application-extension"]),
            ]
        ),
        .executableTarget(
            name: "ChatArchiveApp",
            dependencies: ["ChatArchiveCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ChatArchiveShare",
            dependencies: ["ChatArchiveCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-application-extension"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain",
                    "-Xlinker", "-application_extension",
                ])
            ]
        ),
        .testTarget(
            name: "ChatArchiveCoreTests",
            dependencies: ["ChatArchiveCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
