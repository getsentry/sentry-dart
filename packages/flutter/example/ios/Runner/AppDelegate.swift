import UIKit
import Flutter
import Sentry

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let _channel = "example.flutter.sentry.io"

  private var probeSpan: Span?

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
    if call.method == "startProfileProbe" {
      UIApplication.shared.isIdleTimerDisabled = true
      SentrySDK.startProfiler()
      probeSpan = SentrySDK.startTransaction(name: "Flutter XR AOT workload", operation: "profile.probe")
      result(nil)
    } else if call.method == "stopProfileProbe" {
      probeSpan?.finish()
      probeSpan = nil
      SentrySDK.stopProfiler()
      DispatchQueue.main.asyncAfter(deadline: .now() + 35) {
        UIApplication.shared.isIdleTimerDisabled = false
      }
      result(nil)
    } else if call.method == "fatalError" {
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
