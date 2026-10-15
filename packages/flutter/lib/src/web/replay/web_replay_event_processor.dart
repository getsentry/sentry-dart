import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry_flutter.dart';
import '../sentry_js_binding.dart';

/// Links Dart events to the JS SDK's current replay.
///
/// Dart events reach the JS SDK as raw envelopes, which skip the JS event
/// processors that would add the replay ID. The `replayId` tag is also what
/// the JS Replay checks to send a buffered replay when an error is sent.
@internal
class WebReplayEventProcessor implements EventProcessor {
  WebReplayEventProcessor(this._binding);

  final SentryJsBinding _binding;

  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) {
    final replayId = _binding.getReplayId(onlyIfSampled: true);
    if (replayId == null) {
      return event;
    }

    event.tags = {...?event.tags, 'replayId': replayId};
    event.contexts.trace?.replayId = SentryId.fromId(replayId);

    return event;
  }
}
