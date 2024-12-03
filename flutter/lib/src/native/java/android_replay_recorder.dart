import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../sentry_safe_method_channel.dart';

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  final SentrySafeMethodChannel _channel;
  final String _cacheDir;

  AndroidReplayRecorder(
      super.config, super.options, this._channel, this._cacheDir) {
    super.callback = _addReplayScreenshot;
  }

  Future<void> _addReplayScreenshot(ScreenshotPng screenshot) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = "$_cacheDir/$timestamp.png";

    options.logger(
        SentryLevel.debug,
        '$logName: saving screenshot to $filePath ('
        '${screenshot.width}x${screenshot.height} pixels, '
        '${screenshot.data.lengthInBytes} bytes)');
    try {
      await options.fileSystem
          .file(filePath)
          .writeAsBytes(screenshot.data.buffer.asUint8List(), flush: true);

      await _channel.invokeMethod(
        'addReplayScreenshot',
        {'path': filePath, 'timestamp': timestamp},
      );
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
