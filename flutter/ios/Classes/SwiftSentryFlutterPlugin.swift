import Flutter
import Sentry
import UIKit

public class SwiftSentryFlutterPlugin: NSObject, FlutterPlugin {

    var sentryOptions: Options?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftSentryFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method as String{
            case "deviceInfos" :
              deviceInfos(result: result)
              break

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

    private func deviceInfos(result: @escaping FlutterResult){
        SentrySDK.configureScope{ scope in
            let serializedScope = scope.serialize()
            let context = serializedScope["context"]

            var infos = ["contexts":context]
            // TODO DEBUG context

            if let integrations = self.sentryOptions?.integrations {
                infos["integrations"] = integrations
            }

            //infos["package"] = ["version": SentryMeta.versionString ,"sdk_name":"cocoapods:\(SentryMeta.sdkName)"]

            // TODO add sdk.packages
            result(infos)
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
            if let dsn = arguments["dsn"] as? String {
                options.dsn = dsn
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
                options.attachStacktrace = attachStacktrace
            }

            if let diagnosticLevel = arguments["diagnosticLevel"] as? String, options.debug == true {
                options.logLevel = self.logLevelFrom(diagnosticLevel: diagnosticLevel)
            }

            if let sessionTrackingIntervalMillis = arguments["sessionTrackingIntervalMillis"] as? UInt{
                options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
            }

            if let dist = arguments["dist"] as? String{
                options.dist = dist
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

            self.sentryOptions = options
            /*
             TODO : beforeSend alternative =>
              - eventOrigin
             */

            // note : for now, in sentry-cocoa, beforeSend is not called before captureEnvelope
            options.beforeSend = { event in
                self.setEventOriginTag(event: event)

                if let sdk = event.sdk, self.isValidSdk(sdk: sdk){
                    if let packages = arguments["packages"] as? [String]{
                        if  var sdkPackages = sdk["packages"] as? [String]{
                            event.sdk!["packages"] = sdkPackages.append(contentsOf: packages)
                        } else {
                            event.sdk = ["packages":packages]
                        }
                    }

                    if let integrations = arguments["integrations"] as? [String]{
                        if  var sdkIntegrations = sdk["integrations"] as? [String]{
                            event.sdk!["integrations"] = sdkIntegrations.append(contentsOf: integrations)
                        } else {
                            event.sdk = ["integrations":integrations]
                        }
                    }
                }
                return event
            }
        }

        result("" )
    }
    
    private func logLevelFrom(diagnosticLevel:String)->SentryLogLevel{
        switch (diagnosticLevel) {
        case "fatal", "error":
            return .error
            break;
        case "debug":
            return .debug
            break;
        case "warning", "info":
            return .verbose
            break;
        default:
            return .none
            break;
        }
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

    func convertStringToDictionary(text: String) -> [String:Any]? {
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

        let rawEnvelopeHeader = envelopeParts[0]

        guard
            let eventId = rawEnvelopeHeader["event_id"] as? String,
            let itemType = envelopeParts[1]["type"] as? String else {
            result(FlutterError(code: "2", message: "Cannot serialize event", details: nil) )
            return
        }

        let sdkInfo = SentrySdkInfo(dict: rawEnvelopeHeader)
        let sentryId = SentryId(uuidString: eventId)
        let envelopeHeader = SentryEnvelopeHeader.init(id: sentryId, andSdkInfo: sdkInfo)

        let payload = envelopeParts[2]

        do{
            let data = try JSONSerialization.data(withJSONObject: payload, options: .init(rawValue: 0))
        
            let itemHeader = SentryEnvelopeItemHeader(type: itemType, length: UInt(data.count))
            let sentryItem = SentryEnvelopeItem( header: itemHeader, data: data)

            let envelope = SentryEnvelope.init(header: envelopeHeader, singleItem: sentryItem)
            SentrySDK.currentHub().getClient()?.capture(envelope: envelope)

            result("")
        } catch{
            
            result(FlutterError(code: "2", message: "Cannot serialize event payload", details: nil) )
        }
    }
}
