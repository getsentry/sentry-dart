import Flutter
import Sentry
import UIKit

public class SwiftSentryFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftSentryFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

  override init() {
    SentrySDK.start { options in
        options.dsn = "https://39226a237e6b4fa5aae9191fa5732814@o19635.ingest.sentry.io/2078115"
        options.debug = true
        options.attachStacktrace = true
    }
  }
}
