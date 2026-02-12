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
  FutureOr<void> init(Hub hub) {
    if (options.platform.isAndroid) {
      assert(
          false, 'init should not be used through method channels on Android.');
      return null;
    }
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
      'captureFailedRequests':
          options.captureNativeFailedRequests ?? options.captureFailedRequests,
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
  FutureOr<void> close() {
    return channel.invokeMethod('closeNativeSdk');
  }

  @override
  FutureOr<NativeAppStart?> fetchNativeAppStart() async {
    if (options.platform.isAndroid) {
      assert(false,
          'fetchNativeAppStart should not be used through method channels on Android.');
      return null;
    }
    final json =
        await channel.invokeMapMethod<String, dynamic>('fetchNativeAppStart');
    return (json != null) ? NativeAppStart.fromJson(json) : null;
  }

  @override
  bool get supportsCaptureEnvelope => true;

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    if (options.platform.isAndroid) {
      assert(false,
          'captureEnvelope should not be used through method channels on Android.');
      return null;
    }
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
  FutureOr<Map<String, dynamic>?> loadContexts() {
    if (options.platform.isAndroid) {
      assert(false,
          'loadContexts should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMapMethod<String, dynamic>('loadContexts');
  }

  @override
  FutureOr<void> setUser(SentryUser? user) async {
    if (options.platform.isAndroid) {
      assert(false,
          'setUser should not be used through method channels on Android.');
      return;
    }
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
    if (options.platform.isAndroid) {
      assert(false,
          'addBreadcrumb should not be used through method channels on Android.');
      return;
    }
    final normalizedBreadcrumb = Breadcrumb(
      message: breadcrumb.message,
      category: breadcrumb.category,
      data: normalizeMap(breadcrumb.data),
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
  }

  @override
  FutureOr<void> clearBreadcrumbs() {
    if (options.platform.isAndroid) {
      assert(false,
          'clearBreadcrumbs should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('clearBreadcrumbs');
  }

  @override
  FutureOr<void> setContexts(String key, dynamic value) {
    if (options.platform.isAndroid) {
      assert(false,
          'setContexts should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod(
      'setContexts',
      {'key': key, 'value': normalize(value)},
    );
  }

  @override
  FutureOr<void> removeContexts(String key) {
    if (options.platform.isAndroid) {
      assert(false,
          'removeContexts should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('removeContexts', {'key': key});
  }

  @override
  FutureOr<void> setExtra(String key, dynamic value) {
    if (options.platform.isAndroid) {
      assert(false,
          'setExtra should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod(
      'setExtra',
      {'key': key, 'value': normalize(value)},
    );
  }

  @override
  FutureOr<void> removeExtra(String key) {
    if (options.platform.isAndroid) {
      assert(false,
          'removeExtra should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('removeExtra', {'key': key});
  }

  @override
  FutureOr<void> setTag(String key, String value) {
    if (options.platform.isAndroid) {
      assert(false,
          'setTag should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('setTag', {'key': key, 'value': value});
  }

  @override
  FutureOr<void> removeTag(String key) {
    if (options.platform.isAndroid) {
      assert(false,
          'removeTag should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('removeTag', {'key': key});
  }

  @override
  int? startProfiler(SentryId traceId) =>
      throw UnsupportedError("Not supported on this platform");

  @override
  FutureOr<void> discardProfiler(SentryId traceId) {
    if (options.platform.isAndroid) {
      assert(false,
          'discardProfiler should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('discardProfiler', traceId.toString());
  }

  @override
  FutureOr<Map<String, dynamic>?> collectProfile(
      SentryId traceId, int startTimeNs, int endTimeNs) {
    if (options.platform.isAndroid) {
      assert(false,
          'collectProfile should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMapMethod<String, dynamic>('collectProfile', {
      'traceId': traceId.toString(),
      'startTime': startTimeNs,
      'endTime': endTimeNs,
    });
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    if (options.platform.isAndroid) {
      assert(false,
          'loadDebugImages should not be used through method channels on Android.');
      return null;
    }
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
  }

  @override
  FutureOr<int?> displayRefreshRate() {
    if (options.platform.isAndroid) {
      assert(false,
          'displayRefreshRate should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('displayRefreshRate');
  }

  @override
  FutureOr<void> pauseAppHangTracking() {
    if (options.platform.isAndroid) {
      assert(false,
          'pauseAppHangTracking should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('pauseAppHangTracking');
  }

  @override
  FutureOr<void> resumeAppHangTracking() {
    if (options.platform.isAndroid) {
      assert(false,
          'resumeAppHangTracking should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('resumeAppHangTracking');
  }

  @override
  FutureOr<void> nativeCrash() {
    if (options.platform.isAndroid) {
      assert(false,
          'nativeCrash should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('nativeCrash');
  }

  @override
  bool get supportsReplay => false;

  @override
  SentryId? get replayId => null;

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    if (options.platform.isAndroid) {
      assert(false,
          'setReplayConfig should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('setReplayConfig', {
      'windowWidth': config.windowWidth,
      'windowHeight': config.windowHeight,
      'width': config.width,
      'height': config.height,
      'frameRate': config.frameRate,
    });
  }

  @override
  FutureOr<SentryId> captureReplay() {
    if (options.platform.isAndroid) {
      assert(false,
          'captureReplay should not be used through method channels on Android.');
      return SentryId.empty();
    }
    return channel
        .invokeMethod('captureReplay')
        .then((value) => SentryId.fromId(value as String));
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

  // Android handles supportings trace sync via JNI, not method channels.
  @override
  bool get supportsTraceSync => !options.platform.isAndroid;

  @override
  FutureOr<void> setTrace(SentryId traceId, SpanId spanId) {
    if (options.platform.isAndroid) {
      assert(false,
          'setTrace should not be used through method channels on Android.');
      return null;
    }
    return channel.invokeMethod('setTrace', {
      'traceId': traceId.toString(),
      'spanId': spanId.toString(),
    });
  }
}
