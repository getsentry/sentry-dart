import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
import '../event_processor/replay_event_processor.dart';
import '../native/sentry_native_binding.dart';

@internal
const replayIntegrationName = 'ReplayIntegration';

@internal
class ReplayIntegration extends Integration<SentryFlutterOptions> {
  final SentryNativeBinding _native;

  ReplayIntegration(this._native);

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (_native.supportsReplay && options.experimental.replay.isEnabled) {
      options.sdk.addIntegration(replayIntegrationName);

      // We only need the integration when error-replay capture is enabled.
      if ((options.experimental.replay.onErrorSampleRate ?? 0) > 0) {
        options.addEventProcessor(ReplayEventProcessor(hub, _native));
      }
    }
  }
}
