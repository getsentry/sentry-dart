import 'dart:async';
import 'dart:io';
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
import 'utils/data_normalizer.dart' as data_normalizer;

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
    if (Platform.isIOS) {
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
    } else {
      assert(false, 'init should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> close() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('closeNativeSdk');
    } else {
      assert(false, 'close should not be used through method channels on Android.');
    }
  }

  @override
  Future<NativeAppStart?> fetchNativeAppStart() async {
    if (Platform.isIOS) {
      final json =
          await channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
      return (json != null) ? NativeAppStart.fromJson(json) : null;
    } else {
      assert(false, 'fetchNativeAppStart should not be used through method channels on Android.');
      return null;
    }
  }

  @override
  bool get supportsCaptureEnvelope => true;

  @override
  Future<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) async {
    if (Platform.isIOS) {
      return channel.invokeMethod(
          'captureEnvelope', [envelopeData, containsUnhandledException]);
    } else {
      assert(false, 'captureEnvelope should not be used through method channels on Android.');
    }
  }

  @override
  FutureOr<void> captureStructuredEnvelope(SentryEnvelope envelope) {
    throw UnsupportedError("Not supported on this platform");
  }

  @override
  bool get supportsLoadContexts => true;

  @override
  Future<Map<String, dynamic>?> loadContexts() async {
    if (Platform.isIOS) {
      return channel.invokeMapMethod<String, dynamic>('loadContexts');
    } else {
      assert(false, 'loadContexts should not be used through method channels on Android.');
      return null;
    }
  }

  @override
  Future<void> setUser(SentryUser? user) async {
    if (Platform.isIOS) {
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
          data: data_normalizer.normalizeMap(user.data),
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
    } else {
      assert(false, 'setUser should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> addBreadcrumb(Breadcrumb breadcrumb) async {
    if (Platform.isIOS) {
      final normalizedBreadcrumb = Breadcrumb(
        message: breadcrumb.message,
        category: breadcrumb.category,
        data: data_normalizer.normalizeMap(breadcrumb.data),
        level: breadcrumb.level,
        type: breadcrumb.type,
        timestamp: breadcrumb.timestamp,
        // ignore: invalid_use_of_internal_member
        unknown: breadcrumb.unknown,
      );
      await channel.invokeMethod(
        'addBreadcrumb',
        {'breadcrumb': normalizedBreadcrumb.toJson()},
      );
    } else {
      assert(false, 'addBreadcrumb should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> clearBreadcrumbs() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('clearBreadcrumbs');
    } else {
      assert(false, 'clearBreadcrumbs should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> setContexts(String key, dynamic value) async {
    if (Platform.isIOS) {
      return channel.invokeMethod(
        'setContexts',
        {'key': key, 'value': data_normalizer.normalize(value)},
      );
    } else {
      assert(false, 'setContexts should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> removeContexts(String key) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('removeContexts', {'key': key});
    } else {
      assert(false, 'removeContexts should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> setExtra(String key, dynamic value) async {
    if (Platform.isIOS) {
      return channel.invokeMethod(
        'setExtra',
        {'key': key, 'value': data_normalizer.normalize(value)},
      );
    } else {
      assert(false, 'setExtra should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> removeExtra(String key) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('removeExtra', {'key': key});
    } else {
      assert(false, 'removeExtra should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> setTag(String key, String value) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('setTag', {'key': key, 'value': value});
    } else {
      assert(false, 'setTag should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> removeTag(String key) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('removeTag', {'key': key});
    } else {
      assert(false, 'removeTag should not be used through method channels on Android.');
    }
  }

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  Future<void> discardProfiler(SentryId traceId) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('discardProfiler', traceId.toString());
    } else {
      assert(false, 'discardProfiler should not be used through method channels on Android.');
    }
  }

  @override
  Future<Map<String, dynamic>?> collectProfile(
          SentryId traceId, int startTimeNs, int endTimeNs) async {
    if (Platform.isIOS) {
      return channel.invokeMapMethod<String, dynamic>('collectProfile', {
        'traceId': traceId.toString(),
        'startTime': startTimeNs,
        'endTime': endTimeNs,
      });
    } else {
      assert(false, 'collectProfile should not be used through method channels on Android.');
      return null;
    }
  }

  @override
  Future<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) async {
    if (Platform.isIOS) {
      return tryCatchAsync('loadDebugImages', () async {
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
    } else {
      assert(false, 'loadDebugImages should not be used through method channels on Android.');
      return null;
    }
  }

  @override
  Future<int?> displayRefreshRate() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('displayRefreshRate');
    } else {
      assert(false, 'displayRefreshRate should not be used through method channels on Android.');
      return null;
    }
  }

  @override
  Future<void> pauseAppHangTracking() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('pauseAppHangTracking');
    } else {
      assert(false, 'pauseAppHangTracking should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> resumeAppHangTracking() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('resumeAppHangTracking');
    } else {
      assert(false, 'resumeAppHangTracking should not be used through method channels on Android.');
    }
  }

  @override
  Future<void> nativeCrash() async {
    if (Platform.isIOS) {
      return channel.invokeMethod('nativeCrash');
    } else {
      assert(false, 'nativeCrash should not be used through method channels on Android.');
    }
  }

  @override
  bool get supportsReplay => false;

  @override
  SentryId? get replayId => null;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) async {
    if (Platform.isIOS) {
      return channel.invokeMethod('setReplayConfig', {
        'windowWidth': config.windowWidth,
        'windowHeight': config.windowHeight,
        'width': config.width,
        'height': config.height,
        'frameRate': config.frameRate,
      });
    } else {
      assert(false, 'setReplayConfig should not be used through method channels on Android.');
    }
  }

  @override
  Future<SentryId> captureReplay() async {
    if (Platform.isIOS) {
      return channel
          .invokeMethod('captureReplay')
          .then((value) => SentryId.fromId(value as String));
    } else {
      assert(false, 'captureReplay should not be used through method channels on Android.');
      return SentryId.empty();
    }
  }

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
