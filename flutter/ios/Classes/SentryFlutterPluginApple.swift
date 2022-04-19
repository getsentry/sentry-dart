import Sentry
#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import AppKit
#endif

// swiftlint:disable:next type_body_length
public class SentryFlutterPluginApple: NSObject, FlutterPlugin {

    private var sentryOptions: Options?

    // The Cocoa SDK is init. after the notification didBecomeActiveNotification is registered.
    // We need to be able to receive this notification and start a session when the SDK is fully operational.
    private var didReceiveDidBecomeActiveNotification = false

    private var didBecomeActiveNotificationName: NSNotification.Name {
#if os(iOS)
        return UIApplication.didBecomeActiveNotification
#elseif os(macOS)
        return NSApplication.didBecomeActiveNotification
#endif
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
#if os(iOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
#elseif os(macOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger)
#endif

        let instance = SentryFlutterPluginApple()
        instance.registerObserver()

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private func registerObserver() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: didBecomeActiveNotificationName,
                                               object: nil)
    }

    @objc private func applicationDidBecomeActive() {
        didReceiveDidBecomeActiveNotification = true
        // we only need to do that in the 1st time, so removing it
        NotificationCenter.default.removeObserver(self,
                                                  name: didBecomeActiveNotificationName,
                                                  object: nil)

    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method as String {
        case "loadContexts":
            loadContexts(result: result)

        case "initNativeSdk":
            initNativeSdk(call, result: result)

        case "closeNativeSdk":
            closeNativeSdk(call, result: result)

        case "captureEnvelope":
            captureEnvelope(call, result: result)

        case "fetchNativeAppStart":
            fetchNativeAppStart(result: result)

        case "beginNativeFrames":
            beginNativeFrames(result: result)

        case "endNativeFrames":
            endNativeFrames(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadContexts(result: @escaping FlutterResult) {
        SentrySDK.configureScope { scope in
            let serializedScope = scope.serialize()
            let context = serializedScope["context"]

            var infos = ["contexts": context]

            if let user = serializedScope["user"] as? [String: Any] {
                infos["user"] = user
            } else {
                infos["user"] = ["id": PrivateSentrySDKOnly.installationID]
            }

            if let integrations = self.sentryOptions?.integrations {
                infos["integrations"] = integrations
            }

            if let sdkInfo = self.sentryOptions?.sdkInfo {
                infos["package"] = ["version": sdkInfo.version, "sdk_name": "cocoapods:sentry-cocoa"]
            }

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
            self.updateOptions(arguments: arguments, options: options)

            if arguments["enableAutoPerformanceTracking"] as? Bool ?? false {
                PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
                #if os(iOS) || targetEnvironment(macCatalyst)
                PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true
                #endif
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

      // checking enableAutoSessionTracking is actually not necessary, but we'd spare the sent bits.
       if didReceiveDidBecomeActiveNotification && sentryOptions?.enableAutoSessionTracking == true {
            // we send a SentryHybridSdkDidBecomeActive to the Sentry Cocoa SDK, so the SDK will mimics
            // the didBecomeActiveNotification notification and start a session if not yet.
           NotificationCenter.default.post(name: Notification.Name("SentryHybridSdkDidBecomeActive"), object: nil)
           // we reset the flag for the sake of correctness
           didReceiveDidBecomeActiveNotification = false
       }

        result("")
    }

    private func closeNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        SentrySDK.close()
        result("")
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func updateOptions(arguments: [String: Any], options: Options) {
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
            options.diagnosticLevel = logLevelFrom(diagnosticLevel: diagnosticLevel)
        }

        if let sessionTrackingIntervalMillis = arguments["autoSessionTrackingIntervalMillis"] as? UInt {
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

        if let enableNativeCrashHandling = arguments["enableNativeCrashHandling"] as? Bool,
           enableNativeCrashHandling == false {
            options.integrations = options.integrations?.filter { (name) -> Bool in
                name != "SentryCrashIntegration"
            }
        }

        if let maxBreadcrumbs = arguments["maxBreadcrumbs"] as? UInt {
            options.maxBreadcrumbs = maxBreadcrumbs
        }

        if let sendDefaultPii = arguments["sendDefaultPii"] as? Bool {
            options.sendDefaultPii = sendDefaultPii
        }

        if let maxCacheItems = arguments["maxCacheItems"] as? UInt {
            options.maxCacheItems = maxCacheItems
        }

        if let enableOutOfMemoryTracking = arguments["enableOutOfMemoryTracking"] as? Bool {
            options.enableOutOfMemoryTracking = enableOutOfMemoryTracking
        }

        if let sendClientReports = arguments["sendClientReports"] as? Bool {
            options.sendClientReports = sendClientReports
        }
    }

    private func logLevelFrom(diagnosticLevel: String) -> SentryLevel {
        switch diagnosticLevel {
        case "fatal":
            return .fatal
        case "error":
            return .error
        case "debug":
            return .debug
        case "warning":
            return .warning
        case "info":
            return .info
        default:
            return .none
        }
    }

    private func setEventOriginTag(event: Event) {
        guard let sdk = event.sdk else {
            return
        }
        if isValidSdk(sdk: sdk) {

            switch sdk["name"] as? String {
            case "sentry.cocoa":
                #if os(OSX)
                    let origin = "mac"
                #elseif os(watchOS)
                    let origin = "watch"
                #elseif os(tvOS)
                    let origin = "tv"
                #elseif os(iOS)
                    #if targetEnvironment(macCatalyst)
                        let origin = "macCatalyst"
                    #else
                        let origin = "ios"
                    #endif
                #endif
                setEventEnvironmentTag(event: event, origin: origin, environment: "native")
            default:
                return
            }
        }
    }

    private func setEventEnvironmentTag(event: Event, origin: String, environment: String) {
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
              let data = (arguments.first as? FlutterStandardTypedData)?.data  else {
            print("Envelope is null or empty !")
            result(FlutterError(code: "2", message: "Envelope is null or empty", details: nil))
            return
        }
        guard let envelope = PrivateSentrySDKOnly.envelope(with: data) else {
            print("Cannot parse the envelope data")
            result(FlutterError(code: "3", message: "Cannot parse the envelope data", details: nil))
            return
        }
        PrivateSentrySDKOnly.capture(envelope)
        result("")
        return
    }

    private func fetchNativeAppStart(result: @escaping FlutterResult) {
        guard let appStartMeasurement = PrivateSentrySDKOnly.appStartMeasurement else {
            print("warning: appStartMeasurement is null")
            result(nil)
            return
        }

        let appStartTime = appStartMeasurement.appStartTimestamp.timeIntervalSince1970 * 1000
        let isColdStart = appStartMeasurement.type == .cold

        let item: [String: Any] = [
            "appStartTime": appStartTime,
            "isColdStart": isColdStart
        ]

        result(item)
    }

    private var totalFrames: UInt = 0
    private var frozenFrames: UInt = 0
    private var slowFrames: UInt = 0

    private func beginNativeFrames(result: @escaping FlutterResult) {
      #if os(iOS) || targetEnvironment(macCatalyst)
      guard PrivateSentrySDKOnly.isFramesTrackingRunning else {
        print("Native frames tracking not running.")
        result(nil)
        return
      }

      let currentFrames = PrivateSentrySDKOnly.currentScreenFrames
      totalFrames = currentFrames.total
      frozenFrames = currentFrames.frozen
      slowFrames = currentFrames.slow

      result(nil)
      #else
      result(nil)
      #endif
    }

    private func endNativeFrames(result: @escaping FlutterResult) {
      #if os(iOS) || targetEnvironment(macCatalyst)
      guard PrivateSentrySDKOnly.isFramesTrackingRunning else {
        print("Native frames tracking not running.")
        result(nil)
        return
      }

      let currentFrames = PrivateSentrySDKOnly.currentScreenFrames

      let total = currentFrames.total - totalFrames
      let frozen = currentFrames.frozen - frozenFrames
      let slow = currentFrames.slow - slowFrames

      if total <= 0 && frozen <= 0 && slow <= 0 {
        result(nil)
        return
      }

      let item: [String: Any] = [
          "totalFrames": total,
          "frozenFrames": frozen,
          "slowFrames": slow
      ]

      result(item)
      #else
      result(nil)
      #endif
    }
}
