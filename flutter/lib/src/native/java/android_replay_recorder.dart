import 'dart:isolate';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import 'binding.dart' as native;

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  static final _nativeReplay = native.SentryFlutterPlugin$Companion(null)
      .privateSentryGetReplayIntegration()!;

  AndroidReplayRecorder(super.config, super.options) {
    super.callback = _addReplayScreenshot;
  }

  Future<void> _addReplayScreenshot(
      Screenshot screenshot, bool isNewlyCaptured) async {
    // TODO this is currently missing in native onScreenshotRecorded()
    // final timestamp = screenshot.timestamp.millisecondsSinceEpoch;

    try {
      final data = await screenshot.rawRgbaData;
      options.logger(
          SentryLevel.debug,
          '$logName: captured screenshot ('
          '${screenshot.width}x${screenshot.height} pixels, '
          '${data.lengthInBytes} bytes)');

      // TODO evaluate setAll() performance, consider memcpy.
      final jBuffer = JByteBuffer.fromList(data.buffer.asUint8List());
      int width = screenshot.width;
      int height = screenshot.height;

      // TODO possible future improvements:
      // - long-lived isolate
      // - store Bitmap (creation is a bit expensive) and only refresh when the resolution changes
      await Isolate.run(
          () => _addReplayScreenshotNative(jBuffer, width, height),
          debugName: 'SentryReplayRecorder');
    } catch (error, stackTrace) {
      options.logger(
        SentryLevel.error,
        '$logName: native call `addReplayScreenshot` failed',
        exception: error,
        stackTrace: stackTrace,
      );
      if (options.automatedTestMode) {
        rethrow;
      }
    }
  }

  static void _addReplayScreenshotNative(
      JByteBuffer jBuffer, int width, int height) {
    using((arena) {
      // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
      final jBitmap = native.Bitmap.createBitmap$3(
          width, height, native.Bitmap$Config.ARGB_8888)!
        ..releasedBy(arena);
      try {
        jBitmap.copyPixelsFromBuffer(jBuffer);
      } finally {
        jBuffer.release();
      }
      _nativeReplay.onScreenshotRecorded(jBitmap);
    });
  }
}
