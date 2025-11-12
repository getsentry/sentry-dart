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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method as String {
        case "closeNativeSdk":
            closeNativeSdk(call, result: result)

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

    private func closeNativeSdk(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        SentrySDK.close()
        result("")
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

  @objc(setupReplay:tags:)
  public class func setupReplay(callback: @escaping SentryReplayCaptureCallback, tags: [String: Any]) {
    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
      let breadcrumbConverter = SentryFlutterReplayBreadcrumbConverter()
      let screenshotProvider = SentryFlutterReplayScreenshotProvider(callback: callback)
      PrivateSentrySDKOnly.configureSessionReplay(with: breadcrumbConverter, screenshotProvider: screenshotProvider)
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
    #endif
  }

  @objc(setBeforeSend:packages:integrations:)
  public class func setBeforeSend(options: Options, packages: [[String: String]], integrations: [String]) {
    options.beforeSend = { event in
      setEventOriginTag(event: event)
      setSdkMetaData(event: event, packages: packages, integrations: integrations)

      return event
    }
  }

  @objc public class func setAutoPerformanceFeatures() {
    PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
    #if os(iOS) || targetEnvironment(macCatalyst)
      PrivateSentrySDKOnly.framesTrackingMeasurementHybridSDKMode = true
    #endif
  }

  @objc public class func setupHybridSdkNotifications() {
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
  }

  @objc(setSdkMetaData:packages:integrations:)
  public class func setSdkMetaData(event: Event, packages: [[String: String]], integrations: [String]) {
    if var sdk = event.sdk, self.isValidSdk(sdk: sdk) {
      if let sdkPackages = sdk["packages"] as? [[String: String]] {
        sdk["packages"] = sdkPackages + packages
      } else {
        sdk["packages"] = packages
      }
      if let sdkIntegrations = sdk["integrations"] as? [String] {
        sdk["integrations"] = sdkIntegrations + integrations
      } else {
        sdk["integrations"] = integrations
      }
      event.sdk = sdk
    }
  }

  @objc(setEventOriginTag:)
  public class func setEventOriginTag(event: Event) {
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

  private class func setEventEnvironmentTag(event: Event, origin: String, environment: String) {
    event.tags?["event.origin"] = origin
    event.tags?["event.environment"] = environment
  }

  private class func isValidSdk(sdk: [String: Any]) -> Bool {
    guard let name = sdk["name"] as? String else {
      return false
    }
    return !name.isEmpty
  }

  @objc(setProxyOptions:user:pass:host:port:type:)
  public class func setProxyOptions(
    options: Options,
    user: String?,
    pass: String?,
    host: String,
    port: String,
    type: String
  ) {
    guard let portInt = Int(port) else {
      print("Could not parse proxy port")
      return
    }

    var connectionProxyDictionary: [String: Any] = [:]
    if type.lowercased() == "http" {
      connectionProxyDictionary[kCFNetworkProxiesHTTPEnable as String] = true
      connectionProxyDictionary[kCFNetworkProxiesHTTPProxy as String] = host
      connectionProxyDictionary[kCFNetworkProxiesHTTPPort as String] = portInt
    } else if type.lowercased() == "socks" {
      #if os(macOS)
        connectionProxyDictionary[kCFNetworkProxiesSOCKSEnable as String] = true
        connectionProxyDictionary[kCFNetworkProxiesSOCKSProxy as String] = host
        connectionProxyDictionary[kCFNetworkProxiesSOCKSPort as String] = portInt
      #else
        return
      #endif
    } else {
      return
    }

    if let user = user, let pass = pass {
      connectionProxyDictionary[kCFProxyUsernameKey as String] = user
      connectionProxyDictionary[kCFProxyPasswordKey as String] = pass
    }

    let configuration = URLSessionConfiguration.default
    configuration.connectionProxyDictionary = connectionProxyDictionary

    options.urlSession = URLSession(configuration: configuration)
  }

  @objc public class func getReplayOptions() -> SentryReplayOptions? {
    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
      return PrivateSentrySDKOnly.options.sessionReplay
    #endif
    return nil
  }

  @objc(setReplayOptions:quality:sessionSampleRate:onErrorSampleRate:sdkName:sdkVersion:)
  public class func setReplayOptions(
    options: Options,
    quality: Int,
    sessionSampleRate: Float,
    onErrorSampleRate: Float,
    sdkName: String,
    sdkVersion: String
  ) {
    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
      options.sessionReplay.quality = SentryReplayOptions.SentryReplayQuality(rawValue: quality) ?? .medium
      options.sessionReplay.sessionSampleRate = sessionSampleRate
      options.sessionReplay.onErrorSampleRate = onErrorSampleRate

      options.sessionReplay.setValue(
        [
          "name": sdkName,
          "version": sdkVersion
        ], forKey: "sdkInfo")
    #endif
  }

  @objc public class func captureReplay() -> String? {
    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
    PrivateSentrySDKOnly.captureReplay()
    return PrivateSentrySDKOnly.getReplayId()
    #else
    return nil
    #endif
  }

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
}
// swiftlint:enable type_body_length

// swiftlint:enable function_body_length

private extension TimeInterval {
    func toMilliseconds() -> Int64 {
        return Int64(self * 1000)
    }
}
