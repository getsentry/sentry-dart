import UIKit
import Flutter
import Sentry

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let _channel = "example.flutter.sentry.io"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // With the UIScene life cycle (required by the iOS 27 SDK), the window and
  // engine don't exist yet in didFinishLaunching, so register plugins and the
  // method channel once Flutter has created its implicit engine.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: _channel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler(handleMessage)
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
