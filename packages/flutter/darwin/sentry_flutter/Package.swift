// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// sentry-cocoa's hybrid SDK tests replace everything between these markers to build
// against a local sentry-cocoa checkout. Keep both declarations inside the markers.
// BEGIN:SENTRY-COCOA
let sentryDependency: Package.Dependency = .package(
    url: "https://github.com/getsentry/sentry-apple-binaries", exact: "9.32.0"
)
let sentryProduct: Target.Dependency = .product(name: "Sentry-Static", package: "sentry-apple-binaries")
// END:SENTRY-COCOA

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
      .package(name: "FlutterFramework", path: "../FlutterFramework"),
      sentryDependency
    ],
    targets: [
        .target(
            name: "sentry_flutter",
            dependencies: [
                "sentry_flutter_objc",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                sentryProduct
            ]
        ),
        // SPM does not support mixed-language targets, so we need to move the ObjC files into a separate one
        .target(
            name: "sentry_flutter_objc",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                sentryProduct
            ]
        )
    ]
)
