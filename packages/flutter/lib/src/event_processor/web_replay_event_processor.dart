import 'dart:async';

import '../../sentry_flutter.dart';
import '../web/sentry_js_binding.dart';

class WebReplayEventProcessor implements EventProcessor {
  WebReplayEventProcessor(this._binding);

  final SentryJsBinding _binding;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) {
    final replayId = _binding.getReplayId(onlyIfSampled: true);
    if (replayId == null) {
      return event;
    }

    event.tags = {
      ...?event.tags,
      'replayId': replayId,
    };
    event.contexts.trace?.replayId = SentryId.fromId(replayId);

    return event;
  }
}
