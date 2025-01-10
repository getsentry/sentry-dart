import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_recorder.dart';
import '../../screenshot/recorder.dart';
import '../../screenshot/recorder_config.dart';
import '../../screenshot/stabilizer.dart';

@internal
class CocoaReplayRecorder {
  final SentryFlutterOptions _options;
  final ScreenshotRecorder _recorder;
  late final ScreenshotStabilizer<void> _stabilizer;
  var _completer = Completer<Uint8List?>();

  CocoaReplayRecorder(this._options)
      : _recorder =
            ReplayScreenshotRecorder(ScreenshotRecorderConfig(), _options) {
    _stabilizer = ScreenshotStabilizer(_recorder, _options, (screenshot) async {
      final pngData = await screenshot.pngData;
      _options.logger(
          SentryLevel.debug,
          'Replay: captured screenshot ('
          '${screenshot.width}x${screenshot.height} pixels, '
          '${pngData.lengthInBytes} bytes)');
      _completer.complete(pngData.buffer.asUint8List());
    });
  }

  Future<Uint8List?> captureScreenshot() async {
    _completer = Completer<Uint8List?>();
    _stabilizer.ensureFrameAndAddCallback((msSinceEpoch) {
      _stabilizer.capture(msSinceEpoch).onError(_completer.completeError);
    });
    return _completer.future;
  }
}
