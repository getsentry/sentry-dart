import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';

class ReplayEventProcessor implements EventProcessor {
  final Hub _hub;
  final SentryNativeBinding _binding;

  ReplayEventProcessor(this._hub, this._binding);

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final hasException = event.eventId != SentryId.empty() &&
        event.exceptions?.isNotEmpty == true;
    final isFeedback =
        event.eventId != SentryId.empty() && event.type == 'feedback';
    final shouldCaptureReplay = hasException || isFeedback;

    if (shouldCaptureReplay) {
      final replayId = await _binding.captureReplay();
      // If session replay is disabled, this is the first time we receive the ID.
      _hub.configureScope((scope) {
        // ignore: invalid_use_of_internal_member
        scope.replayId = replayId;
      });
    }
    return event;
  }
}
