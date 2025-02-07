import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import 'binding.dart' as native;

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  late final native.ReplayIntegration _nativeReplay;

  AndroidReplayRecorder(super.config, super.options, this._nativeReplay) {
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

      using((arena) {
        // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
        final jBitmap = native.Bitmap.createBitmap$3(
          screenshot.width,
          screenshot.height,
          native.Bitmap$Config.ARGB_8888,
        )?..releasedBy(arena);
        if (jBitmap == null) {
          options.logger(
            SentryLevel.warning,
            '$logName: failed to create native Bitmap',
          );
          return;
        }

        // TODO this uses setAll() which is slow, change to memcpy or ideally use Uint8List directly.
        final jBuffer = JByteBuffer.fromList(data.buffer.asUint8List());
        try {
          jBitmap.copyPixelsFromBuffer(jBuffer);
        } finally {
          jBuffer.release();
        }
        _nativeReplay.onScreenshotRecorded(jBitmap);
      });

      // _nativeReplay.onScreenshotRecorded$1(
      //     native.File(filePath.toJString()), timestamp);
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
}
