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
