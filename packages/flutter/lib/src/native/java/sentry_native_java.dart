// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../../utils/internal_logger.dart';
import '../native_app_start.dart';
import '../sentry_native_channel.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
import 'android_core_worker.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as native;

part 'sentry_native_java_init.dart';

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidCoreWorker? _coreWorker;
  native.ReplayIntegration? _nativeReplay;

  SentryNativeJava(super.options) {
    // Initialize core worker here in the ctor instead of init().
    // Ensures it starts when autoInitializeNativeSdk is enabled and disabled.
    _coreWorker = AndroidCoreWorker.factory(options);
    _coreWorker?.start();
  }

  @override
  bool get supportsReplay => true;

  @override
  SentryId? get replayId => _replayId;
  SentryId? _replayId;

  @visibleForTesting
  AndroidReplayRecorder? get testRecorder => _replayRecorder;

  void _setNativeReplay(native.ReplayIntegration? nativeReplay) {
    _nativeReplay?.release();
    _nativeReplay = nativeReplay;
  }

  @override
  void init(Hub hub) {
    initSentryAndroid(hub: hub, options: options, owner: this);
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _coreWorker?.captureEnvelope(envelopeData, containsUnhandledException);
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) =>
      _coreWorker?.loadDebugImages(stackTrace);

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() => _coreWorker?.loadContexts();

  @override
  int? displayRefreshRate() => tryCatchSync('displayRefreshRate', () {
        return native.SentryFlutterPlugin.displayRefreshRate
            ?.toDartInt(releaseOriginal: true);
      });

  @override
  NativeAppStart? fetchNativeAppStart() {
    JByteArray? appStartUtf8JsonBytes;

    return tryCatchSync('fetchNativeAppStart', () {
      if (!options.enableAutoPerformanceTracing) {
        return null;
      }
      appStartUtf8JsonBytes =
          native.SentryFlutterPlugin.fetchNativeAppStartAsBytes();
      if (appStartUtf8JsonBytes == null) return null;

      final byteRange =
          appStartUtf8JsonBytes!.getRange(0, appStartUtf8JsonBytes!.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      final appStartMap = decodeUtf8JsonMap(bytes);
      return NativeAppStart.fromJson(appStartMap);
    }, finallyFn: () {
      appStartUtf8JsonBytes?.release();
    });
  }

  @override
  void nativeCrash() {
    native.SentryFlutterPlugin.crash();
  }

  @override
  void pauseAppHangTracking() {
    assert(false, 'pauseAppHangTracking is not supported on Android.');
  }

  @override
  void resumeAppHangTracking() {
    assert(false, 'resumeAppHangTracking is not supported on Android.');
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    await _coreWorker?.close();
    _setNativeReplay(null);
    return super.close();
  }

  @override
  FutureOr<void> addBreadcrumb(Breadcrumb breadcrumb) =>
      _coreWorker?.addBreadcrumb(breadcrumb);

  @override
  FutureOr<void> clearBreadcrumbs() => _coreWorker?.clearBreadcrumbs();

  @override
  FutureOr<void> setUser(SentryUser? user) => _coreWorker?.setUser(user);

  @override
  FutureOr<void> setContexts(String key, value) =>
      _coreWorker?.setContexts(key, value);

  @override
  FutureOr<void> removeContexts(String key) => _coreWorker?.removeContexts(key);

  @override
  void setTag(String key, String value) => tryCatchSync('setTag', () {
        using((arena) {
          final jKey = key.toJString()..releasedBy(arena);
          final jVal = value.toJString()..releasedBy(arena);
          native.Sentry.setTag(jKey, jVal);
        });
      });

  @override
  void removeTag(String key) => tryCatchSync('removeTag', () {
        using((arena) {
          final jKey = key.toJString()..releasedBy(arena);
          native.Sentry.removeTag(jKey);
        });
      });

  @override
  void setExtra(String key, dynamic value) => tryCatchSync('setExtra', () {
        using((arena) {
          final jKey = key.toJString()..releasedBy(arena);
          final jVal = normalize(value).toString().toJString()
            ..releasedBy(arena);

          native.Sentry.setExtra(jKey, jVal);
        });
      });

  @override
  void removeExtra(String key) => tryCatchSync('removeExtra', () {
        using((arena) {
          final jKey = key.toJString()..releasedBy(arena);
          native.Sentry.removeExtra(jKey);
        });
      });

  @override
  SentryId captureReplay() {
    final id = tryCatchSync<SentryId>('captureReplay', () {
      return using((arena) {
        _nativeReplay ??=
            native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
        // The passed parameter is `isTerminating`
        _nativeReplay?.captureReplay(false.toJBoolean()..releasedBy(arena));

        final nativeReplayId = _nativeReplay?.replayId;
        nativeReplayId?.releasedBy(arena);

        JString? jString;
        if (nativeReplayId != null) {
          jString = nativeReplayId.toString$1();
          jString?.releasedBy(arena);
        }

        final result = jString == null
            ? SentryId.empty()
            : SentryId.fromId(jString.toDartString());

        _replayId = result;
        return result;
      });
    });

    return id ?? SentryId.empty();
  }

  @override
  void setReplayConfig(ReplayConfig config) =>
      tryCatchSync('setReplayConfig', () {
        // Since codec block size is 16, so we have to adjust the width and height to it,
        // otherwise the codec might fail to configure on some devices, see
        // https://cs.android.com/android/platform/superproject/+/master:frameworks/base/media/java/android/media/MediaCodecInfo.java;l=1999-2001
        final invalidConfig = config.width == 0.0 ||
            config.height == 0.0 ||
            config.windowWidth == 0.0 ||
            config.windowHeight == 0.0;
        if (invalidConfig) {
          internalLogger.error(
            'Replay config is not valid: '
            'width: ${config.width}, '
            'height: ${config.height}, '
            'windowWidth: ${config.windowWidth}, '
            'windowHeight: ${config.windowHeight}',
          );
          return;
        }

        var adjWidth = config.width;
        var adjHeight = config.height;

        // First update the smaller dimension, as changing that will affect the screen ratio more.
        if (adjWidth < adjHeight) {
          final newWidth = adjWidth.adjustReplaySizeToBlockSize();
          final scale = newWidth / adjWidth;
          final newHeight = (adjHeight * scale).adjustReplaySizeToBlockSize();
          adjWidth = newWidth;
          adjHeight = newHeight;
        } else {
          final newHeight = adjHeight.adjustReplaySizeToBlockSize();
          final scale = newHeight / adjHeight;
          final newWidth = (adjWidth * scale).adjustReplaySizeToBlockSize();
          adjHeight = newHeight;
          adjWidth = newWidth;
        }

        final replayConfig = native.ScreenshotRecorderConfig(
          adjWidth.round(),
          adjHeight.round(),
          adjWidth / config.windowWidth,
          adjHeight / config.windowHeight,
          config.frameRate,
          0, // bitRate is currently not used
        );

        _nativeReplay ??=
            native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
        _nativeReplay?.onConfigurationChanged(replayConfig);

        replayConfig.release();
      });

  @override
  bool get supportsTraceSync => true;

  @override
  void setTrace(SentryId traceId, SpanId spanId) {
    tryCatchSync('setTrace', () {
      using((arena) {
        final jTraceId = traceId.toString().toJString()..releasedBy(arena);
        final jSpanId = spanId.toString().toJString()..releasedBy(arena);
        // The two double parameters are sampleRate and sampleRand.
        // We pass null for them because we don't need to support sampleRate and sampleRand.
        // sampleRate and sampleRand are only used by native for baggage headers
        // on outgoing HTTP requests. Since HTTP requests in Flutter go through
        // Dart, the Dart-side propagation context handles baggage already.
        // When there is a use case for sampleRate and sampleRand, we can add support for them.
        native.InternalSentrySdk.setTrace(jTraceId, jSpanId, null, null);
      });
    });
  }

  @override
  void registerTraceId(SentryId traceId) {
    if (traceId == SentryId.empty()) {
      return;
    }

    tryCatchSync('registerTraceId', () {
      using((arena) {
        final jTraceId = traceId.toString().toJString()..releasedBy(arena);
        final sentryId = native.SentryId.new$2(jTraceId)..releasedBy(arena);
        _nativeReplay ??=
            native.SentryFlutterPlugin.privateSentryGetReplayIntegration();
        _nativeReplay?.registerTraceId(sentryId);
      });
    });
  }
}

// Direct JNI conversion is fine for primitives. Use the Map/List conversion
// branches below only for small, known-shape payloads. Arbitrary,
// user-controlled, or potentially large maps/lists should cross JNI as UTF-8
// JSON bytes and be deserialized on the Java/Kotlin side to avoid per-entry JNI
// calls and local reference churn.
@visibleForTesting
JObject dartToJObject(Object? value) => switch (value) {
      String s => s.toJString(),
      bool b => b.toJBoolean(),
      int i => i.toJLong(),
      double d => d.toJDouble(),
      List<dynamic> l => dartToJList(l),
      Map<String, dynamic> m => dartToJMap(m),
      _ => value.toString().toJString()
    };

@visibleForTesting
JByteArray jsonToJByteArray(Object? value) =>
    _toJByteArray(encodeUtf8Json(normalize(value)));

@visibleForTesting
JList<JObject?> dartToJList(List<dynamic> values) {
  final jList = JArrayList<JObject>();
  for (final v in values.nonNulls) {
    final j = dartToJObject(v);
    jList.add(j);
    j.release();
  }
  return jList;
}

@visibleForTesting
JMap<JString?, JObject?> dartToJMap(Map<String, dynamic> json) {
  final jMap = JHashMap<JString, JObject>();
  for (final entry in json.entries.where((e) => e.value != null)) {
    final jk = entry.key.toJString();
    final jv = dartToJObject(entry.value);
    jMap.put(jk, jv);
    jk.release();
    jv.release();
  }
  return jMap;
}

/// Builds a [JByteArray] from Dart [bytes]. JNIgen 1.0.0 dropped the
/// `JByteArray.from` factory in favour of allocate-then-fill.
JByteArray _toJByteArray(List<int> bytes) =>
    JByteArray(bytes.length)..setRange(0, bytes.length, bytes);

const _videoBlockSize = 16;

@visibleForTesting
extension ReplaySizeAdjustment on double {
  double adjustReplaySizeToBlockSize() {
    final remainder = this % _videoBlockSize;
    if (remainder <= _videoBlockSize / 2) {
      return this - remainder;
    } else {
      return this + (_videoBlockSize - remainder);
    }
  }
}
