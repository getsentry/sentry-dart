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
    if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
      if let resource = NSDictionary(contentsOfFile: path) {
        if let dsn = resource.object(forKey: "SentryDsn") {
          SentrySDK.start { options in
              options.dsn = dsn as? String
              options.debug = resource["SentryDebug"] as? NSNumber ?? 0
              options.attachStacktrace = true
          }
        }
      }
    }
  }
}
