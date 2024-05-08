import 'dart:io';
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../../../sentry_flutter.dart';
import '../../replay/recorder.dart';
import '../../replay/recorder_config.dart';
import '../sentry_native_channel.dart';

// Note: currently this doesn't do anything. Later, it shall be used with
// generated JNI bindings. See https://github.com/getsentry/sentry-dart/issues/1444
@internal
class SentryNativeJava extends SentryNativeChannel {
  ScreenshotRecorder? _replayRecorder;
  late final SentryFlutterOptions _options;
  SentryNativeJava(super.channel);

  @override
  Future<void> init(SentryFlutterOptions options) async {
    // We only need these when replay is enabled so let's set it up
    // conditionally. This allows Dart to trim the code.
    if (options.experimental.replay.isEnabled) {
      _options = options;
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'ReplayRecorder.start':
            _startRecorder(
              call.arguments['directory'] as String,
              ScreenshotRecorderConfig(
                width: call.arguments['width'] as int,
                height: call.arguments['height'] as int,
                frameRate: call.arguments['frameRate'] as int,
              ),
            );
            break;
          case 'ReplayRecorder.stop':
            _replayRecorder?.stop();
            _replayRecorder = null;
            break;
          case 'ReplayRecorder.pause':
            _replayRecorder?.stop();
            break;
          case 'ReplayRecorder.resume':
            _replayRecorder?.start();
            break;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(options);
  }

  void _startRecorder(String cacheDir, ScreenshotRecorderConfig config) {
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
        var timestamp = DateTime.now().millisecondsSinceEpoch;
        var filePath = path.join(cacheDir, "$timestamp.png");

        _options.logger(
            SentryLevel.debug,
            'Replay: Saving screenshot to $filePath ('
            '${image.width}x${image.height} pixels, '
            '${imageData.lengthInBytes} bytes)');
        await File(filePath).writeAsBytes(imageData.buffer.asUint8List());

        try {
          await channel.invokeMethod(
            'addReplayScreenshot',
            {'path': filePath, 'timestamp': timestamp},
          );
        } catch (error, stackTrace) {
          _options.logger(
            SentryLevel.error,
            'Native call `addReplayScreenshot` failed',
            exception: error,
            stackTrace: stackTrace,
          );
        }
      }
    };

    _replayRecorder = ScreenshotRecorder(
      config,
      callback,
      _options,
    )..start();
  }
}
