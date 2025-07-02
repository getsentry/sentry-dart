import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../event_processor/replay_event_processor.dart';
import '../native/sentry_native_binding.dart';
import 'replay_config.dart';

@internal
const replayIntegrationName = 'ReplayIntegration';

@internal
class ReplayIntegration extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;

  ReplayIntegration(this._native);

  Hub? _hub;
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    final replayOptions = options.replay;
    if (_native.supportsReplay && replayOptions.isEnabled) {
      options.sdk.addIntegration(replayIntegrationName);
      _hub = hub;
      _options = options;

      // We only need the integration when error-replay capture is enabled.
      if ((replayOptions.onErrorSampleRate ?? 0) > 0) {
        options.addEventProcessor(ReplayEventProcessor(hub, _native));
      }

      SentryScreenshotWidget.onBuild((status, prevStatus) {
        if (status != prevStatus) {
          _native.setReplayConfig(ReplayConfig(
              width: replayOptions.quality.resolutionScalingFactor *
                  (status.size?.width ?? 0.0),
              height: replayOptions.quality.resolutionScalingFactor *
                  (status.size?.height ?? 0.0)));
        }
        return true;
      });
    }
  }

  Future<void> captureReplay() async {
    if (_native.supportsReplay && _options?.replay.isEnabled == true) {
      final replayId = await _native.captureReplay(false);
      _hub?.configureScope((scope) {
        // ignore: invalid_use_of_internal_member
        scope.replayId = replayId;
      });
    }
  }
}
