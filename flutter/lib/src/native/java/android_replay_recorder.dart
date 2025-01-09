import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/scheduled_recorder.dart';
import '../../screenshot/screenshot.dart';
import '../sentry_safe_method_channel.dart';

@internal
class AndroidReplayRecorder extends ScheduledScreenshotRecorder {
  final SentrySafeMethodChannel _channel;
  final String _cacheDir;

  AndroidReplayRecorder(
      super.config, super.options, this._channel, this._cacheDir) {
    super.callback = _addReplayScreenshot;
  }

  Future<void> _addReplayScreenshot(
      Screenshot screenshot, bool isNewlyCaptured) async {
    final timestamp = screenshot.timestamp.millisecondsSinceEpoch;
    final filePath = "$_cacheDir/$timestamp.png";

    try {
      final pngData = await screenshot.pngData;
      options.logger(
          SentryLevel.debug,
          '$logName: saving ${isNewlyCaptured ? 'new' : 'repeated'} screenshot to'
          ' $filePath (${screenshot.width}x${screenshot.height} pixels, '
          '${pngData.lengthInBytes} bytes)');
      await options.fileSystem
          .file(filePath)
          .writeAsBytes(pngData.buffer.asUint8List(), flush: true);

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
