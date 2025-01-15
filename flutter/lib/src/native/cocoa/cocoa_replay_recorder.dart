import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_recorder.dart';
import '../../screenshot/recorder.dart';
import '../../screenshot/recorder_config.dart';
import '../../screenshot/stabilizer.dart';
import '../native_memory.dart';

@internal
class CocoaReplayRecorder {
  final SentryFlutterOptions _options;
  final ScreenshotRecorder _recorder;
  late final ScreenshotStabilizer<void> _stabilizer;
  var _completer = Completer<Map<String, int>?>();

  CocoaReplayRecorder(this._options)
      : _recorder =
            ReplayScreenshotRecorder(ScreenshotRecorderConfig(), _options) {
    _stabilizer = ScreenshotStabilizer(_recorder, _options, (screenshot) async {
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
      _completer.complete(json);
    });
  }

  Future<Map<String, int>?> captureScreenshot() async {
    _completer = Completer();
    _stabilizer.ensureFrameAndAddCallback((msSinceEpoch) {
      _stabilizer.capture(msSinceEpoch).onError(_completer.completeError);
    });
    return _completer.future;
  }
}
