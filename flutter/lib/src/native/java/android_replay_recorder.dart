import 'dart:isolate';

import 'package:jni/jni.dart';
import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import 'binding.dart' as native;

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  late final _nativeReplay = native.SentryFlutterPlugin$Companion(null)
      .privateSentryGetReplayIntegration()!;
  // Android Bitmap creation is a bit costly so we reuse it between captures.
  native.Bitmap? _bitmap;

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

      // Note: possible future improvement: long-lived isolate
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

  @override
  Future<void> stop() async {
    await super.stop();
    _bitmap?.release();
    _bitmap = null;
  }

  void _addReplayScreenshotNative(JByteBuffer jBuffer, int width, int height) {
    if (_bitmap != null) {
      if (_bitmap!.getWidth() != width || _bitmap!.getHeight() != height) {
        _bitmap!.release();
        _bitmap = null;
      }
    }

    // https://developer.android.com/reference/android/graphics/Bitmap#createBitmap(int,%20int,%20android.graphics.Bitmap.Config)
    // Note: in the currently generated API this may return null so we null-check below.
    _bitmap ??= native.Bitmap.createBitmap$3(
        width, height, native.Bitmap$Config.ARGB_8888);

    try {
      _bitmap?.copyPixelsFromBuffer(jBuffer);
    } finally {
      jBuffer.release();
    }

    if (_bitmap != null) {
      _nativeReplay.onScreenshotRecorded(_bitmap!);
    }
  }
}
