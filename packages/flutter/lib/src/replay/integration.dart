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
        // Skip config update if the difference is negligible (e.g., due to floating-point precision)
        // e.g a size.height of 200.00001 and 200.001 could be treated as equals
        if (prevStatus != null && status.matches(prevStatus)) {
          return true;
        }

        _native.setReplayConfig(ReplayConfig(
            windowWidth: status.size?.width ?? 0.0,
            windowHeight: status.size?.height ?? 0.0,
            width: replayOptions.quality.resolutionScalingFactor *
                (status.size?.width ?? 0.0),
            height: replayOptions.quality.resolutionScalingFactor *
                (status.size?.height ?? 0.0)));

        return true;
      });
    }
  }

  Future<void> captureReplay() async {
    if (_native.supportsReplay && _options?.replay.isEnabled == true) {
      final replayId = await _native.captureReplay();
      _hub?.configureScope((scope) {
        // ignore: invalid_use_of_internal_member
        scope.replayId = replayId;
      });
    }
  }
}
