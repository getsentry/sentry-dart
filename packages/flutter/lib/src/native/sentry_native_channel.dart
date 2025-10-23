import 'dart:async';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../replay/replay_config.dart';
import 'native_app_start.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_invoker.dart';
import 'sentry_safe_method_channel.dart';
import 'utils/data_normalizer.dart';

/// Provide typed methods to access native layer via MethodChannel.
@internal
class SentryNativeChannel
    with SentryNativeSafeInvoker
    implements SentryNativeBinding {
  @override
  final SentryFlutterOptions options;

  @protected
  final SentrySafeMethodChannel channel;

  SentryNativeChannel(this.options)
      : channel = SentrySafeMethodChannel(options);

  void _logNotSupported(String operation) => options.log(
      SentryLevel.debug, 'SentryNativeChannel: $operation is not supported');

  @override
  Future<void> init(Hub hub) async {
    return channel.invokeMethod('initNativeSdk', <String, dynamic>{
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
      'sdk': options.sdk.toJson(),
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
      'recordHttpBreadcrumbs': options.recordHttpBreadcrumbs,
      'captureFailedRequests': options.captureFailedRequests,
      'enableAppHangTracking': options.enableAppHangTracking,
      'connectionTimeoutMillis': options.connectionTimeout.inMilliseconds,
      'readTimeoutMillis': options.readTimeout.inMilliseconds,
      'appHangTimeoutIntervalMillis':
          options.appHangTimeoutInterval.inMilliseconds,
      if (options.proxy != null) 'proxy': options.proxy?.toJson(),
      'replay': <String, dynamic>{
        'quality': options.replay.quality.name,
        'sessionSampleRate': options.replay.sessionSampleRate,
        'onErrorSampleRate': options.replay.onErrorSampleRate,
        'tags': <String, dynamic>{
          'maskAllText': options.privacy.maskAllText,
          'maskAllImages': options.privacy.maskAllImages,
          'maskAssetImages': options.privacy.maskAssetImages,
          if (options.privacy.userMaskingRules.isNotEmpty)
            'maskingRules': options.privacy.userMaskingRules
                .map((rule) => '${rule.name}: ${rule.description}')
                .toList(growable: false),
        },
      },
      'enableSpotlight': options.spotlight.enabled,
      'spotlightUrl': options.spotlight.url,
    });
  }

  @override
  Future<void> close() async => channel.invokeMethod('closeNativeSdk');

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() async {
    assert(false,
        'fetchNativeAppStart should not be used through method channels.');
    return null;
  }

  @override
  bool get supportsCaptureEnvelope => true;

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    assert(
        false, "captureEnvelope should not be used through method channels.");
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) {
    throw UnsupportedError("Not supported on this platform");
  }

  @override
  bool get supportsLoadContexts => true;

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    assert(false, 'loadContexts should not be used through method channels.');
    return null;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    if (user == null) {
      await channel.invokeMethod(
        'setUser',
        {'user': null},
      );
    } else {
      final normalizedUser = SentryUser(
        id: user.id,
        username: user.username,
        email: user.email,
        ipAddress: user.ipAddress,
        data: normalizeMap(user.data),
        // ignore: deprecated_member_use
        extras: user.extras,
        geo: user.geo,
        name: user.name,
        // ignore: invalid_use_of_internal_member
        unknown: user.unknown,
      );
      await channel.invokeMethod(
        'setUser',
        {'user': normalizedUser.toJson()},
      );
    }
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    assert(false, "addBreadcrumb should not be used through method channels.");
  }

  @override
  FutureOr<void> clearBreadcrumbs() async {
    assert(
        false, "clearBreadcrumbs should not be used through method channels.");
  }

  @override
  Future<void> setContexts(String key, dynamic value) => channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': normalize(value)},
      );

  @override
  Future<void> removeContexts(String key) =>
      channel.invokeMethod('removeContexts', {'key': key});

  @override
  Future<void> setExtra(String key, dynamic value) => channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': normalize(value)},
      );

  @override
  Future<void> removeExtra(String key) =>
      channel.invokeMethod('removeExtra', {'key': key});

  @override
  Future<void> setTag(String key, String value) =>
      channel.invokeMethod('setTag', {'key': key, 'value': value});

  @override
  Future<void> removeTag(String key) =>
      channel.invokeMethod('removeTag', {'key': key});

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  Future<void> discardProfiler(SentryId traceId) =>
      channel.invokeMethod('discardProfiler', traceId.toString());

  @override
  Future<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) =>
      channel.invokeMapMethod<String, dynamic>('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTimeNs,
        'endTime': endTimeNs,
      });

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    assert(
        false, "loadDebugImages should not be used through method channels.");
    return null;
  }

  @override
  FutureOr<int?> displayRefreshRate() {
    assert(false,
        'displayRefreshRate should not be used through method channels.');
    return null;
  }

  @override
  FutureOr<void> pauseAppHangTracking() {
    assert(false,
        'pauseAppHangTracking should not be used through method channels.');
  }

  @override
  FutureOr<void> resumeAppHangTracking() {
    assert(false,
        'resumeAppHangTracking should not be used through method channels.');
  }

  @override
  FutureOr<void> nativeCrash() {
    assert(false, 'nativeCrash should not be used through method channels.');
  }

  @override
  bool get supportsReplay => false;

  @override
  SentryId? get replayId => null;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) =>
      channel.invokeMethod('setReplayConfig', {
        'windowWidth': config.windowWidth,
        'windowHeight': config.windowHeight,
        'width': config.width,
        'height': config.height,
        'frameRate': config.frameRate,
      });

  @override
  FutureOr<SentryId> captureReplay() => channel
      .invokeMethod('captureReplay')
      .then((value) => SentryId.fromId(value as String));

  @override
  FutureOr<void> captureSession() {
    _logNotSupported('capturing session');
  }

  @override
  FutureOr<void> startSession({bool ignoreDuration = false}) {
    _logNotSupported('starting session');
  }

  @override
  FutureOr<Map<dynamic, dynamic>?> getSession() {
    _logNotSupported('getting session');
    return null;
  }

  @override
  FutureOr<void> updateSession({int? errors, String? status}) {
    _logNotSupported('updating session');
  }
}
