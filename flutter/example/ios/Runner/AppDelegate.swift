import UIKit
import Flutter
import Sentry

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let _channel = "example.flutter.sentry.io"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    let channel = FlutterMethodChannel(name: _channel,
                            binaryMessenger: controller.binaryMessenger)
    channel.setMethodCallHandler(handleMessage)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleMessage(call: FlutterMethodCall, result: FlutterResult) {
    if call.method == "fatalError" {
      fatalError("fatalError")
    } else if call.method == "crash" {
      SentrySDK.crash()
    } else if call.method == "capture" {
      let exception = NSException(
        name: NSExceptionName("NSException"),
        reason: "Swift NSException Captured",
        userInfo: ["details": "lots"])
      SentrySDK.capture(exception: exception)
    } else if call.method == "capture_message" {
      SentrySDK.capture(message: "A message from Swift.")
    } else if call.method == "throw" {
      Buggy.throw()
    }
  }
}
