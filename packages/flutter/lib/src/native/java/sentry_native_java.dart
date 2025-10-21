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

const _videoBlockSize = 16;

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidEnvelopeSender? _envelopeSender;
  native.ReplayIntegration? _nativeReplay;

  SentryNativeJava(super.options);

  @override
  bool get supportsReplay => true;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'ReplayRecorder.start':
            final replayId =
                SentryId.fromId(call.arguments['replayId'] as String);
            _nativeReplay = native.SentryFlutterPlugin.Companion
                .privateSentryGetReplayIntegration();
            _replayRecorder = AndroidReplayRecorder.factory(options);
            await _replayRecorder!.start();
            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = replayId;
            });
            break;
          case 'ReplayRecorder.onConfigurationChanged':
            final config = ScheduledScreenshotRecorderConfig(
                width: (call.arguments['width'] as num).toDouble(),
                height: (call.arguments['height'] as num).toDouble(),
                frameRate: call.arguments['frameRate'] as int);

            await _replayRecorder?.onConfigurationChanged(config);
            break;
          case 'ReplayRecorder.stop':
            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = null;
            });

            final future = _replayRecorder?.stop();
            _replayRecorder = null;
            await future;

            break;
          case 'ReplayRecorder.pause':
            await _replayRecorder?.pause();
            break;
          case 'ReplayRecorder.resume':
            await _replayRecorder?.resume();
            break;
          case 'ReplayRecorder.reset':
            // ignored
            break;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    _envelopeSender = AndroidEnvelopeSender.factory(options);
    await _envelopeSender?.start();

    return super.init(hub);
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
            ?.intValue();
      });

  @override
  NativeAppStart? fetchNativeAppStart() {
    JByteArray? appStartUtf8JsonBytes;

    return tryCatchSync('fetchNativeAppStart', () {
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
    return super.close();
  }

  @override
  void addBreadcrumb(Breadcrumb breadcrumb) {
    native.Breadcrumb? nativeBreadcrumb;
    JObject? nativeOptions;

    tryCatchSync('addBreadcrumb', () {
      nativeOptions = native.ScopesAdapter.getInstance()?.getOptions();
      if (nativeOptions == null) return;

      nativeBreadcrumb = native.Breadcrumb.fromMap(
          _dartToJMap(breadcrumb.toJson()), nativeOptions!);
      if (nativeBreadcrumb == null) return;

      native.Sentry.addBreadcrumb$1(nativeBreadcrumb!);
    }, finallyFn: () {
      nativeOptions?.release();
      nativeBreadcrumb?.release();
    });
  }

  @override
  void clearBreadcrumbs() => tryCatchSync('clearBreadcrumbs', () {
        native.Sentry.clearBreadcrumbs();
      });

  @override
  void setUser(SentryUser? user) {
    native.User? nativeUser;
    JObject? nativeOptions;

    tryCatchSync('setUser', () {
      if (user == null) {
        native.Sentry.setUser(null);
      } else {
        nativeOptions = native.ScopesAdapter.getInstance()?.getOptions();
        if (nativeOptions == null) return;

        nativeUser =
            native.User.fromMap(_dartToJMap(user.toJson()), nativeOptions!);
        if (nativeUser == null) return;

        native.Sentry.setUser(nativeUser);
      }
    }, finallyFn: () {
      nativeUser?.release();
      nativeOptions?.release();
    });
  }

  @override
  void setContexts(String key, value) {
    JString jKey = key.toJString();
    JObject? jVal = _dartToJObject(value);

    if (jVal == null) return;

    tryCatchSync('setContexts', () {
      native.Sentry.configureScope(
        native.ScopeCallback.implement(
          native.$ScopeCallback(
            run: (iScope) {
              final scope = iScope.as(const native.$Scope$Type());
              scope.setContexts(jKey, jVal);
            },
          ),
        ),
      );
    }, finallyFn: () {
      jKey.release();
      jVal.release();
    });
  }

  @override
  void removeContexts(String key) {
    JString jKey = key.toJString();

    tryCatchSync('removeContexts', () {
      native.Sentry.configureScope(
          native.ScopeCallback.implement(native.$ScopeCallback(run: (iScope) {
        final scope = iScope.as(const native.$Scope$Type());
        scope.removeContexts(jKey);
      })));
    }, finallyFn: () {
      jKey.release();
    });
  }

  @override
  void setExtra(String key, dynamic value) {
    JString jKey = key.toJString();
    JString jVal = normalize(value).toString().toJString();

    tryCatchSync('setExtra', () {
      native.Sentry.configureScope(
        native.ScopeCallback.implement(
          native.$ScopeCallback(
            run: (iScope) {
              final scope = iScope.as(const native.$Scope$Type());
              scope.setExtra(jKey, jVal);
            },
          ),
        ),
      );
    }, finallyFn: () {
      jKey.release();
      jVal.release();
    });
  }

  @override
  FutureOr<void> removeExtra(String key) {
    JString jKey = key.toJString();

    tryCatchSync('removeExtra', () {
      native.Sentry.configureScope(
          native.ScopeCallback.implement(native.$ScopeCallback(run: (iScope) {
        final scope = iScope.as(const native.$Scope$Type());
        scope.removeExtra(jKey);
      })));
    }, finallyFn: () {
      jKey.release();
    });
  }

  @override
  void setTag(String key, String value) {
    JString jKey = key.toJString();
    JString jVal = value.toJString();

    tryCatchSync('setTag', () {
      native.Sentry.configureScope(
        native.ScopeCallback.implement(
          native.$ScopeCallback(
            run: (iScope) {
              final scope = iScope.as(const native.$Scope$Type());
              scope.setTag(jKey, jVal);
            },
          ),
        ),
      );
    }, finallyFn: () {
      jKey.release();
      jVal.release();
    });
  }

  @override
  void removeTag(String key) {
    JString jKey = key.toJString();

    tryCatchSync('removeTag', () {
      native.Sentry.configureScope(
          native.ScopeCallback.implement(native.$ScopeCallback(run: (iScope) {
        final scope = iScope.as(const native.$Scope$Type());
        scope.removeTag(jKey);
      })));
    }, finallyFn: () {
      jKey.release();
    });
  }

  @override
  SentryId captureReplay() {
    JString? jString;

    final id = tryCatchSync('captureReplay', () {
      // The passed parameter is `isTerminating`
      _nativeReplay?.captureReplay(false.toJBoolean());
      jString = _nativeReplay?.getReplayId().toString$1();

      if (jString == null) {
        return SentryId.empty();
      } else {
        return SentryId.fromId(jString!.toDartString());
      }
    }, finallyFn: () {
      jString?.release();
    });

    if (id == null) {
      return SentryId.empty();
    }
    return id;
  }

  @override
  void setReplayConfig(ReplayConfig config) =>
      tryCatchSync('setReplayConfig', () {
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
          adjWidth.toInt(),
          adjHeight.toInt(),
          adjWidth / config.windowWidth,
          adjHeight / config.windowHeight,
          config.frameRate,
          0, // bitRate is currently not used
        );

        _nativeReplay?.onConfigurationChanged(replayConfig);
      });
}

JObject? _dartToJObject(Object? value) => switch (value) {
      null => null,
      String s => s.toJString(),
      bool b => b.toJBoolean(),
      int i => i.toJLong(), // safer for 64-bit
      double d => d.toJDouble(),
      List<dynamic> l => _dartToJList(l),
      Map<String, dynamic> m => _dartToJMap(m),
      _ => null
    };

JList<JObject?> _dartToJList(List<dynamic> values) {
  final jlist = JList.array(JObject.nullableType);
  jlist.addAll(values.map(_dartToJObject));
  return jlist;
}

JMap<JString, JObject?> _dartToJMap(Map<String, dynamic> json) {
  final jmap = JMap.hash(JString.type, JObject.nullableType);
  for (final entry in json.entries) {
    jmap[entry.key.toJString()] = _dartToJObject(entry.value);
  }
  return jmap;
}

extension _ReplaySizeAdjustment on double {
  double adjustReplaySizeToBlockSize() {
    final remainder = this % _videoBlockSize;
    if (remainder <= _videoBlockSize / 2) {
      return this - remainder;
    } else {
      return this + (_videoBlockSize - remainder);
    }
  }
}
