import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_recorder.dart';
import '../../screenshot/recorder.dart';
import '../../screenshot/recorder_config.dart';
import '../native_memory.dart';

@internal
class CocoaReplayRecorder {
  final SentryFlutterOptions _options;
  final ScreenshotRecorder _recorder;

  CocoaReplayRecorder(this._options)
      : _recorder = ReplayScreenshotRecorder(
          ScreenshotRecorderConfig(
            pixelRatio: _options.replay.quality.resolutionScalingFactor,
          ),
          _options,
        );

  Future<Map<String, int>?> captureScreenshot() async {
    return _recorder.capture((screenshot) async {
      final data = await screenshot.rawRgbaData;
      _options.logger(
          SentryLevel.debug,
          'Replay: captured screenshot ('
          '${screenshot.width}x${screenshot.height} pixels, '
          '${data.lengthInBytes} bytes)');

      // Malloc memory and copy the data. Native must free it.
      final json = data.toNativeMemory().toJson();
      json['width'] = screenshot.width;
      json['height'] = screenshot.height;
      return json;
    });
  }
}
