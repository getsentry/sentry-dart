import '../sentry_flutter_options.dart';

extension SentryFlutterOptionsNativeJson on SentryFlutterOptions {
  Map<String, dynamic> toNativeInitJson() {
    return <String, dynamic>{
      'dsn': dsn,
      'debug': debug,
      'environment': environment,
      'release': release,
      'enableAutoSessionTracking': enableAutoSessionTracking,
      'enableNativeCrashHandling': enableNativeCrashHandling,
      'attachStacktrace': attachStacktrace,
      'attachThreads': attachThreads,
      'autoSessionTrackingIntervalMillis':
          autoSessionTrackingInterval.inMilliseconds,
      'dist': dist,
      'sdk': sdk.toJson(),
      'diagnosticLevel': diagnosticLevel.name,
      'maxBreadcrumbs': maxBreadcrumbs,
      'anrEnabled': anrEnabled,
      'anrTimeoutIntervalMillis': anrTimeoutInterval.inMilliseconds,
      'enableAutoNativeBreadcrumbs': enableAutoNativeBreadcrumbs,
      'maxCacheItems': maxCacheItems,
      'sendDefaultPii': sendDefaultPii,
      'enableWatchdogTerminationTracking': enableWatchdogTerminationTracking,
      'enableNdkScopeSync': enableNdkScopeSync,
      'enableAutoPerformanceTracing': enableAutoPerformanceTracing,
      'sendClientReports': sendClientReports,
      'proguardUuid': proguardUuid,
      'maxAttachmentSize': maxAttachmentSize,
      'recordHttpBreadcrumbs': recordHttpBreadcrumbs,
      'captureFailedRequests': captureFailedRequests,
      'enableAppHangTracking': enableAppHangTracking,
      'connectionTimeoutMillis': connectionTimeout.inMilliseconds,
      'readTimeoutMillis': readTimeout.inMilliseconds,
      'appHangTimeoutIntervalMillis': appHangTimeoutInterval.inMilliseconds,
      if (proxy != null) 'proxy': proxy?.toJson(),
      'replay': <String, dynamic>{
        'quality': replay.quality.name,
        'sessionSampleRate': replay.sessionSampleRate,
        'onErrorSampleRate': replay.onErrorSampleRate,
        'tags': <String, dynamic>{
          'maskAllText': privacy.maskAllText,
          'maskAllImages': privacy.maskAllImages,
          'maskAssetImages': privacy.maskAssetImages,
          if (privacy.userMaskingRules.isNotEmpty)
            'maskingRules': privacy.userMaskingRules
                .map((rule) => '${rule.name}: ${rule.description}')
                .toList(growable: false),
        },
      },
      'enableSpotlight': spotlight.enabled,
      'spotlightUrl': spotlight.url,
    };
  }
}
