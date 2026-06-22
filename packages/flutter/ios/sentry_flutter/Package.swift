// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sentry_flutter",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0")
    ],
    products: [
        .library(name: "sentry-flutter", targets: ["sentry_flutter", "sentry_flutter_objc"])
    ],
    dependencies: [
      .package(url: "https://github.com/getsentry/sentry-cocoa", exact: "9.17.1")
    ],
    targets: [
        .target(
            name: "sentry_flutter",
            dependencies: [
                "sentry_flutter_objc",
                .product(name: "Sentry", package: "sentry-cocoa")
            ],
            swiftSettings: [
                .define("SENTRY_FLUTTER_SPM")
            ]
        ),
        // SPM does not support mixed-language targets, so we need to move the ObjC files into a separate one
        .target(
            name: "sentry_flutter_objc",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa")
            ]
        )
    ]
)
