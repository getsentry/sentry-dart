import 'dart:async';

import 'package:flutter/services.dart';
import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';

/// Enables Sentry's native SDKs (Android and iOS) with options.
class NativeSdkIntegration implements Integration<SentryFlutterOptions> {
  NativeSdkIntegration(this._channel);

  final MethodChannel _channel;
  SentryFlutterOptions? _options;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    _options = options;
    if (!options.autoInitializeNativeSdk) {
      return;
    }
    try {
      await _channel.invokeMethod('initNativeSdk', <String, dynamic>{
        'dsn': options.dsn,
        'debug': options.debug,
        'environment': options.environment,
        'release': options.release,
        'enableAutoSessionTracking': options.enableAutoSessionTracking,
        'enableNativeCrashHandling': options.enableNativeCrashHandling,
        'attachStacktrace': options.attachStacktrace,
        'attachThreads': options.attachThreads,
        'autoSessionTrackingIntervalMillis':
            options.autoSessionTrackingInterval.inMilliseconds,
        'dist': options.dist,
        'integrations': options.sdk.integrations,
        'packages':
            options.sdk.packages.map((e) => e.toJson()).toList(growable: false),
        'diagnosticLevel': options.diagnosticLevel.name,
        'maxBreadcrumbs': options.maxBreadcrumbs,
        'anrEnabled': options.anrEnabled,
        'anrTimeoutIntervalMillis': options.anrTimeoutInterval.inMilliseconds,
        'enableAutoNativeBreadcrumbs': options.enableAutoNativeBreadcrumbs,
        'maxCacheItems': options.maxCacheItems,
        'sendDefaultPii': options.sendDefaultPii,
        'enableWatchdogTerminationTracking':
            options.enableWatchdogTerminationTracking,
        'enableNdkScopeSync': options.enableNdkScopeSync,
        'enableAutoPerformanceTracing': options.enableAutoPerformanceTracing,
        'sendClientReports': options.sendClientReports,
        'proguardUuid': options.proguardUuid,
        'maxAttachmentSize': options.maxAttachmentSize,
        'captureFailedRequests': options.captureFailedRequests,
        'enableAppHangTracking': options.enableAppHangTracking,
        'connectionTimeoutMillis': options.connectionTimeout.inMilliseconds,
        'readTimeoutMillis': options.readTimeout.inMilliseconds,
        'appHangTimeoutIntervalMillis':
            options.appHangTimeoutInterval.inMilliseconds,
      });

      options.sdk.addIntegration('nativeSdkIntegration');
    } catch (exception, stackTrace) {
      options.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be installed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> close() async {
    final options = _options;
    if (options != null && !options.autoInitializeNativeSdk) {
      return;
    }
    try {
      await _channel.invokeMethod('closeNativeSdk');
    } catch (exception, stackTrace) {
      _options?.logger(
        SentryLevel.fatal,
        'nativeSdkIntegration failed to be closed',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
  }
}
