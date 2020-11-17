import Flutter
import Sentry
import UIKit

public class SwiftSentryFlutterPlugin: NSObject, FlutterPlugin {
    var options: Options?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftSentryFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method as String{
            case "initNativeSdk" :
            initNativeSdk(call, result: result)
                break

        case "captureEnvelope" :
            captureEnvelope(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }


    }

    private func initNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "4", message: "Arguments is null or empty", details: nil) )
            return
        }

        if (arguments.isEmpty) {
            result(FlutterError(code: "4", message: "Arguments is null or empty", details: nil) )
            return
        }

        SentrySDK.start { options in
            if(arguments["dsn"] != nil ){
                options.dsn = arguments["dsn"] as? String
            } else {
                result(FlutterError(code: "4", message: "A valid Dsn must be provided", details: nil) )
            }
            if let isDebug = arguments["debug"] as? Bool {
                options.debug = isDebug
            }

            if let environment = arguments["environment"] as? String{
                options.environment = environment
            }
            if let releaseName = arguments["release"] as? String{
                options.releaseName = releaseName
            }

            if let enableAutoSessionTracking = arguments["enableAutoSessionTracking"] as? Bool {
                options.enableAutoSessionTracking = enableAutoSessionTracking
            }

            if let attachStacktrace = arguments["attachStacktrace"] as? Bool {
                print("attachStacktrace \(attachStacktrace)")
                options.attachStacktrace = attachStacktrace
            }

            if let sessionTrackingIntervalMillis = arguments["sessionTrackingIntervalMillis"] as? UInt{
                options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
            }

            if let dist = arguments["dist"] as? String{
                options.dist = dist
            }

            if let integrations = arguments["integrations"] as? [String]{
                options.integrations?.append(contentsOf: integrations)
            }

            if let enableAutoNativeBreadcrumbs = arguments["enableAutoNativeBreadcrumbs"] as? Bool,
               enableAutoNativeBreadcrumbs == false {
                options.integrations = options.integrations?.filter { (name) -> Bool in
                    return name != "SentryAutoBreadcrumbTrackingIntegration"
                }
            }

            if let maxBreadcrumbs = arguments["maxBreadcrumbs"] as? UInt{
                options.maxBreadcrumbs = maxBreadcrumbs
            }

            /*
             missing fields : enableAutoNativeBreadcrumbs, diagnostic level,
             enableNativeCrashHandling,platform, web, packages,anrTimeoutIntervalMillis
             diagnosticLevel, cacheDirSize
             */

            options.beforeSend = { event in
                self.setEventOriginTag(event: event)
                /// TODO ? addPackages
                return event
            }

            self.options = options
        }

        result("iOS initNativeSdk" )
    }

    private func setEventOriginTag(event: Event){
        guard let sdk = event.sdk else { return  }
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

    func convertStringToDictionary(text: String) -> [String:AnyObject]? {
        if let data = text.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String:AnyObject]
                return json
            } catch {
                print("Something went wrong")
            }
        }
        return nil
    }

    private func captureEnvelope(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let arguments = call.arguments as? [Any],
              !arguments.isEmpty,
              let event = arguments.first as? String else {
            result(FlutterError(code: "2", message: "Envelope is null or empty", details: nil) )
            return
        }

        let parts = event.split(separator: "\n")
        let envelopeParts: [[String: Any]] = parts.map ({ part in
            convertStringToDictionary(text: "\(part)")!
        })

        let envelopeHeaderDict = envelopeParts[0]
        let eventSdk = envelopeHeaderDict
        let itemHeader = envelopeParts[1]

        guard
              let eventId = envelopeHeaderDict["event_id"] as? String,
              let itemType = itemHeader["type"] as? String else {
            result(FlutterError(code: "2", message: "Cannot serialize event", details: nil) )
            return
        }

        let sdkInfo = SentrySdkInfo(dict: eventSdk)
        let sentryId = SentryId(uuidString: eventId)
        let envelopeHeader = SentryEnvelopeHeader.init(id: sentryId, andSdkInfo: sdkInfo)

        let data = NSKeyedArchiver.archivedData(withRootObject: envelopeParts[2])
        let sentryItemHeader = SentryEnvelopeItemHeader(type: itemType, length: UInt(data.count))
        let sentryEnvelopeItem = SentryEnvelopeItem( header: sentryItemHeader, data: data)

        let envelope = SentryEnvelope.init(header: envelopeHeader, singleItem: sentryEnvelopeItem)
        SentrySDK.currentHub().getClient()?.capture(envelope: envelope)

        result("")
        //result(FlutterError(code: "2", message: "Cannot serialize event payload", details: nil) )
    }

    private func writeEnvelope(envelope: String) -> Bool{
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = dir.appendingPathComponent(UUID().uuidString)
            do{
                try envelope.write(to: filePath, atomically: false, encoding: .utf8)
                return true
            } catch {
                print("writeEnvelope fail")
                // logger ?
            }
        }
        return false
    }
}
