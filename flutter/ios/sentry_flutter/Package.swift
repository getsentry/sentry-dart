// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "sentry_flutter",
    platforms: [
        .iOS("12.0"),
        .macOS("10.14")
    ],
    products: [
        .library(name: "sentry-flutter", targets: ["sentry_flutter", "sentry_flutter_objc"])
    ],
    dependencies: [
      .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.50.0")
    ],
    targets: [
        .target(
            name: "sentry_flutter",
            dependencies: [
                "sentry_flutter_objc",
                .product(name: "Sentry", package: "sentry-cocoa")
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
