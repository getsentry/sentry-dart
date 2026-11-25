// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sentry_webview_flutter",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "sentry-webview-flutter", targets: ["sentry_webview_flutter"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "sentry_webview_flutter",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")]
        )
    ]
)
