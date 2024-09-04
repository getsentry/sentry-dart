import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';

class ReplayEventProcessor implements EventProcessor {
  final SentryNativeBinding _binding;

  ReplayEventProcessor(this._binding);

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    if (event.eventId != SentryId.empty() &&
        event.exceptions?.isNotEmpty == true) {
      final isCrash =
          event.exceptions!.any((e) => e.mechanism?.handled == false);
      await _binding.captureReplay(isCrash);
    }
    return event;
  }
}
