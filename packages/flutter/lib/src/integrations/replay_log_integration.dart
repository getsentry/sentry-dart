// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry/sentry.dart';
import '../sentry_flutter_options.dart';
import '../native/sentry_native_binding.dart';

/// Integration that adds replay-related information to logs using lifecycle callbacks
class ReplayLogIntegration implements Integration<SentryFlutterOptions> {
  static const String integrationName = 'ReplayLog';

  final SentryNativeBinding? _native;
  ReplayLogIntegration(this._native);

  SentryFlutterOptions? _options;
  SdkLifecycleCallback<OnBeforeCaptureLog>? _addReplayInformation;

  @override
  Future<void> call(Hub hub, SentryFlutterOptions options) async {
    if (!options.replay.isEnabled) {
      return;
    }
    final sessionSampleRate = options.replay.sessionSampleRate ?? 0;
    final onErrorSampleRate = options.replay.onErrorSampleRate ?? 0;

    _options = options;
    _addReplayInformation = (OnBeforeCaptureLog event) {
      final scopeReplayId = hub.scope.replayId;
      final replayId = scopeReplayId ?? _native?.replayId;
      final replayIsBuffering = replayId != null && scopeReplayId == null;

      if (sessionSampleRate > 0 && replayId != null && !replayIsBuffering) {
        event.log.attributes['sentry.replay_id'] = SentryAttribute.string(
          scopeReplayId.toString(),
        );
      } else if (onErrorSampleRate > 0 &&
          replayId != null &&
          replayIsBuffering) {
        event.log.attributes['sentry.replay_id'] = SentryAttribute.string(
          replayId.toString(),
        );
        event.log.attributes['sentry._internal.replay_is_buffering'] =
            SentryAttribute.bool(true);
      }
    };
    options.lifecycleRegistry
        .registerCallback<OnBeforeCaptureLog>(_addReplayInformation!);
    options.sdk.addIntegration(integrationName);
  }

  @override
  Future<void> close() async {
    final options = _options;
    final addReplayInformation = _addReplayInformation;

    if (options != null && addReplayInformation != null) {
      options.lifecycleRegistry
          .removeCallback<OnBeforeCaptureLog>(addReplayInformation);
    }

    _options = null;
    _addReplayInformation = null;
  }
}
