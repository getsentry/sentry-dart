import 'dart:async';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../sentry_native_channel.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as native;

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
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

    return super.init(hub);
  }

  @override
  FutureOr<void> captureEnvelope(
      Uint8List envelopeData, bool containsUnhandledException) {
    JObject? id;
    JByteArray? byteArray;
    try {
      byteArray = JByteArray.from(envelopeData);
      id = native.InternalSentrySdk.captureEnvelope(
          byteArray, containsUnhandledException);

      if (id == null) {
        options.log(SentryLevel.error,
            'Native Android SDK returned null id when capturing envelope');
      }
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to capture envelope',
          exception: exception, stackTrace: stackTrace);

      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      byteArray?.release();
      id?.release();
    }
  }

  @override
  FutureOr<List<DebugImage>?> loadDebugImages(SentryStackTrace stackTrace) {
    native.SentryAndroidOptions? androidOptions;
    JSet<JString?>? jniAddressSet;
    JSet<native.DebugImage?>? androidDebugImagesJniSet;
    List<JString>? jniAddressStrings;
    List<DebugImage>? dartDebugImages;

    try {
      jniAddressStrings = stackTrace.frames
          .map((f) => f.instructionAddr)
          .whereType<String>()
          .toSet()
          .map((s) => s.toJString())
          .toList(growable: false);
      jniAddressSet =
          jniAddressStrings.cast<JString?>().toJSet(JString.nullableType);

      androidOptions = native.ScopesAdapter.getInstance()
          ?.getOptions()
          .as(native.SentryAndroidOptions.type);

      androidDebugImagesJniSet = (jniAddressStrings.isEmpty)
          ? androidOptions?.getDebugImagesLoader().loadDebugImages()?.toSet()
          : androidOptions
              ?.getDebugImagesLoader()
              .loadDebugImagesForAddresses(jniAddressSet);

      if (androidDebugImagesJniSet != null) {
        dartDebugImages = androidDebugImagesJniSet
            .where((img) => img != null)
            .map((img) {
              final androidImage = img!;
              final type =
                  androidImage.getType()?.toDartString(releaseOriginal: true);
              if (type == null) {
                return null;
              }
              return DebugImage(
                type: type,
                imageAddr: androidImage
                    .getImageAddr()
                    ?.toDartString(releaseOriginal: true),
                imageSize: androidImage
                    .getImageSize()
                    ?.longValue(releaseOriginal: true),
                codeFile: androidImage
                    .getCodeFile()
                    ?.toDartString(releaseOriginal: true),
                debugId: androidImage
                    .getDebugId()
                    ?.toDartString(releaseOriginal: true),
                codeId: androidImage
                    .getCodeId()
                    ?.toDartString(releaseOriginal: true),
                debugFile: androidImage
                    .getDebugFile()
                    ?.toDartString(releaseOriginal: true),
              );
            })
            .whereType<DebugImage>()
            .toList(growable: false);
      }
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to load debug images',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      // Release JNI refs
      for (final js in jniAddressStrings ?? const <JString>[]) {
        js.release();
      }
      jniAddressSet?.release();
      androidDebugImagesJniSet?.release();
      androidOptions?.release();
    }

    return dartDebugImages;
  }

  @override
  Future<Map<String, dynamic>?> loadContexts() {
    native.SentryAndroidOptions? androidOptions;
    native.ScopesAdapter? nativeScope;
    JObject? currentScope;
    JObject? applicationContext;
    JMap<JString?, JObject?>? jniContexts;

    try {
      nativeScope = native.ScopesAdapter.getInstance();
      androidOptions =
          nativeScope?.getOptions().as(native.SentryAndroidOptions.type);
      currentScope = native.InternalSentrySdk.getCurrentScope();
      applicationContext =
          native.SentryFlutterPlugin.Companion.getApplicationContext();

      if (currentScope != null &&
          applicationContext != null &&
          androidOptions != null) {
        jniContexts = native.InternalSentrySdk.serializeScope(
            applicationContext, androidOptions, currentScope);
        final result = _jniMapToDart(jniContexts);
        jniContexts.release();
        return Future.value(result);
      }
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to load contexts via JNI',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      applicationContext?.release();
      currentScope?.release();
      androidOptions?.release();
      nativeScope?.release();
      jniContexts?.release();
    }

    return Future.value(null);
  }

  Map<String, dynamic> _jniMapToDart(JMap<JString?, JObject?> jmap) {
    final dartMap = <String, dynamic>{};
    final keys = jmap.keys;
    try {
      for (final jKey in keys) {
        final jValue = jmap[jKey];
        final dartValue = _javaToDart(jValue);
        final keyString = jKey?.toDartString(releaseOriginal: true);
        if (keyString != null) {
          dartMap[keyString] = dartValue;
        } else {
          // Release key if not converted above.
          jKey?.release();
        }
      }
    } finally {
      keys.release();
    }
    return dartMap;
  }

  dynamic _javaToDart(JObject? value) {
    if (value == null) {
      return null;
    }

    // String
    if (value.isA(JString.type)) {
      final s = value.as(JString.type, releaseOriginal: true);
      return s.toDartString();
    }

    // Boolean
    if (value.isA(JBoolean.type)) {
      final b = value.as(JBoolean.type, releaseOriginal: true);
      return b.booleanValue(releaseOriginal: true);
    }

    // Number (integral or floating)
    if (value.isA(JNumber.type)) {
      final isFloating = value.isA(JDouble.type) || value.isA(JFloat.type);
      final n = value.as(JNumber.type, releaseOriginal: true);
      if (isFloating) {
        return n.doubleValue(releaseOriginal: true);
      }
      return n.longValue(releaseOriginal: true);
    }

    // Map<String, Object>
    if (value.isA(JMap.type(JObject.nullableType, JObject.nullableType))) {
      final m = value.as(
        JMap.type<JString?, JObject?>(
          JString.nullableType,
          JObject.nullableType,
        ),
        releaseOriginal: true,
      );
      return m.use((map) => _jniMapToDart(map));
    }

    // List<Object>
    if (value.isA(JList.type(JObject.nullableType))) {
      final l = value.as(
        JList.type<JObject?>(JObject.nullableType),
        releaseOriginal: true,
      );
      return l.use((list) {
        final result = <dynamic>[];
        for (var i = 0; i < list.length; i++) {
          final elem = list[i];
          result.add(_javaToDart(elem));
        }
        return result;
      });
    }

    // Set<Object> → List
    if (value.isA(JSet.type(JObject.nullableType))) {
      final s = value.as(
        JSet.type<JObject?>(JObject.nullableType),
        releaseOriginal: true,
      );
      return s.use((set) {
        final result = <dynamic>[];
        for (final e in set) {
          result.add(_javaToDart(e));
        }
        return result;
      });
    }

    // Fallback: stringify and release
    try {
      final str = value.toString();
      return str;
    } finally {
      value.release();
    }
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    return super.close();
  }
}
