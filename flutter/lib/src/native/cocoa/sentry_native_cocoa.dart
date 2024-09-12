import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../event_processor/replay_event_processor.dart';
import '../../replay/recorder.dart';
import '../../replay/recorder_config.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  late final _lib = cocoa.SentryCocoa(DynamicLibrary.process());
  ScreenshotRecorder? _replayRecorder;
  SentryId? _replayId;

  SentryNativeCocoa(super.options, super.channel);

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.experimental.replay.isEnabled &&
        options.platformChecker.platform.isIOS) {
      // We only need the integration when error-replay capture is enabled.
      if ((options.experimental.replay.onErrorSampleRate ?? 0) > 0) {
        options.addEventProcessor(ReplayEventProcessor(this));
      }

      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??=
                ScreenshotRecorder(ScreenshotRecorderConfig(), options);
            final replayId =
                SentryId.fromId(call.arguments['replayId'] as String);
            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // ignore: invalid_use_of_internal_member
                s.replayId = replayId;
              });
            }

            Uint8List? imageBytes;
            await _replayRecorder?.capture((image) async {
              final imageData =
                  await image.toByteData(format: ImageByteFormat.png);
              if (imageData != null) {
                options.logger(
                    SentryLevel.debug,
                    'Replay: captured screenshot ('
                    '${image.width}x${image.height} pixels, '
                    '${imageData.lengthInBytes} bytes)');
                imageBytes = imageData.buffer.asUint8List();
              } else {
                options.logger(SentryLevel.warning,
                    'Replay: failed to convert screenshot to PNG');
              }
            });
            return imageBytes;
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
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
