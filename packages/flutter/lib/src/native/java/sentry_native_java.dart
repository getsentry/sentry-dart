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
  Future<void> close() async {
    await _replayRecorder?.stop();
    return super.close();
  }
}
