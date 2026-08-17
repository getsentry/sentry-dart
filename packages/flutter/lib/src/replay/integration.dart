// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';
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
  SdkLifecycleCallback<OnBeforeSendEvent>? _onBeforeSendEventCallback;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    final replayOptions = options.replay;
    if (_native.supportsReplay && replayOptions.isEnabled) {
      options.sdk.addIntegration(replayIntegrationName);
      _hub = hub;
      _options = options;

      // We only need the hook when error-replay capture is enabled. It runs in
      // the send phase rather than as an event processor so that an event
      // dropped by sampling or `beforeSend` cannot flush the buffered replay.
      if ((replayOptions.onErrorSampleRate ?? 0) > 0) {
        final callback = _onEventAboutToBeSent;
        options.lifecycleRegistry.registerCallback<OnBeforeSendEvent>(callback);
        _onBeforeSendEventCallback = callback;
      }

      SentryScreenshotWidget.onBuild((status, prevStatus) {
        // Skip config update if the difference is negligible (e.g., due to floating-point precision)
        // e.g a size.height of 200.00001 and 200.001 could be treated as equals
        if (prevStatus != null && status.matches(prevStatus)) {
          return true;
        }

        _native.setReplayConfig(
          ReplayConfig(
            windowWidth: status.size?.width ?? 0.0,
            windowHeight: status.size?.height ?? 0.0,
            width:
                replayOptions.quality.resolutionScalingFactor *
                (status.size?.width ?? 0.0),
            height:
                replayOptions.quality.resolutionScalingFactor *
                (status.size?.height ?? 0.0),
          ),
        );

        return true;
      });
    }
  }

  @override
  void close() {
    final callback = _onBeforeSendEventCallback;
    if (callback != null) {
      _options?.lifecycleRegistry.removeCallback<OnBeforeSendEvent>(callback);
      _onBeforeSendEventCallback = null;
    }
  }

  Future<void> _onEventAboutToBeSent(OnBeforeSendEvent lifecycleEvent) async {
    final event = lifecycleEvent.event;
    final hasEventId = event.eventId != SentryId.empty();
    final isErrorEvent = hasEventId && event.exceptions?.isNotEmpty == true;
    final isFeedbackEvent = hasEventId && event.type == 'feedback';
    // The feedback widget captures the replay itself when the form opens.
    final isWidgetFeedbackEvent =
        lifecycleEvent.hint.get(TypeCheckHint.isWidgetFeedback) == true;

    if (isErrorEvent || (isFeedbackEvent && !isWidgetFeedbackEvent)) {
      await captureReplay();
    }
  }

  Future<void> captureReplay() async {
    if (_native.supportsReplay && _options?.replay.isEnabled == true) {
      final replayId = await _native.captureReplay();
      _hub?.configureScope((scope) {
        scope.replayId = replayId;
      });
    }
  }
}
