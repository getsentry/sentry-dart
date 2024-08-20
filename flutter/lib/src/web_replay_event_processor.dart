import 'dart:async';

import '../sentry_flutter.dart';
import 'web/sentry_web_binding.dart';

class WebReplayEventProcessor implements EventProcessor {
  WebReplayEventProcessor(this._binding);

  final SentryWebBinding _binding;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    try {
      await _binding.flushReplay();

      await Future<void>.delayed(Duration(seconds: 1));

      final sentryId = await _binding.getReplayId();

      print(sentryId);
      event = event.copyWith(tags: {
        ...?event.tags,
        'replayId': sentryId.toString(),
      });
      event.tags?.forEach((key, value) {
        print('$key: $value');
      });
    } catch (exception, stackTrace) {
      print('Failed to get replay id: $exception $stackTrace');
    }

    return event;
  }
}
