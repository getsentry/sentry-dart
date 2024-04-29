import 'dart:io';
import 'dart:ui';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../../replay/recorder.dart';
import '../../replay/recorder_config.dart';
import '../../sentry_flutter_options.dart';
import 'binding.dart' as java;

@internal
class AndroidReplayRecorder implements java.$RecorderImpl {
  final SentryFlutterOptions _options;
  late ScreenshotRecorder _recorder;
  late java.ReplayIntegration? _integration;

  AndroidReplayRecorder._(this._options);

  static java.Recorder create(SentryFlutterOptions options) =>
      java.Recorder.implement(AndroidReplayRecorder._(options));

  @override
  void pause() => _recorder.stop();

  @override
  void resume() => _recorder.start();

  @override
  void start(java.ScreenshotRecorderConfig config) {
    _integration = java.SentryFlutterReplay.integration;

    var jniCacheDir = _integration!.getReplayCacheDir();
    var cacheDir =
        jniCacheDir.getAbsolutePath().toDartString(releaseOriginal: true);
    jniCacheDir.release();

    // Note: time measurements using a Stopwatch in a debug build:
    //     save as rawRgba (1230876 bytes): 0.257 ms  -- discarded
    //     save as PNG (25401 bytes): 43.110 ms  -- used for the final image
    //     image size: 25401 bytes
    //     save to file: 3.677 ms
    //     new jfile: 0.400 ms
    //     onScreenshotRecorded1: 1.237 ms
    //     released and exiting callback: 0.021 ms
    ScreenshotRecorderCallback callback = (image) async {
      var imageData = await image.toByteData(format: ImageByteFormat.png);
      if (imageData != null) {
        var timestamp = DateTime.now().millisecondsSinceEpoch;
        var filePath = path.join(cacheDir, "$timestamp.png");
        await File(filePath).writeAsBytes(imageData.buffer.asUint8List());

        var jFilePath = filePath.toJString();
        var jFile = java.File(jFilePath);
        try {
          _integration?.onScreenshotRecorded1(jFile, timestamp);
        } finally {
          jFile.release();
          jFilePath.release();
        }
      }
    };

    _recorder = ScreenshotRecorder(
      ScreenshotRecorderConfig(
        config.getRecordingWidth(),
        config.getRecordingHeight(),
        config.getFrameRate(),
      ),
      callback,
      _options.logger,
      _options.replay,
    );

    _recorder.start();
  }

  @override
  void stop() {
    _recorder.stop();
    var integration = _integration;
    _integration = null;
    integration?.release();
  }
}
