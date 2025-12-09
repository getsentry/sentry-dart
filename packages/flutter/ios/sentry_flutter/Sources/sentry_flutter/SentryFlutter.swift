import Sentry

public final class SentryFlutter {

    public init() {
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    public func update(options: Options, with data: [String: Any]) {
        if let dsn = data["dsn"] as? String {
            options.dsn = dsn
        }
        if let isDebug = data["debug"] as? Bool {
            options.debug = isDebug
        }
        if let environment = data["environment"] as? String {
            options.environment = environment
        }
        if let releaseName = data["release"] as? String {
            options.releaseName = releaseName
        }
        if let enableAutoSessionTracking = data["enableAutoSessionTracking"] as? Bool {
            options.enableAutoSessionTracking = enableAutoSessionTracking
        }
        if let attachStacktrace = data["attachStacktrace"] as? Bool {
            options.attachStacktrace = attachStacktrace
        }
        if let diagnosticLevel = data["diagnosticLevel"] as? String, options.debug == true {
            options.diagnosticLevel = logLevelFrom(diagnosticLevel: diagnosticLevel)
        }
        if let sessionTrackingIntervalMillis = data["autoSessionTrackingIntervalMillis"] as? NSNumber {
            options.sessionTrackingIntervalMillis = sessionTrackingIntervalMillis.uintValue
        }
        if let dist = data["dist"] as? String {
            options.dist = dist
        }
        if let enableAutoNativeBreadcrumbs = data["enableAutoNativeBreadcrumbs"] as? Bool {
            options.enableAutoBreadcrumbTracking = enableAutoNativeBreadcrumbs
        }
        if let enableNativeCrashHandling = data["enableNativeCrashHandling"] as? Bool {
            options.enableCrashHandler = enableNativeCrashHandling
        }
        if let maxBreadcrumbs = data["maxBreadcrumbs"] as? NSNumber {
            options.maxBreadcrumbs = maxBreadcrumbs.uintValue
        }
        if let sendDefaultPii = data["sendDefaultPii"] as? Bool {
            options.sendDefaultPii = sendDefaultPii
        }
        if let maxCacheItems = data["maxCacheItems"] as? NSNumber {
            options.maxCacheItems = maxCacheItems.uintValue
        }
        if let enableWatchdogTerminationTracking = data["enableWatchdogTerminationTracking"] as? Bool {
            options.enableWatchdogTerminationTracking = enableWatchdogTerminationTracking
        }
        if let sendClientReports = data["sendClientReports"] as? Bool {
            options.sendClientReports = sendClientReports
        }
        if let maxAttachmentSize = data["maxAttachmentSize"] as? NSNumber {
            options.maxAttachmentSize = maxAttachmentSize.uintValue
        }
        if let recordHttpBreadcrumbs = data["recordHttpBreadcrumbs"] as? Bool {
            options.enableNetworkBreadcrumbs = recordHttpBreadcrumbs
        }
        if let captureFailedRequests = data["captureFailedRequests"] as? Bool {
            options.enableCaptureFailedRequests = captureFailedRequests
        }
        if let enableAppHangTracking = data["enableAppHangTracking"] as? Bool {
            options.enableAppHangTracking = enableAppHangTracking
        }
        if let appHangTimeoutIntervalMillis = data["appHangTimeoutIntervalMillis"] as? NSNumber {
            options.appHangTimeoutInterval = appHangTimeoutIntervalMillis.doubleValue / 1000
        }
        if let spotlightUrl = data["spotlightUrl"] as? String {
            options.spotlightUrl = spotlightUrl
        }
        if let enableSpotlight = data["enableSpotlight"] as? Bool {
            options.enableSpotlight = enableSpotlight
        }
        if let proxy = data["proxy"] as? [String: Any],
           let host = proxy["host"] as? String,
           let port = proxy["port"] as? Int,
           let type = proxy["type"] as? String {

            var connectionProxyDictionary: [String: Any]?
            if type.lowercased() == "http" {
                connectionProxyDictionary = [
                    kCFNetworkProxiesHTTPEnable as String: true,
                    kCFNetworkProxiesHTTPProxy as String: host,
                    kCFNetworkProxiesHTTPPort as String: port
                ]
            } else if type.lowercased() == "socks" {
                #if os(macOS)
                    connectionProxyDictionary = [
                        kCFNetworkProxiesSOCKSEnable as String: true,
                        kCFNetworkProxiesSOCKSProxy as String: host,
                        kCFNetworkProxiesSOCKSPort as String: port
                    ]
                #else
                    print("SOCKS proxy is not supported on iOS")
                #endif
            } else {
                print("Unknown proxy type: \(type)")
            }

            if var proxyDict = connectionProxyDictionary {
                if let user = proxy["user"] as? String, let pass = proxy["pass"] as? String {
                    proxyDict[kCFProxyUsernameKey as String] = user
                    proxyDict[kCFProxyPasswordKey as String] = pass
                }

                let configuration = URLSessionConfiguration.default
                configuration.connectionProxyDictionary = proxyDict
                options.urlSession = URLSession(configuration: configuration)
            }
        }
        #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
            if let replayOptions = data["replay"] as? [String: Any] {
                switch replayOptions["quality"] as? String {
                case "low":
                    options.sessionReplay.quality = SentryReplayOptions.SentryReplayQuality.low
                case "high":
                    options.sessionReplay.quality = SentryReplayOptions.SentryReplayQuality.high
                default:
                    options.sessionReplay.quality = SentryReplayOptions.SentryReplayQuality.medium
                }
                options.sessionReplay.sessionSampleRate =
                    (replayOptions["sessionSampleRate"] as? NSNumber)?.floatValue ?? 0
                options.sessionReplay.onErrorSampleRate =
                    (replayOptions["onErrorSampleRate"] as? NSNumber)?.floatValue ?? 0

                if let flutterSdk = data["sdk"] as? [String: Any] {
                    options.sessionReplay.setValue(
                        [
                            "name": flutterSdk["name"],
                            "version": flutterSdk["version"]
                        ], forKey: "sdkInfo")
                }
            }
        #endif
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
}
