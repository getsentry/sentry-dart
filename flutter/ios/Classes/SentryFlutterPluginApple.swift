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
            let user = arguments?["user"] as? [String: Any?]
            setUser(user: user, result: result)

        case "addBreadcrumb":
            let arguments = call.arguments as? [String: Any?]
            let breadcrumb = arguments?["breadcrumb"] as? [String: Any?]
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
                        currentDevice.mergeDictionary(other: extraDevice)
                        context[deviceStr] = currentDevice
                    } else {
                        context[deviceStr] = extraDevice
                    }
                }

                // merge app
                if let extraApp = extraContext[appStr] as? [String: Any] {
                    if var currentApp = context[appStr] as? [String: Any] {
                        currentApp.mergeDictionary(other: extraApp)
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
            self.updateOptions(arguments: arguments, options: options)

            if arguments["enableAutoPerformanceTracing"] as? Bool ?? false {
                PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
                #if os(iOS) || targetEnvironment(macCatalyst)
                PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true
                #endif
            }

            let name = "sentry.cocoa.flutter"
            let version = PrivateSentrySDKOnly.getSdkVersionString()
            PrivateSentrySDKOnly.setSdkName(name, andVersionString: version)

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

        if let enableAutoNativeBreadcrumbs = arguments["enableAutoNativeBreadcrumbs"] as? Bool {
            options.enableAutoBreadcrumbTracking = enableAutoNativeBreadcrumbs
        }

        if let enableNativeCrashHandling = arguments["enableNativeCrashHandling"] as? Bool {
            options.enableCrashHandler = enableNativeCrashHandling
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

        if let enableWatchdogTerminationTracking = arguments["enableWatchdogTerminationTracking"] as? Bool {
            options.enableWatchdogTerminationTracking = enableWatchdogTerminationTracking
        }

        if let sendClientReports = arguments["sendClientReports"] as? Bool {
            options.sendClientReports = sendClientReports
        }

        if let maxAttachmentSize = arguments["maxAttachmentSize"] as? UInt {
            options.maxAttachmentSize = maxAttachmentSize
        }

        if let captureFailedRequests = arguments["captureFailedRequests"] as? Bool {
            options.enableCaptureFailedRequests = captureFailedRequests
        }

        if let enableAppHangTracking = arguments["enableAppHangTracking"] as? Bool {
            options.enableAppHangTracking = enableAppHangTracking
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

    // swiftlint:disable:next cyclomatic_complexity
    private func setUser(user: [String: Any?]?, result: @escaping FlutterResult) {
      if let user = user {
        let userInstance = User()

        if let email = user["email"] as? String {
          userInstance.email = email
        }
        if let id = user["id"] as? String {
          userInstance.userId = id
        }
        if let username = user["username"] as? String {
          userInstance.username = username
        }
        if let ipAddress = user["ip_address"] as? String {
          userInstance.ipAddress = ipAddress
        }
        if let segment = user["segment"] as? String {
          userInstance.segment = segment
        }
        if let extras = user["extras"] as? [String: Any] {
          userInstance.data = extras
        }
        if let data = user["data"] as? [String: Any] {
          if let oldData = userInstance.data {
            userInstance.data = oldData.reduce(into: data) { (first, second) in first[second.0] = second.1 }
          } else {
            userInstance.data = data
          }
        }
        if let name = user["name"] as? String {
          userInstance.name = name
        }
        if let geoData = user["geo"] as? [String: Any] {
          let geo = Geo()
          geo.city = geoData["city"] as? String
          geo.countryCode = geoData["country_code"] as? String
          geo.region = geoData["region"] as? String
          userInstance.geo = geo
        }

        SentrySDK.setUser(userInstance)
      } else {
        SentrySDK.setUser(nil)
      }
      result("")
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func addBreadcrumb(breadcrumb: [String: Any?]?, result: @escaping FlutterResult) {
      guard let breadcrumb = breadcrumb else {
        result("")
        return
      }

      let breadcrumbInstance = Breadcrumb()

      if let message = breadcrumb["message"] as? String {
        breadcrumbInstance.message = message
      }
      if let type = breadcrumb["type"] as? String {
        breadcrumbInstance.type = type
      }
      if let category = breadcrumb["category"] as? String {
        breadcrumbInstance.category = category
      }
      if let level = breadcrumb["level"] as? String {
        switch level {
        case "fatal":
          breadcrumbInstance.level = SentryLevel.fatal
        case "warning":
          breadcrumbInstance.level = SentryLevel.warning
        case "info":
          breadcrumbInstance.level = SentryLevel.info
        case "debug":
          breadcrumbInstance.level = SentryLevel.debug
        case "error":
          breadcrumbInstance.level = SentryLevel.error
        default:
          breadcrumbInstance.level = SentryLevel.error
        }
      }
      if let data = breadcrumb["data"] as? [String: Any] {
        breadcrumbInstance.data = data
      }

      if let timestampValue = breadcrumb["timestamp"] as? String,
         let timestamp = dateFrom(iso8601String: timestampValue) {
        breadcrumbInstance.timestamp = timestamp
      }

      SentrySDK.addBreadcrumb(breadcrumbInstance)

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
}

extension Dictionary {
    mutating func mergeDictionary(other: Dictionary) {
        for (key, value) in other {
            self.updateValue(value, forKey: key)
        }
    }
}

// swiftlint:enable function_body_length
