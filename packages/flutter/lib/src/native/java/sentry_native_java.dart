import 'dart:async';
import 'dart:convert';
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
    JSet<JString>? jniAddressSet;
    List<JString>? jniAddressStrings;
    JByteArray? imagesBytes;

    try {
      jniAddressStrings = stackTrace.frames
          .map((f) => f.instructionAddr)
          .whereType<String>()
          .toSet()
          .map((s) => s.toJString())
          .toList(growable: false);
      jniAddressSet =
          jniAddressStrings.nonNulls.cast<JString>().toJSet(JString.type);

      imagesBytes = native.SentryFlutterPlugin.Companion
          .loadDebugImagesAsBytes(jniAddressSet);
      if (imagesBytes != null) {
        // Copy from JVM -> native buffer as Int8List
        final i8 = imagesBytes.getRange(0, imagesBytes.length);

        // Zero-copy view as Uint8List
        final u8 = Uint8List.view(i8.buffer, i8.offsetInBytes, i8.length);

        final jsonStr = utf8.decode(u8);
        final debugImagesMap = (jsonDecode(jsonStr) as List)
            .map((x) => (x is Map) ? x as Map<String, dynamic> : null)
            .nonNulls;
        return debugImagesMap.map(DebugImage.fromJson).toList(growable: false);
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
      imagesBytes?.release();
    }

    return null;
  }

  @override
  FutureOr<Map<String, dynamic>?> loadContexts() async {
    final channelStopwatch = Stopwatch()..start();
    await super.loadContexts();
    channelStopwatch.stop();

    JByteArray? jba;

    final ffiStopwatch = Stopwatch()..start();
    try {
      // Use a single JNI call to get contexts as UTF-8 encoded JSON instead of
      // making multiple JNI calls to convert each object individually. This approach
      // is significantly faster because contexts can be large and contain many nested
      // objects. Local benchmarks show this method is ~4x faster than the alternative
      // approach of converting JNI objects to Dart objects one by one.
      jba = native.SentryFlutterPlugin.Companion.loadContextsAsBytes();
      if (jba == null) return null;

      // Copy from JVM -> native buffer as Int8List
      final i8 = jba.getRange(0, jba.length);

      // Zero-copy view as Uint8List
      final u8 = Uint8List.view(i8.buffer, i8.offsetInBytes, i8.length);

      final jsonStr = utf8.decode(u8);
      ffiStopwatch.stop();
      print(
          'JNI loadContexts took ${ffiStopwatch.elapsedMicroseconds} microseconds');
      print(
          'Channel loadContexts took ${channelStopwatch.elapsedMicroseconds} microseconds');
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (exception, stackTrace) {
      options.log(SentryLevel.error, 'Failed to load contexts via JNI',
          exception: exception, stackTrace: stackTrace);
      if (options.automatedTestMode) {
        rethrow;
      }
    } finally {
      jba?.release();
    }

    return null;
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    return super.close();
  }
}
