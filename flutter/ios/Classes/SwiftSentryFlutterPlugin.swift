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
        if call.method == "initNativeSdk" {
            initNativeSdk(call, result: result)

        } else if call.method == "captureEnvelope"{
            captureEnvelope(call, result: result)
        }

    }

    private func initNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "0", message: "invalid args", details: nil) )
            return
        }

        if (arguments.isEmpty) {
            result("Arguments is null or empty")
            return
        }

        SentrySDK.start { options in
            options.dsn = arguments["dsn"] as? String
            options.debug = arguments["debug"] as? Bool ?? false
            options.environment = arguments["environment"] as? String
            options.releaseName = arguments["release"] as? String
            options.enableAutoSessionTracking = arguments["enableAutoSessionTracking"] as? Bool ?? false
            options.attachStacktrace = arguments["sessionTrackingIntervalMillis"] as? Bool ?? true
            options.sessionTrackingIntervalMillis = arguments["sessionTrackingIntervalMillis"] as? UInt ?? 30000
            options.dist = arguments["dist"] as? String
            options.integrations = arguments["integrations"] as? [String] ?? []
            options.maxBreadcrumbs = arguments["maxBreadcrumbs"] as? UInt ?? 100

            /*
             missing fields : enableAutoNativeBreadcrumbs, diagnostic level,
             enableNativeCrashHandling,platform, web, packages,anrTimeoutIntervalMillis
             diagnosticLevel, cacheDirSize
             */

            options.beforeSend = { event in
                self.setEventOriginTag(event: event)
                /// TODO ? addPackages, removeThreadsIfNotAndroid
                return event
            }
        }

        result("iOS initNativeSdk" )
    }

    private func setEventOriginTag(event: Event){
        guard let sdk = event.sdk else { return  };
        if self.isValidSdk(sdk:sdk){

            switch sdk["name"] as! String{
            case "sentry.dart.flutter":
                setEventEnvironmentTag(event:event,origin:"flutter",environment:"dart")
            case "sentry.cocoa":
                setEventEnvironmentTag(event:event,origin: "flutter",environment: "dart")
            case "sentry.native":
                setEventEnvironmentTag(event:event,origin: "flutter",environment: "dart")
            default:
                return
            }
        }
    }


    private func setEventEnvironmentTag(event: Event, origin: String = "ios", environment: String) {
        event.tags?["event.origin"] = origin
        event.tags?["event.environment"] = environment
    }

    private func isValidSdk( sdk: [String: Any]) -> Bool{
        return (sdk["name"] != nil && !(sdk["name"] as! String).isEmpty)
    }

    private func captureEnvelope(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        result("iOS captureEnvelope" )
    }

    /*override init() {
     if let path = Bundle.main.path(forResource: "Info", ofType: "plist") {
     if let resource = NSDictionary(contentsOfFile: path) {
     if let dsn = resource.object(forKey: "SentryDsn") {
     SentrySDK.start { options in
     options.dsn = dsn as? String
     options.debug = resource["SentryDebug"] as? Bool ?? false
     options.attachStacktrace = true
     }
     }
     }
     }
     }*/
}
