// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DodoCheckout",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "DodoCheckout",
            targets: ["DodoCheckout"]
        )
    ],
    targets: [
        .target(
            name: "DodoCheckout",
            dependencies: [],
            path: "Sources/DodoCheckout",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                // SE-0461 / SE-0470 — approachable concurrency without
                // defaulting the whole library to MainActor (pure parsers
                // and validators stay nonisolated).
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        ),
        .testTarget(
            name: "DodoCheckoutTests",
            dependencies: ["DodoCheckout"],
            path: "Tests/DodoCheckoutTests",
            swiftSettings: [
                .swiftLanguageMode(.v6),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        )
    ]
)
