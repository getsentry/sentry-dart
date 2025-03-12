import 'dart:async';
// backcompatibility for Flutter < 3.3
// ignore: unnecessary_import
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../replay/replay_config.dart';
import 'method_channel_helper.dart';
import 'native_app_start.dart';
import 'native_frames.dart';
import 'sentry_native_binding.dart';
import 'sentry_native_invoker.dart';
import 'sentry_safe_method_channel.dart';

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
  Future<NativeAppStart?> fetchNativeAppStart() async {
    final json =
        await channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
    return (json != null) ? NativeAppStart.fromJson(json) : null;
  }

  @override
  bool get supportsCaptureEnvelope => true;

  @override
  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    return channel.invokeMethod(
        'captureEnvelope', [envelopeData, containsUnhandledException]);
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) {
    throw UnsupportedError("Not supported on this platform");
  }

  @override
  bool get supportsLoadContexts => true;

  @override
  Future<Map<String, dynamic>?> loadContexts() =>
      channel.invokeMapMethod<String, dynamic>('loadContexts');

  @override
  Future<void> beginNativeFrames() => channel.invokeMethod('beginNativeFrames');

  @override
  Future<NativeFrames?> endNativeFrames(SentryId id) async {
    final json = await channel.invokeMapMethod<String, dynamic>(
        'endNativeFrames', {'id': id.toString()});
    return (json != null) ? NativeFrames.fromJson(json) : null;
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    final normalizedUser = user?.copyWith(
      data: MethodChannelHelper.normalizeMap(user.data),
    );
    await channel.invokeMethod(
      'setUser',
      {'user': normalizedUser?.toJson()},
    );
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    final normalizedBreadcrumb = breadcrumb.copyWith(
      data: MethodChannelHelper.normalizeMap(breadcrumb.data),
    );
    await channel.invokeMethod(
      'addBreadcrumb',
      {'breadcrumb': normalizedBreadcrumb.toJson()},
    );
  }

  @override
  Future<void> clearBreadcrumbs() => channel.invokeMethod('clearBreadcrumbs');

  @override
  Future<void> setContexts(String key, dynamic value) => channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
      );

  @override
  Future<void> removeContexts(String key) =>
      channel.invokeMethod('removeContexts', {'key': key});

  @override
  Future<void> setExtra(String key, dynamic value) => channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': MethodChannelHelper.normalize(value)},
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
  Future<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) =>
      tryCatchAsync('loadDebugImages', () async {
        Set<String> instructionAddresses = {};
        for (final frame in stackTrace.frames) {
          if (frame.instructionAddr != null) {
            instructionAddresses.add(frame.instructionAddr!);
          }
        }

        final images = await channel.invokeListMethod<Map<dynamic, dynamic>>(
            'loadImageList', instructionAddresses.toList());
        return images
            ?.map((e) => e.cast<String, dynamic>())
            .map(DebugImage.fromJson)
            .toList();
      });

  @override
  Future<int?> displayRefreshRate() =>
      channel.invokeMethod('displayRefreshRate');

  @override
  Future<void> pauseAppHangTracking() =>
      channel.invokeMethod('pauseAppHangTracking');

  @override
  Future<void> resumeAppHangTracking() =>
      channel.invokeMethod('resumeAppHangTracking');

  @override
  Future<void> nativeCrash() => channel.invokeMethod('nativeCrash');

  @override
  bool get supportsReplay => false;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) =>
      channel.invokeMethod('setReplayConfig', {
        'width': config.width,
        'height': config.height,
        'frameRate': config.frameRate,
      });

  @override
  Future<SentryId> captureReplay(bool isCrash) =>
      channel.invokeMethod('captureReplay', {
        'isCrash': isCrash,
      }).then((value) => SentryId.fromId(value as String));
}
