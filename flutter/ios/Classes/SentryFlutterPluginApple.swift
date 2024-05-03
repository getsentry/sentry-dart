import Sentry
#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import AppKit
#endif

// swiftlint:disable file_length function_body_length

// swiftlint:disable:next type_body_length
public class SentryFlutterPluginApple: NSObject, FlutterPlugin {

    private static let nativeClientName = "sentry.cocoa.flutter"

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

    private static var pluginRegistrationTime: Int64 = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        pluginRegistrationTime = Int64(Date().timeIntervalSince1970 * 1000)

#if os(iOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
#elseif os(macOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger)
#endif

        let instance = SentryFlutterPluginApple()
        instance.registerObserver()

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private lazy var sentryFlutter = SentryFlutter()

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

    private lazy var iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }()

    private lazy var iso8601FormatterWithMillisecondPrecision: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter
    }()

    // Replace with `NSDate+SentryExtras` when available.
    private func dateFrom(iso8601String: String) -> Date? {
      return iso8601FormatterWithMillisecondPrecision.date(from: iso8601String)
        ?? iso8601Formatter.date(from: iso8601String) // Parse date with low precision formatter for backward compatible
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method as String {
        case "loadContexts":
            loadContexts(result: result)

        case "loadImageList":
            loadImageList(result: result)

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

        case "setContexts":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            let value = arguments?["value"] as? Any
            setContexts(key: key, value: value, result: result)

        case "removeContexts":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            removeContexts(key: key, result: result)

        case "setUser":
            let arguments = call.arguments as? [String: Any?]
            let user = arguments?["user"] as? [String: Any]
            setUser(user: user, result: result)

        case "addBreadcrumb":
            let arguments = call.arguments as? [String: Any?]
            let breadcrumb = arguments?["breadcrumb"] as? [String: Any]
            addBreadcrumb(breadcrumb: breadcrumb, result: result)

        case "clearBreadcrumbs":
            clearBreadcrumbs(result: result)

        case "setExtra":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            let value = arguments?["value"] as? Any
            setExtra(key: key, value: value, result: result)

        case "removeExtra":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            removeExtra(key: key, result: result)

        case "setTag":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            let value = arguments?["value"] as? String
            setTag(key: key, value: value, result: result)

        case "removeTag":
            let arguments = call.arguments as? [String: Any?]
            let key = arguments?["key"] as? String
            removeTag(key: key, result: result)

        #if !os(tvOS) && !os(watchOS)
        case "discardProfiler":
            discardProfiler(call, result)

        case "collectProfile":
            collectProfile(call, result)
        #endif

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func loadContexts(result: @escaping FlutterResult) {
        SentrySDK.configureScope { scope in
            let serializedScope = scope.serialize()

            var context: [String: Any] = [:]
            if let newContext = serializedScope["context"] as? [String: Any] {
                context = newContext
            }

            var infos: [String: Any] = [:]

            if let tags = serializedScope["tags"] as? [String: String] {
                infos["tags"] = tags
            }
            if let extra = serializedScope["extra"] as? [String: Any] {
                infos["extra"] = extra
            }
            if let user = serializedScope["user"] as? [String: Any] {
                infos["user"] = user
            }
            if let dist = serializedScope["dist"] as? String {
                infos["dist"] = dist
            }
            if let environment = serializedScope["environment"] as? String {
                infos["environment"] = environment
            }
            if let fingerprint = serializedScope["fingerprint"] as? [String] {
                infos["fingerprint"] = fingerprint
            }
            if let level = serializedScope["level"] as? String {
                infos["level"] = level
            }
            if let breadcrumbs = serializedScope["breadcrumbs"] as? [[String: Any]] {
                infos["breadcrumbs"] = breadcrumbs
            }

            if let user = serializedScope["user"] as? [String: Any] {
                infos["user"] = user
            } else {
                infos["user"] = ["id": PrivateSentrySDKOnly.installationID]
            }

            if let integrations = PrivateSentrySDKOnly.options.integrations {
                infos["integrations"] = integrations
            }

            let deviceStr = "device"
            let appStr = "app"
            if let extraContext = PrivateSentrySDKOnly.getExtraContext() as? [String: Any] {
                // merge device
                if let extraDevice = extraContext[deviceStr] as? [String: Any] {
                    if var currentDevice = context[deviceStr] as? [String: Any] {
                        currentDevice.merge(extraDevice) { (current, _) in current }
                        context[deviceStr] = currentDevice
                    } else {
                        context[deviceStr] = extraDevice
                    }
                }

                // merge app
                if let extraApp = extraContext[appStr] as? [String: Any] {
                    if var currentApp = context[appStr] as? [String: Any] {
                        currentApp.merge(extraApp) { (current, _) in current }
                        context[appStr] = currentApp
                    } else {
                        context[appStr] = extraApp
                    }
                }
            }

            infos["contexts"] = context

            // Not reading the name from PrivateSentrySDKOnly.getSdkName because
            // this is added as a package and packages should follow the sentry-release-registry format
            infos["package"] = ["version": PrivateSentrySDKOnly.getSdkVersionString(),
                "sdk_name": "cocoapods:sentry-cocoa"]

            result(infos)
        }
    }

    private func loadImageList(result: @escaping FlutterResult) {
      let debugImages = PrivateSentrySDKOnly.getDebugImages() as [DebugMeta]
      result(debugImages.map { $0.serialize() })
    }

    private func initNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any], !arguments.isEmpty else {
            print("Arguments is null or empty")
            result(FlutterError(code: "4", message: "Arguments is null or empty", details: nil))
            return
        }

        SentrySDK.start { options in
            self.sentryFlutter.update(options: options, with: arguments)

            if arguments["enableAutoPerformanceTracing"] as? Bool ?? false {
                PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
                #if os(iOS) || targetEnvironment(macCatalyst)
                PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true
                #endif
            }

            let version = PrivateSentrySDKOnly.getSdkVersionString()
            PrivateSentrySDKOnly.setSdkName(SentryFlutterPluginApple.nativeClientName, andVersionString: version)

            // note : for now, in sentry-cocoa, beforeSend is not called before captureEnvelope
            options.beforeSend = { event in
                self.setEventOriginTag(event: event)

                if var sdk = event.sdk, self.isValidSdk(sdk: sdk) {
                    if let packages = arguments["packages"] as? [[String: String]] {
                        if let sdkPackages = sdk["packages"] as? [[String: String]] {
                            sdk["packages"] = sdkPackages + packages
                        } else {
                            sdk["packages"] = packages
                        }
                    }

                    if let integrations = arguments["integrations"] as? [String] {
                        if let sdkIntegrations = sdk["integrations"] as? [String] {
                            sdk["integrations"] = sdkIntegrations + integrations
                        } else {
                            sdk["integrations"] = integrations
                        }
                    }
                    event.sdk = sdk
                }

                return event
            }
        }

       if didReceiveDidBecomeActiveNotification &&
            (PrivateSentrySDKOnly.options.enableAutoSessionTracking ||
             PrivateSentrySDKOnly.options.enableWatchdogTerminationTracking) {
            // We send a SentryHybridSdkDidBecomeActive to the Sentry Cocoa SDK, so the SDK will mimics
            // the didBecomeActiveNotification notification. This is needed for session and OOM tracking.
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

    private func setEventOriginTag(event: Event) {
        guard let sdk = event.sdk else {
            return
        }
        if isValidSdk(sdk: sdk) {

            switch sdk["name"] as? String {
            case SentryFlutterPluginApple.nativeClientName:
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
              let data = (arguments.first as? FlutterStandardTypedData)?.data else {
            print("Envelope is null or empty!")
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

    struct TimeSpan {
        var startTimestampMsSinceEpoch: NSNumber
        var stopTimestampMsSinceEpoch: NSNumber
        var description: String

        func addToMap(_ map: inout [String: Any]) {
            map[description] = [
                "startTimestampMsSinceEpoch": startTimestampMsSinceEpoch,
                "stopTimestampMsSinceEpoch": stopTimestampMsSinceEpoch
            ]
        }
    }

    private func fetchNativeAppStart(result: @escaping FlutterResult) {
        #if os(iOS) || os(tvOS)
        guard let appStartMeasurement = PrivateSentrySDKOnly.appStartMeasurement else {
            print("warning: appStartMeasurement is null")
            result(nil)
            return
        }

        var nativeSpanTimes: [String: Any] = [:]

        let appStartTimeMs = appStartMeasurement.appStartTimestamp.timeIntervalSince1970.toMilliseconds()
        let runtimeInitTimeMs = appStartMeasurement.runtimeInitTimestamp.timeIntervalSince1970.toMilliseconds()
        let moduleInitializationTimeMs =
            appStartMeasurement.moduleInitializationTimestamp.timeIntervalSince1970.toMilliseconds()
        let sdkStartTimeMs = appStartMeasurement.sdkStartTimestamp.timeIntervalSince1970.toMilliseconds()

        if !appStartMeasurement.isPreWarmed {
            let preRuntimeInitDescription = "Pre Runtime Init"
            let preRuntimeInitSpan = TimeSpan(
                startTimestampMsSinceEpoch: NSNumber(value: appStartTimeMs),
                stopTimestampMsSinceEpoch: NSNumber(value: runtimeInitTimeMs),
                description: preRuntimeInitDescription
            )
            preRuntimeInitSpan.addToMap(&nativeSpanTimes)

            let moduleInitializationDescription = "Runtime init to Pre Main initializers"
            let moduleInitializationSpan = TimeSpan(
                startTimestampMsSinceEpoch: NSNumber(value: runtimeInitTimeMs),
                stopTimestampMsSinceEpoch: NSNumber(value: moduleInitializationTimeMs),
                description: moduleInitializationDescription
            )
            moduleInitializationSpan.addToMap(&nativeSpanTimes)
        }

        let uiKitInitDescription = "UIKit init"
        let uiKitInitSpan = TimeSpan(
            startTimestampMsSinceEpoch: NSNumber(value: moduleInitializationTimeMs),
            stopTimestampMsSinceEpoch: NSNumber(value: sdkStartTimeMs),
            description: uiKitInitDescription
        )
        uiKitInitSpan.addToMap(&nativeSpanTimes)

        // Info: We don't have access to didFinishLaunchingTimestamp,
        // On HybridSDKs, the Cocoa SDK misses the didFinishLaunchNotification and the
        // didBecomeVisibleNotification. Therefore, we can't set the
        // didFinishLaunchingTimestamp

        let appStartTime = appStartMeasurement.appStartTimestamp.timeIntervalSince1970 * 1000
        let isColdStart = appStartMeasurement.type == .cold

        let item: [String: Any] = [
            "pluginRegistrationTime": SentryFlutterPluginApple.pluginRegistrationTime,
            "appStartTime": appStartTime,
            "isColdStart": isColdStart,
            "nativeSpanTimes": nativeSpanTimes
        ]

        result(item)
        #else
        print("note: appStartMeasurement not available on this platform")
        result(nil)
        #endif
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
      let total = max(Int(currentFrames.total) - Int(totalFrames), 0)
      let frozen = max(Int(currentFrames.frozen) - Int(frozenFrames), 0)
      let slow = max(Int(currentFrames.slow) - Int(slowFrames), 0)

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

    private func setContexts(key: String?, value: Any?, result: @escaping FlutterResult) {
      guard let key = key else {
        result("")
        return
      }

      SentrySDK.configureScope { scope in
        if let dictionary = value as? [String: Any] {
          scope.setContext(value: dictionary, key: key)
        } else if let string = value as? String {
          scope.setContext(value: ["value": string], key: key)
        } else if let int = value as? Int {
          scope.setContext(value: ["value": int], key: key)
        } else if let double = value as? Double {
          scope.setContext(value: ["value": double], key: key)
        } else if let bool = value as? Bool {
          scope.setContext(value: ["value": bool], key: key)
        }
        result("")
      }
    }

    private func removeContexts(key: String?, result: @escaping FlutterResult) {
      guard let key = key else {
        result("")
        return
      }
      SentrySDK.configureScope { scope in
        scope.removeContext(key: key)
        result("")
      }
    }

    private func setUser(user: [String: Any]?, result: @escaping FlutterResult) {
      if let user = user {
        let userInstance = PrivateSentrySDKOnly.user(with: user)
        SentrySDK.setUser(userInstance)
      } else {
        SentrySDK.setUser(nil)
      }
      result("")
    }

    private func addBreadcrumb(breadcrumb: [String: Any]?, result: @escaping FlutterResult) {
      if let breadcrumb = breadcrumb {
        let breadcrumbInstance = PrivateSentrySDKOnly.breadcrumb(with: breadcrumb)
        SentrySDK.addBreadcrumb(breadcrumbInstance)
      }
      result("")
    }

    private func clearBreadcrumbs(result: @escaping FlutterResult) {
      SentrySDK.configureScope { scope in
        scope.clearBreadcrumbs()

        result("")
      }
    }

    private func setExtra(key: String?, value: Any?, result: @escaping FlutterResult) {
      guard let key = key else {
        result("")
        return
      }
      SentrySDK.configureScope { scope in
        scope.setExtra(value: value, key: key)

        result("")
      }
    }

    private func removeExtra(key: String?, result: @escaping FlutterResult) {
      guard let key = key else {
        result("")
        return
      }
      SentrySDK.configureScope { scope in
        scope.removeExtra(key: key)

        result("")
      }
    }

    private func setTag(key: String?, value: String?, result: @escaping FlutterResult) {
      guard let key = key, let value = value else {
        result("")
        return
      }
      SentrySDK.configureScope { scope in
        scope.setTag(value: value, key: key)

        result("")
      }
    }

    private func removeTag(key: String?, result: @escaping FlutterResult) {
      guard let key = key else {
        result("")
        return
      }
      SentrySDK.configureScope { scope in
        scope.removeTag(key: key)

        result("")
      }
    }

    private func collectProfile(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any],
              let traceId = arguments["traceId"] as? String else {
            print("Cannot collect profile: trace ID missing")
            result(FlutterError(code: "6", message: "Cannot collect profile: trace ID missing", details: nil))
            return
        }

        guard let startTime = arguments["startTime"] as? UInt64 else {
            print("Cannot collect profile: start time missing")
            result(FlutterError(code: "7", message: "Cannot collect profile: start time missing", details: nil))
            return
        }

        guard let endTime = arguments["endTime"] as? UInt64 else {
            print("Cannot collect profile: end time missing")
            result(FlutterError(code: "8", message: "Cannot collect profile: end time missing", details: nil))
            return
        }

        let payload = PrivateSentrySDKOnly.collectProfileBetween(startTime, and: endTime,
                                                                       forTrace: SentryId(uuidString: traceId))
        result(payload)
    }

    private func discardProfiler(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let traceId = call.arguments as? String else {
            print("Cannot discard a profiler: trace ID missing")
            result(FlutterError(code: "9", message: "Cannot discard a profiler: trace ID missing", details: nil))
            return
        }

        PrivateSentrySDKOnly.discardProfiler(forTrace: SentryId(uuidString: traceId))
        result(nil)
    }
}

// swiftlint:enable function_body_length

private extension TimeInterval {
    func toMilliseconds() -> Int64 {
        return Int64(self * 1000)
    }
}
