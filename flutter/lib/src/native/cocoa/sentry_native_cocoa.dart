import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../../replay/replay_recorder.dart';
import '../../screenshot/recorder.dart';
import '../../screenshot/recorder_config.dart';
import '../../screenshot/retrier.dart';
import '../native_memory.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  late final _lib = cocoa.SentryCocoa(DynamicLibrary.process());
  ScreenshotRecorder? _replayRecorder;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platformChecker.platform.isIOS;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.experimental.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??=
                ReplayScreenshotRecorder(ScreenshotRecorderConfig(), options);

            final replayId = call.arguments['replayId'] == null
                ? null
                : SentryId.fromId(call.arguments['replayId'] as String);
            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // ignore: invalid_use_of_internal_member
                s.replayId = replayId;
              });
            }

            final widgetsBinding = options.bindingUtils.instance;
            if (widgetsBinding == null) {
              options.logger(SentryLevel.warning,
                  'Replay: failed to capture screenshot, WidgetsBinding.instance is null');
              return null;
            }

            final completer = Completer<Uint8List?>();
            final retrier = ScreenshotRetrier(_replayRecorder!, options,
                (screenshot) async {
              final pngData = await screenshot.pngData;
              options.logger(
                  SentryLevel.debug,
                  'Replay: captured screenshot ('
                  '${screenshot.width}x${screenshot.height} pixels, '
                  '${pngData.lengthInBytes} bytes)');
              completer.complete(pngData.buffer.asUint8List());
            });
            retrier.ensureFrameAndAddCallback((msSinceEpoch) {
              retrier.capture(msSinceEpoch).onError(completer.completeError);
            });
            final uint8List = await completer.future;

            // Malloc memory and copy the data. Native must free it.
            return uint8List?.toNativeMemory().toJson();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  @override
  FutureOr<void> setReplayConfig(ReplayConfig config) {
    // Note: unused on iOS.
  }

  @override
  int? startProfiler(SentryId traceId) => tryCatchSync('startProfiler', () {
        final cSentryId = cocoa.SentryId1.alloc(_lib)
          ..initWithUUIDString_(cocoa.NSString(_lib, traceId.toString()));
        final startTime =
            cocoa.PrivateSentrySDKOnly.startProfilerForTrace_(_lib, cSentryId);
        return startTime;
      });
}
