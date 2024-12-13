import 'dart:async';
import 'dart:ffi';
import 'dart:ui';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../../screenshot/recorder.dart';
import '../../screenshot/recorder_config.dart';
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
                ScreenshotRecorder(ScreenshotRecorderConfig(), options);
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

            return _replayRecorder?.capture((image) async {
              final imageData =
                  await image.toByteData(format: ImageByteFormat.png);
              if (imageData != null) {
                options.logger(
                    SentryLevel.debug,
                    'Replay: captured screenshot ('
                    '${image.width}x${image.height} pixels, '
                    '${imageData.lengthInBytes} bytes)');
                return imageData.buffer.asUint8List();
              } else {
                options.logger(SentryLevel.warning,
                    'Replay: failed to convert screenshot to PNG');
              }
            });
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
