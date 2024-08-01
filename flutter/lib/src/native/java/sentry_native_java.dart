import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../event_processor/replay_event_processor.dart';
import '../../replay/scheduled_recorder.dart';
import '../../replay/recorder_config.dart';
import '../sentry_native_channel.dart';

// Note: currently this doesn't do anything. Later, it shall be used with
// generated JNI bindings. See https://github.com/getsentry/sentry-dart/issues/1444
@internal
class SentryNativeJava extends SentryNativeChannel {
  ScheduledScreenshotRecorder? _replayRecorder;
  SentryNativeJava(super.options, super.channel);

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.experimental.replay.isEnabled) {
      // We only need the integration when error-replay capture is enabled.
      if ((options.experimental.replay.errorSampleRate ?? 0) > 0) {
        options.addEventProcessor(ReplayEventProcessor(this));
      }

      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'ReplayRecorder.start':
            final replayId =
                SentryId.fromId(call.arguments['replayId'] as String);

            _startRecorder(
              call.arguments['directory'] as String,
              ScheduledScreenshotRecorderConfig(
                width: call.arguments['width'] as int,
                height: call.arguments['height'] as int,
                frameRate: call.arguments['frameRate'] as int,
              ),
            );

            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = replayId;
            });

            break;
          case 'ReplayRecorder.stop':
            await _replayRecorder?.stop();
            _replayRecorder = null;

            hub.configureScope((s) {
              // ignore: invalid_use_of_internal_member
              s.replayId = null;
            });

            break;
          case 'ReplayRecorder.pause':
            await _replayRecorder?.stop();
            break;
          case 'ReplayRecorder.resume':
            _replayRecorder?.start();
            break;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  @override
  Future<void> close() async {
    await _replayRecorder?.stop();
    _replayRecorder = null;
    return super.close();
  }

  void _startRecorder(
      String cacheDir, ScheduledScreenshotRecorderConfig config) {
    // Note: time measurements using a Stopwatch in a debug build:
    //     save as rawRgba (1230876 bytes): 0.257 ms  -- discarded
    //     save as PNG (25401 bytes): 43.110 ms  -- used for the final image
    //     image size: 25401 bytes
    //     save to file: 3.677 ms
    //     onScreenshotRecorded1: 1.237 ms
    //     released and exiting callback: 0.021 ms
    ScreenshotRecorderCallback callback = (image) async {
      var imageData = await image.toByteData(format: ImageByteFormat.png);
      if (imageData != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = "$cacheDir/$timestamp.png";

        options.logger(
            SentryLevel.debug,
            'Replay: Saving screenshot to $filePath ('
            '${image.width}x${image.height} pixels, '
            '${imageData.lengthInBytes} bytes)');
        try {
          await options.fileSystem
              .file(filePath)
              .writeAsBytes(imageData.buffer.asUint8List(), flush: true);

          await channel.invokeMethod(
            'addReplayScreenshot',
            {'path': filePath, 'timestamp': timestamp},
          );
        } catch (error, stackTrace) {
          options.logger(
            SentryLevel.error,
            'Native call `addReplayScreenshot` failed',
            exception: error,
            stackTrace: stackTrace,
          );
          // ignore: invalid_use_of_internal_member
          if (options.automatedTestMode) {
            rethrow;
          }
        }
      }
    };

    _replayRecorder = ScheduledScreenshotRecorder(config, callback, options)
      ..start();
  }
}
