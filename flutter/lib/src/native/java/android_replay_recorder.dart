import 'dart:io';
import 'dart:ui';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import '../../replay/recorder.dart';
import '../../replay/recorder_config.dart';
import 'binding.dart' as java;

@internal
class AndroidReplayRecorder implements java.$RecorderImpl {
  late ScreenshotRecorder _recorder;
  late java.ScreenshotRecorderCallback? _callback;

  AndroidReplayRecorder._();

  static java.Recorder create() =>
      java.Recorder.implement(AndroidReplayRecorder._());

  @override
  void pause() => _recorder.stop();

  @override
  void resume() => _recorder.start();

  @override
  void start(java.ScreenshotRecorderConfig config) {
    var cacheDir =
        java.SentryFlutterReplay.cacheDir.toDartString(releaseOriginal: true);
    _callback = java.SentryFlutterReplay.callback;
    _recorder = ScreenshotRecorder(
        ScreenshotRecorderConfig(
          config.getRecordingWidth(),
          config.getRecordingHeight(),
          config.getFrameRate(),
          config.getBitRate(),
        ), (image) async {
      var imageData = await image.toByteData(format: ImageByteFormat.png);
      if (imageData != null) {
        var timestamp = DateTime.now().millisecondsSinceEpoch;
        var filePath = path.join(cacheDir, "$timestamp.png");
        await File(filePath).writeAsBytes(imageData.buffer.asUint8List());

        var jFilePath = filePath.toJString();
        var jFile = java.File(jFilePath);
        try {
          _callback?.onScreenshotRecorded1(jFile, timestamp);
        } finally {
          jFile.release();
          jFilePath.release();
        }
      }
    });
    _recorder.start();
  }

  @override
  void stop() {
    _recorder.stop();
    var callback = _callback;
    _callback = null;
    callback?.release();
  }
}
