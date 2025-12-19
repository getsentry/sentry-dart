import 'dart:async';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../native_app_start.dart';
import '../sentry_native_channel.dart';
import '../utils/data_normalizer.dart';
import '../utils/utf8_json.dart';
import 'android_envelope_sender.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as native;

part 'sentry_native_java_init.dart';

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidEnvelopeSender? _envelopeSender;
  native.ReplayIntegration? _nativeReplay;

  SentryNativeJava(super.options) {
    // Initialize envelope sender here instead of init() to ensure it starts
    // in both autoInitializeNativeSdk enabled and disabled cases.
    _envelopeSender = AndroidEnvelopeSender.factory(options);
    _envelopeSender!.start();
  }

  @override
  bool get supportsReplay => true;

  @override
  SentryId? get replayId => _replayId;
  SentryId? _replayId;

  @visibleForTesting
  AndroidReplayRecorder? get testRecorder => _replayRecorder;

  @override
  void init(Hub hub) {
    initSentryAndroid(hub: hub, options: options, owner: this);
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    _envelopeSender?.captureEnvelope(envelopeData, containsUnhandledException);
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    JSet<JString>? instructionAddressSet;
    Set<JString>? instructionAddressJStrings;
    JByteArray? imagesUtf8JsonBytes;

    try {
      instructionAddressJStrings = stackTrace.frames
          .map((f) => f.instructionAddr)
          .nonNulls
          .map((s) => s.toJString())
          .toSet();

      instructionAddressSet = instructionAddressJStrings.nonNulls
          .cast<JString>()
          .toJSet(JString.type);

      // Use a single JNI call to get images as UTF-8 encoded JSON instead of
      // making multiple JNI calls to convert each object individually. This approach
      // is significantly faster because images can be large.
      // Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting JNI objects to Dart objects one by one.

      // NOTE: when instructionAddressSet is empty, loadDebugImagesAsBytes will return
      // all debug images as fallback.
      imagesUtf8JsonBytes = native.SentryFlutterPlugin.loadDebugImagesAsBytes(
          instructionAddressSet);
      if (imagesUtf8JsonBytes == null) return null;

      final byteRange =
          imagesUtf8JsonBytes.getRange(0, imagesUtf8JsonBytes.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      final debugImageMaps = decodeUtf8JsonListOfMaps(bytes);
      return debugImageMaps.map(DebugImage.fromJson).toList(growable: false);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'JNI: Failed to load debug images',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      // Release JNI refs
      for (final js in instructionAddressJStrings ?? const <JString>[]) {
        js.release();
      }
      instructionAddressSet?.release();
      imagesUtf8JsonBytes?.release();
    }

    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() {
    JByteArray? contextsUtf8JsonBytes;

    try {
      // Use a single JNI call to get contexts as UTF-8 encoded JSON instead of
      // making multiple JNI calls to convert each object individually. This approach
      // is significantly faster because contexts can be large and contain many nested
      // objects. Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting JNI objects to Dart objects one by one.
      contextsUtf8JsonBytes = native.SentryFlutterPlugin.loadContextsAsBytes();
      if (contextsUtf8JsonBytes == null) return null;

      final byteRange =
          contextsUtf8JsonBytes.getRange(0, contextsUtf8JsonBytes.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      return decodeUtf8JsonMap(bytes);
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'JNI: Failed to load contexts',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      contextsUtf8JsonBytes?.release();
    }

    return null;
  }

  @override
  int? displayRefreshRate() => tryCatchSync('displayRefreshRate', () {
        return native.SentryFlutterPlugin.getDisplayRefreshRate()
            ?.intValue(releaseOriginal: true);
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
    await _envelopeSender?.close();
    _nativeReplay?.release();
    return super.close();
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) =>
      tryCatchSync('addBreadcrumb', () {
        using((arena) {
          final scopesAdapter = native.ScopesAdapter.getInstance()
            ?..releasedBy(arena);
          if (scopesAdapter == null) return;
          final nativeOptions = scopesAdapter.getOptions()..releasedBy(arena);

          final jMap = dartToJMap(breadcrumb.toJson());
          final nativeBreadcrumb =
              native.Breadcrumb.fromMap(jMap, nativeOptions)
                ?..releasedBy(arena);
          // release jMap directly after use
          jMap.release();
          if (nativeBreadcrumb == null) return;
          native.Sentry.addBreadcrumb$1(nativeBreadcrumb);
        });
      });

  @override
  void clearBreadcrumbs() => tryCatchSync('clearBreadcrumbs', () {
        native.Sentry.clearBreadcrumbs();
      });

  @override
  void setUser(SentryUser? user) => tryCatchSync('setUser', () {
        using((arena) {
          if (user == null) {
            native.Sentry.setUser(null);
          } else {
            final scopesAdapter = native.ScopesAdapter.getInstance()
              ?..releasedBy(arena);
            if (scopesAdapter == null) return;
            final nativeOptions = scopesAdapter.getOptions()..releasedBy(arena);

            final jMap = dartToJMap(user.toJson());
            final nativeUser = native.User.fromMap(jMap, nativeOptions)
              ?..releasedBy(arena);
            // release jMap directly after use
            jMap.release();
            if (nativeUser == null) return;

            native.Sentry.setUser(nativeUser);
          }
        });
      });

  @override
  void setContexts(String key, value) => tryCatchSync('setContexts', () {
        native.Sentry.configureScope(
          native.ScopeCallback.implement(
            native.$ScopeCallback(
              run: (iScope) {
                using((arena) {
                  final jKey = key.toJString()..releasedBy(arena);
                  final jVal = dartToJObject(value)..releasedBy(arena);

                  final scope = iScope.as(const native.$Scope$Type())
                    ..releasedBy(arena);
                  scope.setContexts(jKey, jVal);
                });
              },
            ),
          ),
        );
      });

  @override
  void removeContexts(String key) => tryCatchSync('removeContexts', () {
        native.Sentry.configureScope(
            native.ScopeCallback.implement(native.$ScopeCallback(run: (iScope) {
          using((arena) {
            final jKey = key.toJString()..releasedBy(arena);
            final scope = iScope.as(const native.$Scope$Type())
              ..releasedBy(arena);
            scope.removeContexts(jKey);
          });
        })));
      });

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

        final nativeReplayId = _nativeReplay?.getReplayId();
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
          options.log(
              SentryLevel.error,
              'Replay config is not valid: '
              'width: ${config.width}, '
              'height: ${config.height}, '
              'windowWidth: ${config.windowWidth}, '
              'windowHeight: ${config.windowHeight}');
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
}

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
JList<JObject> dartToJList(List<dynamic> values) {
  final jList = JList.array(JObject.type);
  for (final v in values.nonNulls) {
    final j = dartToJObject(v);
    jList.add(j);
    j.release();
  }
  return jList;
}

@visibleForTesting
JMap<JString, JObject> dartToJMap(Map<String, dynamic> json) {
  final jMap = JMap.hash(JString.type, JObject.type);
  for (final entry in json.entries.where((e) => e.value != null)) {
    final jk = entry.key.toJString();
    final jv = dartToJObject(entry.value);
    jMap[jk] = jv;
    jk.release();
    jv.release();
  }
  return jMap;
}

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
