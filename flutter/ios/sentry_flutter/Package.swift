// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sentry_flutter",
    platforms: [
        .iOS("12.0"),
        .macOS("10.13")
    ],
    products: [
        .library(name: "sentry-flutter", targets: ["sentry_flutter", "sentry_flutter_swift"])
    ],
    dependencies: [
      .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.36.0"),
    ],
    targets: [
        .target(
            name: "sentry_flutter",
            dependencies: [
                "sentry_flutter_swift",
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            publicHeadersPath:"include"
        ),
        // SPM does not support mixed-language, so we need to move the swift files into a separate target
        .target(
            name: "sentry_flutter_swift",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            publicHeadersPath:"include"
        )
    ]
)
