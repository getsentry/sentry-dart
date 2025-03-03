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

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    final replayOptions = options.replay;
    if (_native.supportsReplay && replayOptions.isEnabled) {
      options.sdk.addIntegration(replayIntegrationName);

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
}
