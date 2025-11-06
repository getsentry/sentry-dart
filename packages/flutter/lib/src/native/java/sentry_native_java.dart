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

const flutterSdkName = 'sentry.dart.flutter';
const androidSdkName = 'sentry.java.android.flutter';
const nativeSdkName = 'sentry.native.android.flutter';

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidEnvelopeSender? _envelopeSender;
  native.ReplayIntegration? _nativeReplay;

  SentryNativeJava(super.options);

  @override
  bool get supportsReplay => true;

  @override
  SentryId? get replayId => _replayId;
  SentryId? _replayId;

  @visibleForTesting
  AndroidReplayRecorder? get testRecorder => _replayRecorder;

  @override
  Future<void> init(Hub hub) async {
    final replayCallbacks = options.replay.isEnabled
        ? native.ReplayRecorderCallbacks.implement(
            native.$ReplayRecorderCallbacks(
              replayStarted:
                  (JString replayIdString, bool replayIsBuffering) async {
                final replayId = SentryId.fromId(replayIdString.toDartString());

                _replayId = replayId;
                _nativeReplay = native.SentryFlutterPlugin.Companion
                    .privateSentryGetReplayIntegration();
                _replayRecorder = AndroidReplayRecorder.factory(options);
                await _replayRecorder!.start();
                hub.configureScope((s) {
                  // Only set replay ID on scope if not buffering (active session mode)
                  // ignore: invalid_use_of_internal_member
                  s.replayId = !replayIsBuffering ? replayId : null;
                });
              },
              replayResumed: () async {
                await _replayRecorder?.resume();
              },
              replayPaused: () async {
                await _replayRecorder?.pause();
              },
              replayStopped: () async {
                hub.configureScope((s) {
                  // ignore: invalid_use_of_internal_member
                  s.replayId = null;
                });

                final future = _replayRecorder?.stop();
                _replayRecorder = null;
                await future;
              },
              replayReset: () {
                // ignored
              },
              replayConfigChanged:
                  (int width, int height, int frameRate) async {
                final config = ScheduledScreenshotRecorderConfig(
                    width: width.toDouble(),
                    height: height.toDouble(),
                    frameRate: frameRate);

                await _replayRecorder?.onConfigurationChanged(config);
              },
            ),
          )
        : null;

    final beforeSendReplayCallback =
        native.SentryOptions$BeforeSendReplayCallback.implement(
      native.$SentryOptions$BeforeSendReplayCallback(
        execute: (sentryReplayEvent, hint) {
          final data = hint.getReplayRecording()?.getPayload()?.firstOrNull;
          if (data is native.$RRWebOptionsEvent$Type) {
            final payload =
                data?.as(native.RRWebOptionsEvent.type).getOptionsPayload();
            payload?.removeWhere((key, value) =>
                key?.toDartString(releaseOriginal: true).contains('mask') ??
                false);

            using((arena) {
              payload?.addAll({
                'maskAllText'.toJString():
                    options.privacy.maskAllText.toJBoolean(),
                'maskAllImages'.toJString():
                    options.privacy.maskAllImages.toJBoolean(),
                'maskAssetImages'.toJString():
                    options.privacy.maskAssetImages.toJBoolean(),
                if (options.privacy.userMaskingRules.isNotEmpty)
                  'maskingRules'.toJString(): _dartToJList(
                      options.privacy.userMaskingRules
                          .map((rule) => '${rule.name}: ${rule.description}')
                          .toList(growable: false),
                      arena)
              });
            });
          }
          return sentryReplayEvent;
        },
      ),
    );
    final beforeSendEventCallback =
        native.SentryOptions$BeforeSendCallback.implement(native
            .$SentryOptions$BeforeSendCallback(execute: (sentryEvent, hint) {
      final sdk = sentryEvent.getSdk();
      if (sdk != null) {
        switch (sdk.getName().toDartString()) {
          case flutterSdkName:
            sentryEvent.setTag(
                'event.origin'.toJString(), 'flutter'.toJString());
            sentryEvent.setTag(
                'event.environment'.toJString(), 'dart'.toJString());
            break;
          case androidSdkName:
            sentryEvent.setTag(
                'event.origin'.toJString(), 'android'.toJString());
            sentryEvent.setTag(
                'event.environment'.toJString(), 'java'.toJString());
            break;
          case nativeSdkName:
            sentryEvent.setTag(
                'event.origin'.toJString(), 'android'.toJString());
            sentryEvent.setTag(
                'event.environment'.toJString(), 'native'.toJString());
            break;
          default:
            // TODO: log unrecognized value
            break;
        }
      }
      return sentryEvent;
    }));
    final context = native.SentryFlutterPlugin.getApplicationContext()!;
    native.SentryAndroid.init$2(
        context,
        native.Sentry$OptionsConfiguration.implement(
          native.$Sentry$OptionsConfiguration(
            T: native.SentryAndroidOptions.nullableType,
            configure: (native.SentryAndroidOptions? androidOptions) {
              if (androidOptions == null) return;

              androidOptions.setDsn(options.dsn?.toJString());
              androidOptions.setDebug(options.debug);
              androidOptions.setEnvironment(options.environment?.toJString());
              androidOptions.setRelease(options.release?.toJString());
              androidOptions.setDist(options.dist?.toJString());
              androidOptions.setEnableAutoSessionTracking(
                  options.enableAutoSessionTracking);
              androidOptions.setSessionTrackingIntervalMillis(
                  options.autoSessionTrackingInterval.inMilliseconds);
              androidOptions.setAnrTimeoutIntervalMillis(
                  options.anrTimeoutInterval.inMilliseconds);
              androidOptions.setAnrEnabled(options.anrEnabled);
              androidOptions.setAttachThreads(options.attachThreads);
              androidOptions.setAttachStacktrace(options.attachStacktrace);
              final enableNativeBreadcrumbs =
                  options.enableAutoNativeBreadcrumbs;
              androidOptions.setEnableActivityLifecycleBreadcrumbs(
                  enableNativeBreadcrumbs);
              androidOptions
                  .setEnableAppLifecycleBreadcrumbs(enableNativeBreadcrumbs);
              androidOptions
                  .setEnableSystemEventBreadcrumbs(enableNativeBreadcrumbs);
              androidOptions
                  .setEnableAppComponentBreadcrumbs(enableNativeBreadcrumbs);
              androidOptions
                  .setEnableUserInteractionBreadcrumbs(enableNativeBreadcrumbs);
              androidOptions.setMaxBreadcrumbs(options.maxBreadcrumbs);
              androidOptions.setMaxCacheItems(options.maxCacheItems);
              if (options.debug) {
                final androidLevel = native.SentryLevel.valueOf(
                    options.diagnosticLevel.name.toUpperCase().toJString());
                androidOptions.setDiagnosticLevel(androidLevel);
              }
              androidOptions.setSendDefaultPii(options.sendDefaultPii);
              androidOptions.setEnableScopeSync(options.enableNdkScopeSync);
              androidOptions.setProguardUuid(options.proguardUuid?.toJString());
              androidOptions.setEnableSpotlight(options.spotlight.enabled);
              androidOptions.setSpotlightConnectionUrl(
                  options.spotlight.url?.toJString());
              // nativeCrashHandling has priority over anrEnabled
              if (!options.enableNativeCrashHandling) {
                androidOptions.setEnableUncaughtExceptionHandler(false);
                androidOptions.setAnrEnabled(false);
                // If split-symbols packaging is enabled, native NDK integration is required
                // to upload/native-process the symbol files. In that case we cannot offer
                // the option to disable NDK support here (would break symbol handling).
              }
              androidOptions.setSendClientReports(options.sendClientReports);
              androidOptions.setMaxAttachmentSize(options.maxAttachmentSize);
              androidOptions.setConnectionTimeoutMillis(
                  options.connectionTimeout.inMilliseconds);
              androidOptions
                  .setReadTimeoutMillis(options.readTimeout.inMilliseconds);
              native.SentryFlutterPlugin.Companion.setProxy(
                  androidOptions,
                  options.proxy?.user?.toJString(),
                  options.proxy?.pass?.toJString(),
                  options.proxy?.host?.toJString(),
                  options.proxy?.port?.toString().toJString(),
                  options.proxy?.type
                      .toString()
                      .split('.')
                      .last
                      .toUpperCase()
                      .toJString());

              native.SdkVersion? sdkVersion = androidOptions.getSdkVersion();
              if (sdkVersion == null) {
                // TODO: force unwrap of version name
                sdkVersion = native.SdkVersion(androidSdkName.toJString(),
                    native.BuildConfig.VERSION_NAME!);
              } else {
                sdkVersion.setName(androidSdkName.toJString());
              }
              for (final integration in options.sdk.integrations) {
                sdkVersion.addIntegration(integration.toJString());
              }
              for (final package in options.sdk.packages) {
                sdkVersion.addPackage(
                    package.name.toJString(), package.version.toJString());
              }

              androidOptions.setBeforeSend(beforeSendEventCallback);

              // Replay
              switch (options.replay.quality) {
                case SentryReplayQuality.low:
                  androidOptions.getSessionReplay().setQuality(
                      native.SentryReplayOptions$SentryReplayQuality.LOW);
                  break;
                case SentryReplayQuality.high:
                  androidOptions.getSessionReplay().setQuality(
                      native.SentryReplayOptions$SentryReplayQuality.HIGH);
                  break;
                default:
                  androidOptions.getSessionReplay().setQuality(
                      native.SentryReplayOptions$SentryReplayQuality.MEDIUM);
              }
              androidOptions.getSessionReplay().setSessionSampleRate(
                  options.replay.sessionSampleRate?.toJDouble());
              androidOptions.getSessionReplay().setOnErrorSampleRate(
                  options.replay.onErrorSampleRate?.toJDouble());

              // Disable native tracking of window sizes
              // because we don't have the new size from Flutter yet. Instead, we'll
              // trigger onConfigurationChanged() manually in setReplayConfig().
              androidOptions.getSessionReplay().setTrackConfiguration(false);
              androidOptions.setBeforeSendReplay(beforeSendReplayCallback);
              androidOptions.getSessionReplay().setSdkVersion(sdkVersion);

              native.SentryFlutterPlugin.Companion
                  .setupReplayJni(androidOptions, replayCallbacks);
            },
          ),
        ));

    _envelopeSender = AndroidEnvelopeSender.factory(options);
    await _envelopeSender?.start();
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
      imagesUtf8JsonBytes = native.SentryFlutterPlugin.Companion
          .loadDebugImagesAsBytes(instructionAddressSet);
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
      contextsUtf8JsonBytes =
          native.SentryFlutterPlugin.Companion.loadContextsAsBytes();
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
        return native.SentryFlutterPlugin.Companion
            .getDisplayRefreshRate()
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
          native.SentryFlutterPlugin.Companion.fetchNativeAppStartAsBytes();
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
    native.SentryFlutterPlugin.Companion.crash();
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
          final nativeOptions = native.ScopesAdapter.getInstance()?.getOptions()
            ?..releasedBy(arena);
          if (nativeOptions == null) return;
          final jMap = _dartToJMap(breadcrumb.toJson(), arena);
          final nativeBreadcrumb =
              native.Breadcrumb.fromMap(jMap, nativeOptions)
                ?..releasedBy(arena);
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
            final nativeOptions = native.ScopesAdapter.getInstance()
                ?.getOptions()
              ?..releasedBy(arena);
            if (nativeOptions == null) return;

            final nativeUser = native.User.fromMap(
                _dartToJMap(user.toJson(), arena), nativeOptions)
              ?..releasedBy(arena);
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
                  final jVal = _dartToJObject(value, arena);

                  if (jVal == null) return;

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
        if (value == null) return;

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
        _nativeReplay ??= native.SentryFlutterPlugin.Companion
            .privateSentryGetReplayIntegration();
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

        _nativeReplay ??= native.SentryFlutterPlugin.Companion
            .privateSentryGetReplayIntegration();
        _nativeReplay?.onConfigurationChanged(replayConfig);

        replayConfig.release();
      });
}

JObject? _dartToJObject(Object? value, Arena arena) => switch (value) {
      null => null,
      String s => s.toJString()..releasedBy(arena),
      bool b => b.toJBoolean()..releasedBy(arena),
      int i => i.toJLong()..releasedBy(arena),
      double d => d.toJDouble()..releasedBy(arena),
      List<dynamic> l => _dartToJList(l, arena),
      Map<String, dynamic> m => _dartToJMap(m, arena),
      _ => null
    };

JList<JObject?> _dartToJList(List<dynamic> values, Arena arena) {
  final jlist = JList.array(JObject.nullableType)..releasedBy(arena);

  for (final value in values) {
    final jObj = _dartToJObject(value, arena);
    jlist.add(jObj);
  }

  return jlist;
}

JMap<JString, JObject?> _dartToJMap(Map<String, dynamic> json, Arena arena) {
  final jmap = JMap.hash(JString.type, JObject.nullableType)..releasedBy(arena);

  for (final entry in json.entries) {
    final key = entry.key.toJString()..releasedBy(arena);
    final value = _dartToJObject(entry.value, arena);
    jmap[key] = value;
  }

  return jmap;
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
