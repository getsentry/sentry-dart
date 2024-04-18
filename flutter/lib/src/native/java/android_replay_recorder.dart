import 'dart:io';
import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../../replay/recorder.dart';
import '../../replay/recorder_config.dart';
import 'binding.dart' as java;

@internal
class AndroidReplayRecorder implements java.$RecorderImpl {
  late ScreenshotRecorder _recorder;

  AndroidReplayRecorder._();

  static java.Recorder create() =>
      java.Recorder.implement(AndroidReplayRecorder._());

  @override
  void pause() => _recorder.stop();

  @override
  void resume() => _recorder.start();

  @override
  void start(java.ScreenshotRecorderConfig config) {
    var cacheDir = java.SentryFlutterReplay.cacheDir;
    _recorder = ScreenshotRecorder(
        ScreenshotRecorderConfig(
          config.getRecordingWidth(),
          config.getRecordingHeight(),
          config.getFrameRate(),
          config.getBitRate(),
        ), (image) async {
      var imageData = await image.toByteData(format: ImageByteFormat.png);
      if (imageData != null) {
        var filePath =
            path.join(cacheDir, "${DateTime.now().millisecondsSinceEpoch}.png");
        await File(filePath).writeAsBytes(imageData.buffer.asUint8List());
      }
    });
    _recorder.start();
  }

  @override
  void stop() => _recorder.stop();
}
