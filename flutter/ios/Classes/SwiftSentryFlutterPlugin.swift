import Flutter
import Sentry
import UIKit

public class SwiftSentryFlutterPlugin: NSObject, FlutterPlugin {

  private var sentryOptions: Options?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftSentryFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method as String {
    case "loadContexts":
      loadContexts(result: result)

    case "initNativeSdk":
      initNativeSdk(call, result: result)

    case "captureEnvelope":
      captureEnvelope(call, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadContexts(result: @escaping FlutterResult) {
    SentrySDK.configureScope { scope in
      let serializedScope = scope.serialize()
      let context = serializedScope["context"]

      var infos = ["contexts": context]

      if let integrations = self.sentryOptions?.integrations {
        infos["integrations"] = integrations
      }

      let options = self.sentryOptions ?? Options()
      infos["package"] = ["version": options.sdkInfo.version, "sdk_name": "cocoapods:sentry-cocoa"]

      result(infos)
    }
  }

  private func initNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any], !arguments.isEmpty else {
      print("Arguments is null or empty")
      result(FlutterError(code: "4", message: "Arguments is null or empty", details: nil))
      return
    }

    SentrySDK.start { options in
      if let dsn = arguments["dsn"] as? String {
        options.dsn = dsn
      }

      if let isDebug = arguments["debug"] as? Bool {
        options.debug = isDebug
      }

      if let environment = arguments["environment"] as? String {
        options.environment = environment
      }

      if let releaseName = arguments["release"] as? String {
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

      if let sessionTrackingIntervalMillis = arguments["sessionTrackingIntervalMillis"] as? UInt {
        options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis
      }

      if let dist = arguments["dist"] as? String {
        options.dist = dist
      }

      if let enableAutoNativeBreadcrumbs = arguments["enableAutoNativeBreadcrumbs"] as? Bool,
         enableAutoNativeBreadcrumbs == false {
        options.integrations = options.integrations?.filter { (name) -> Bool in
          name != "SentryAutoBreadcrumbTrackingIntegration"
        }
      }

      if let maxBreadcrumbs = arguments["maxBreadcrumbs"] as? UInt {
        options.maxBreadcrumbs = maxBreadcrumbs
      }

      self.sentryOptions = options

      // note : for now, in sentry-cocoa, beforeSend is not called before captureEnvelope
      options.beforeSend = { event in
        self.setEventOriginTag(event: event)

        if var sdk = event.sdk, self.isValidSdk(sdk: sdk) {
          if let packages = arguments["packages"] as? [String] {
            if var sdkPackages = sdk["packages"] as? [String] {
              sdk["packages"] = sdkPackages.append(contentsOf: packages)
            } else {
              sdk["packages"] = packages
            }
          }

          if let integrations = arguments["integrations"] as? [String] {
            if var sdkIntegrations = sdk["integrations"] as? [String] {
              sdk["integrations"] = sdkIntegrations.append(contentsOf: integrations)
            } else {
              sdk["integrations"] = integrations
            }
          }
          event.sdk = sdk
        }

        return event
      }
    }

    result("")
  }

  private func logLevelFrom(diagnosticLevel: String) -> SentryLogLevel {
    switch diagnosticLevel {
    case "fatal", "error":
      return .error
    case "debug":
      return .debug
    case "warning", "info":
      return .verbose
    default:
      return .none
    }
  }

  private func setEventOriginTag(event: Event) {
    guard let sdk = event.sdk else {
      return
    }
    if self.isValidSdk(sdk: sdk) {

      switch sdk["name"] as? String {
      case "sentry.dart.flutter":
        setEventEnvironmentTag(event: event, origin: "flutter", environment: "dart")
      case "sentry.cocoa":
        setEventEnvironmentTag(event: event, origin: "flutter", environment: "dart")
      case "sentry.native":
        setEventEnvironmentTag(event: event, origin: "flutter", environment: "dart")
      default:
        return
      }
    }
  }

  private func setEventEnvironmentTag(event: Event, origin: String = "ios", environment: String) {
    event.tags?["event.origin"] = origin
    event.tags?["event.environment"] = environment
  }

  private func isValidSdk(sdk: [String: Any]) -> Bool {
    guard let name = sdk["name"] as? String else {
      return false
    }
    return !name.isEmpty
  }

  private func captureEnvelope(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [Any],
          !arguments.isEmpty,
          let event = arguments.first as? String else {
      print("Envelope is null or empty !")
      result(FlutterError(code: "2", message: "Envelope is null or empty", details: nil))
      return
    }

    do {
      let envelope = try parseJsonEnvelope(event)

      SentrySDK.currentHub().getClient()?.capture(envelope: envelope)
      result("")
    } catch {
      print("Cannot parse the envelope json !")
      result(FlutterError(code: "3", message: "Cannot parse the envelope json", details: nil))
      return
    }
  }

  private func parseJsonEnvelope(_ data: String) throws -> SentryEnvelope {
    let parts = data.split(separator: "\n")

    let envelopeParts: [[String: Any]] = try parts.map({ part in
      guard let dict = parseJson(text: "\(part)") else {
        throw NSError()
      }
      return dict
    })

    let rawEnvelopeHeader = envelopeParts[0]
    guard let eventId = rawEnvelopeHeader["event_id"] as? String,
          let itemType = envelopeParts[1]["type"] as? String else {
      throw NSError()
    }

    let sdkInfo = SentrySdkInfo(dict: rawEnvelopeHeader)
    let sentryId = SentryId(uuidString: eventId)
    let envelopeHeader = SentryEnvelopeHeader.init(id: sentryId, andSdkInfo: sdkInfo)

    let payload = envelopeParts[2]

    let data = try JSONSerialization.data(withJSONObject: payload, options: .init(rawValue: 0))

    let itemHeader = SentryEnvelopeItemHeader(type: itemType, length: UInt(data.count))
    let sentryItem = SentryEnvelopeItem(header: itemHeader, data: data)

    return SentryEnvelope.init(header: envelopeHeader, singleItem: sentryItem)
  }

  func parseJson(text: String) -> [String: Any]? {
    guard let data = text.data(using: .utf8) else {
      print("Invalid UTF8 String : \(text)")
      return nil
    }

    do {
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      return json
    } catch {
      print("json parsing error !")
    }
    return nil
  }
}
