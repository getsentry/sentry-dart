@_spi(Private) import Sentry

#if SWIFT_PACKAGE
import Sentry._Hybrid
import sentry_flutter_objc
#endif

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
import AppKit
import CoreVideo
#endif

// swiftlint:disable file_length function_body_length

// swiftlint:disable type_body_length
@objc(SentryFlutterPlugin)
public class SentryFlutterPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel

    private static let nativeClientName = "sentry.cocoa.flutter"

    private static var pluginRegistrationTime: Int64 = 0

    public static func register(with registrar: FlutterPluginRegistrar) {
        pluginRegistrationTime = Int64(Date().timeIntervalSince1970 * 1000)

#if os(iOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger())
#elseif os(macOS)
        let channel = FlutterMethodChannel(name: "sentry_flutter", binaryMessenger: registrar.messenger)
#endif

        let instance = SentryFlutterPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    private lazy var sentryFlutter = SentryFlutter()

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
        case "initNativeSdk":
            initNativeSdk(call, result: result)

        case "closeNativeSdk":
            closeNativeSdk(call, result: result)

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

        case "captureReplay":
#if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
            PrivateSentrySDKOnly.captureReplay()
            result(PrivateSentrySDKOnly.getReplayId())
#else
            result(nil)
#endif

        default:
            result(FlutterMethodNotImplemented)
        }
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
            PrivateSentrySDKOnly.setSdkName(SentryFlutterPlugin.nativeClientName, andVersionString: version)

            let flutterSdk = arguments["sdk"] as? [String: Any]

            // note : for now, in sentry-cocoa, beforeSend is not called before captureEnvelope
            options.beforeSend = { event in
                self.setEventOriginTag(event: event)

                if flutterSdk != nil {
                    if var sdk = event.sdk, self.isValidSdk(sdk: sdk) {
                        if let packages = flutterSdk!["packages"] as? [[String: String]] {
                            if let sdkPackages = sdk["packages"] as? [[String: String]] {
                                sdk["packages"] = sdkPackages + packages
                            } else {
                                sdk["packages"] = packages
                            }
                        }

                        if let integrations = flutterSdk!["integrations"] as? [String] {
                            if let sdkIntegrations = sdk["integrations"] as? [String] {
                                sdk["integrations"] = sdkIntegrations + integrations
                            } else {
                                sdk["integrations"] = integrations
                            }
                        }
                        event.sdk = sdk
                    }
                }

                return event
            }
        }

        #if os(iOS) || targetEnvironment(macCatalyst)
        let appIsActive = UIApplication.shared.applicationState == .active
        #else
        let appIsActive = NSApplication.shared.isActive
        #endif

        // We send a SentryHybridSdkDidBecomeActive to the Sentry Cocoa SDK, to mimic
        // the didBecomeActiveNotification notification. This is needed for session, OOM tracking, replays, etc.
        if appIsActive {
            NotificationCenter.default.post(name: Notification.Name("SentryHybridSdkDidBecomeActive"), object: nil)
        }

        configureReplay(arguments)

        result("")
    }

  private func configureReplay(_ arguments: [String: Any]) {
#if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
       let breadcrumbConverter = SentryFlutterReplayBreadcrumbConverter()
       let screenshotProvider = SentryFlutterReplayScreenshotProvider(channel: self.channel)
       PrivateSentrySDKOnly.configureSessionReplay(with: breadcrumbConverter, screenshotProvider: screenshotProvider)
       if let replayOptions = arguments["replay"] as? [String: Any] {
         if let tags = replayOptions["tags"] as? [String: Any] {
           let sessionReplayOptions = PrivateSentrySDKOnly.options.sessionReplay
           var newTags: [String: Any] = [
            "sessionSampleRate": sessionReplayOptions.sessionSampleRate,
            "errorSampleRate": sessionReplayOptions.onErrorSampleRate,
            "quality": String(describing: sessionReplayOptions.quality),
            "nativeSdkName": PrivateSentrySDKOnly.getSdkName(),
            "nativeSdkVersion": PrivateSentrySDKOnly.getSdkVersionString()
           ]
           for (key, value) in tags {
               newTags[key] = value
           }
           PrivateSentrySDKOnly.setReplayTags(newTags)
         }
       }
#endif
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
            case SentryFlutterPlugin.nativeClientName:
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

  // MARK: - Objective-C interoperability
  //
  // Group of methods exposed to the Objective-C runtime via `@objc`.
  //
  // Purpose: Called from the Flutter plugin's native bridge (FFI) - bindings are created from SentryFlutterPlugin.h

  #if os(iOS)
  // Taken from the Flutter engine:
  // https://github.com/flutter/engine/blob/main/shell/platform/darwin/ios/framework/Source/vsync_waiter_ios.mm#L150
  @objc public class func getDisplayRefreshRate() -> NSNumber? {
      let displayLink = CADisplayLink(target: self, selector: #selector(onDisplayLinkStatic(_:)))
      displayLink.isPaused = true

      let preferredFPS = displayLink.preferredFramesPerSecond
      displayLink.invalidate()

      if preferredFPS != 0 {
          return NSNumber(value: preferredFPS)
      }

      if #available(iOS 13.0, *) {
          guard let windowScene = UIApplication.shared.windows.first?.windowScene else {
              return nil
          }
          return NSNumber(value: windowScene.screen.maximumFramesPerSecond)
      } else {
          return NSNumber(value: UIScreen.main.maximumFramesPerSecond)
      }
  }

  @objc private class func onDisplayLinkStatic(_ displayLink: CADisplayLink) {
      // No-op
  }
  #elseif os(macOS)
  @objc public class func getDisplayRefreshRate() -> NSNumber? {
      return nil
  }
  #endif

  @objc public class func fetchNativeAppStartAsBytes() -> NSData? {
      #if os(iOS) || os(tvOS)
      guard let appStartMeasurement = PrivateSentrySDKOnly.appStartMeasurement else {
          return nil
      }

      var nativeSpanTimes: [String: Any] = [:]

      let appStartTimeMs = appStartMeasurement.appStartTimestamp.timeIntervalSince1970.toMilliseconds()
      let runtimeInitTimeMs = appStartMeasurement.runtimeInitTimestamp.timeIntervalSince1970.toMilliseconds()
      let moduleInitializationTimeMs =
          appStartMeasurement.moduleInitializationTimestamp.timeIntervalSince1970.toMilliseconds()
      let sdkStartTimeMs = appStartMeasurement.sdkStartTimestamp.timeIntervalSince1970.toMilliseconds()

      if !appStartMeasurement.isPreWarmed {
          let preRuntimeInitDescription = "Pre Runtime Init"
          let preRuntimeInitSpan: [String: Any] = [
              "startTimestampMsSinceEpoch": NSNumber(value: appStartTimeMs),
              "stopTimestampMsSinceEpoch": NSNumber(value: runtimeInitTimeMs)
          ]
          nativeSpanTimes[preRuntimeInitDescription] = preRuntimeInitSpan

          let moduleInitializationDescription = "Runtime init to Pre Main initializers"
          let moduleInitializationSpan: [String: Any] = [
              "startTimestampMsSinceEpoch": NSNumber(value: runtimeInitTimeMs),
              "stopTimestampMsSinceEpoch": NSNumber(value: moduleInitializationTimeMs)
          ]
          nativeSpanTimes[moduleInitializationDescription] = moduleInitializationSpan
      }

      let uiKitInitDescription = "UIKit init"
      let uiKitInitSpan: [String: Any] = [
          "startTimestampMsSinceEpoch": NSNumber(value: moduleInitializationTimeMs),
          "stopTimestampMsSinceEpoch": NSNumber(value: sdkStartTimeMs)
      ]
      nativeSpanTimes[uiKitInitDescription] = uiKitInitSpan

      let appStartTime = appStartMeasurement.appStartTimestamp.timeIntervalSince1970 * 1000
      let isColdStart = appStartMeasurement.type == .cold

      let item: [String: Any] = [
          "pluginRegistrationTime": pluginRegistrationTime,
          "appStartTime": appStartTime,
          "isColdStart": isColdStart,
          "nativeSpanTimes": nativeSpanTimes
      ]

      do {
          let data = try JSONSerialization.data(withJSONObject: item, options: [])
          return data as NSData
      } catch {
          print("Failed to load native app start as bytes: \(error)")
          return nil
      }
      #else
      return nil
      #endif
  }

  @objc(loadDebugImagesAsBytes:)
  public class func loadDebugImagesAsBytes(instructionAddresses: Set<String>) -> NSData? {
          var debugImages: [DebugMeta] = []

          var imagesAddresses: Set<String> = []

          for address in instructionAddresses {
              let hexDigits = address.replacingOccurrences(of: "0x", with: "")
              if let instructionAddress = UInt64(hexDigits, radix: 16) {
                  let image = SentryDependencyContainer.sharedInstance().binaryImageCache
                    .imageByAddress(instructionAddress)
                  if let image = image {
                      let imageAddress = sentry_formatHexAddressUInt64(image.address)!
                      imagesAddresses.insert(imageAddress)
                  }
              }
          }
          debugImages =
            SentryDependencyContainer.sharedInstance().debugImageProvider
            .getDebugImagesForImageAddressesFromCache(imageAddresses: imagesAddresses) as [DebugMeta]

          if debugImages.isEmpty {
              debugImages = PrivateSentrySDKOnly.getDebugImages() as [DebugMeta]
          }

          let serializedImages = debugImages.map { $0.serialize() }
          do {
              let data = try JSONSerialization.data(withJSONObject: serializedImages, options: [])
              return data as NSData
          } catch {
              print("Failed to load debug images as bytes: \(error)")
              return nil
          }
  }

  // swiftlint:disable:next cyclomatic_complexity
  @objc public class func loadContextsAsBytes() -> NSData? {
        var infos: [String: Any] = [:]

        SentrySDK.configureScope { scope in
            let serializedScope = scope.serialize()

            var context: [String: Any] = [:]
            if let newContext = serializedScope["context"] as? [String: Any] {
                context = newContext
            }

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
                infos["integrations"] = integrations.filter { $0 != "SentrySessionReplayIntegration" }
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

        }
        do {
            let data = try JSONSerialization.data(withJSONObject: infos, options: [])
            return data as NSData
        } catch {
            print("Failed to load contexts as bytes: \(error)")
            return nil
        }
  }

  @objc public class func addBreadcrumbAsBytes(_ breadcrumbBytes: NSData) {
      guard let breadcrumbDict = try? JSONSerialization.jsonObject(
          with: breadcrumbBytes as Data,
          options: []
      ) as? [String: Any] else {
          print("addBreadcrumb failed in native cocoa: could not parse bytes")
          return
      }
      let breadcrumbInstance = PrivateSentrySDKOnly.breadcrumb(with: breadcrumbDict)
      SentrySDK.addBreadcrumb(breadcrumbInstance)
  }

  @objc public class func clearBreadcrumbs() {
      SentrySDK.configureScope { scope in
          scope.clearBreadcrumbs()
      }
  }
}
// swiftlint:enable type_body_length

// swiftlint:enable function_body_length

private extension TimeInterval {
    func toMilliseconds() -> Int64 {
        return Int64(self * 1000)
    }
}
