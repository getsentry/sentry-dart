import 'dart:async';
import 'dart:ffi';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../../replay/replay_config.dart';
import '../sentry_native_channel.dart';
import 'binding.dart' as cocoa;
import 'cocoa_replay_recorder.dart';

@internal
class SentryNativeCocoa extends SentryNativeChannel {
  late final _lib = cocoa.SentryCocoa(DynamicLibrary.process());
  CocoaReplayRecorder? _replayRecorder;
  SentryId? _replayId;

  SentryNativeCocoa(super.options);

  @override
  bool get supportsReplay => options.platform.isIOS;

  @override
  SentryId? get replayId => _replayId;

  @override
  Future<void> init(Hub hub) async {
    // We only need these when replay is enabled (session or error capture)
    // so let's set it up conditionally. This allows Dart to trim the code.
    if (options.replay.isEnabled) {
      channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'captureReplayScreenshot':
            _replayRecorder ??= CocoaReplayRecorder(options);

            final replayIdArg = call.arguments['replayId'];
            final replayIsBuffering =
                call.arguments['replayIsBuffering'] as bool? ?? false;

            final replayId = replayIdArg == null
                ? null
                : SentryId.fromId(replayIdArg as String);

            if (_replayId != replayId) {
              _replayId = replayId;
              hub.configureScope((s) {
                // Only set replay ID on scope if not buffering (active session mode)
                // ignore: invalid_use_of_internal_member
                s.replayId = !replayIsBuffering ? replayId : null;
              });
            }

            return _replayRecorder!.captureScreenshot();
          default:
            throw UnimplementedError('Method ${call.method} not implemented');
        }
      });
    }

    return super.init(hub);
  }

  @override
  FutureOr<SentryId> captureReplay() async {
    final replayId = await super.captureReplay();
    _replayId = replayId;
    return replayId;
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
