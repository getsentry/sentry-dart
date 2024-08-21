import 'dart:async';

import '../sentry_flutter.dart';
import 'sentry_replay_options.dart';
import 'web/sentry_web_binding.dart';

class WebReplayEventProcessor implements EventProcessor {
  WebReplayEventProcessor(this._binding, this._replayOptions);

  final SentryWebBinding _binding;
  final SentryReplayOptions _replayOptions;
  bool hasFlushedReplay = false;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    try {
      if (!_replayOptions.isEnabled) {
        return event;
      }

      if (event.exceptions?.isNotEmpty == true && !hasFlushedReplay) {
        await _binding.flushReplay();
        hasFlushedReplay = true;
      }

      final sentryId = await _binding.getReplayId();

      event = event.copyWith(tags: {
        ...?event.tags,
        'replayId': sentryId.toString(),
      });
    } catch (exception, stackTrace) {
      // todo: log
    }

    return event;
  }
}
