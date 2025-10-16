import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder_config.dart';
import '../sentry_native_channel.dart';
import '../utils/utf8_json.dart';
import 'android_envelope_sender.dart';
import 'android_replay_recorder.dart';
import 'binding.dart' as native;
import 'converter.dart';

@internal
class SentryNativeJava extends SentryNativeChannel {
  AndroidReplayRecorder? _replayRecorder;
  AndroidEnvelopeSender? _envelopeSender;

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
  List<DebugImage>? loadDebugImages(SentryStackTrace stackTrace) {
    JSet<JString>? instructionAddressSet;
    JList<JMap<JString, JObject?>>? debugImages;

    return tryCatchSync('loadDebugImages', () {
      instructionAddressSet = stackTrace.frames
          .map((f) => f.instructionAddr)
          .nonNulls
          .map((s) => s.toJString())
          .toJSet(JString.type);

      debugImages = native.SentryFlutterPlugin.Companion
          .loadDebugImages(instructionAddressSet!); // safe to unwrap
      if (debugImages == null) return null;

      return debugImages
          ?.map((e) =>
              DebugImage.fromJson(Map<String, dynamic>.from(e.toDartMap())))
          .toList(growable: false);
    }, finallyFn: () {
      instructionAddressSet?.release();
      debugImages?.release();
    });
  }

  @override
  Map<String, dynamic>? loadContexts() {
    JMap<JString?, JObject?>? contexts;

    return tryCatchSync('loadContexts', () {
      final stopwatch = Stopwatch()..start();
      contexts = native.SentryFlutterPlugin.Companion.loadContexts();
      if (contexts == null) return null;
      final map = Map<String, dynamic>.from(contexts!.toDartMap());
      stopwatch.stop();

      final stopwatch2 = Stopwatch()..start();
      final hello = native.SentryFlutterPlugin.Companion.loadContextsBytes();
      if (hello == null) return null;
      final byteRange = hello.getRange(0, hello.length);
      final bytes = Uint8List.view(
          byteRange.buffer, byteRange.offsetInBytes, byteRange.length);
      final decoded = decodeUtf8JsonMap(bytes);
      stopwatch2.stop();

      final stopwatch3 = Stopwatch()..start();
      final ctx = native.SentryFlutterPlugin.Companion.loadContextsStr();
      final str = json.decode(ctx!.toDartString()) as Map<String, dynamic>;
      stopwatch3.stop();

      print(
          'loadContexts and mapping took (1) ${stopwatch.elapsedMilliseconds}ms and (2) ${stopwatch2.elapsedMilliseconds}ms');
      print(
          'loadContexts and mapping took (3) ${stopwatch3.elapsedMilliseconds}ms');

      return null;

      print('loadCONtexts and mapping took ${stopwatch.elapsedMilliseconds}ms');
      return map;
    }, finallyFn: () {
      contexts?.release();
    });
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    await _envelopeSender?.close();
    return super.close();
  }
}
