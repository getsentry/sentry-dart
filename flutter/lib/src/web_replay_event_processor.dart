import 'dart:async';

import '../sentry_flutter.dart';
import 'web/sentry_web_binding.dart';

class WebReplayEventProcessor implements EventProcessor {
  WebReplayEventProcessor(this._binding, this._options);

  final SentryWebBinding _binding;
  final SentryFlutterOptions _options;
  bool _hasFlushedReplay = false;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    try {
      if (!_options.experimental.replay.isEnabled) {
        return event;
      }

      // flush the first occurrence of a replay event
      // converts buffer to session mode (if the session is set as buffer)
      // captures the replay immediately for session mode
      if (event.exceptions?.isNotEmpty == true && !_hasFlushedReplay) {
        await _binding.flushReplay();
        _hasFlushedReplay = true;
      }

      final sentryId = await _binding.getReplayId();
      if (sentryId == null) {
        return event;
      }

      event = event.copyWith(tags: {
        ...?event.tags,
        'replayId': sentryId.toString(),
      });
    } catch (exception, stackTrace) {
      _options.logger(
        SentryLevel.error,
        'Failed to apply $WebReplayEventProcessor',
        exception: exception,
        stackTrace: stackTrace,
      );
    }
    return event;
  }
}
