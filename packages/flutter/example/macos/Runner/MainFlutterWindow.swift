import Cocoa
import FlutterMacOS
import Sentry

class MainFlutterWindow: NSWindow {
  private let _channel = "example.flutter.sentry.io"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // swiftlint:disable:next force_cast
    let controller = self.contentViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: _channel,
                                    binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler(handleMessage)

    super.awakeFromNib()
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
