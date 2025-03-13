import 'dart:async';

import 'package:sentry/sentry.dart';

import '../native/sentry_native_binding.dart';

/// Updates the native session status based on event information.
/// Handles session status transitions based on error/crash state.
class SessionEventProcessor implements EventProcessor {
  final SentryNativeBinding? _native;

  SessionEventProcessor(this._native);

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    // Skip updating session for transactions
    if (event is SentryTransaction) {
      return event;
    }
    
    // event is done processing, we can now update sessions
    bool crashed = event.level == SentryLevel.fatal;
    bool errored = false;

    if (event.exceptions?.isNotEmpty == true) {
      errored = true;

      for (final exception in event.exceptions!) {
        if (exception.mechanism?.handled == false) {
          crashed = true;
          break;
        }
      }
    }

    // A session is updated and that session update is sent in only one of the two following scenarios:
    // 1. Session with non terminal status and 0 errors + an error occurred -> Will set error count to 1 and send update
    // 2. Session with non terminal status and 1 error + a crash occurred -> Will set status crashed and send update
    final session = await _native?.getSession();
    final sessionNonTerminal = session?['status'] == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && session?['errors'] == 0) ||
            (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final status = crashed
          ? 'crashed'
          : errored
              ? 'errored'
              : 'ok';
      await _native?.updateSession(
          status: status, errors: errored || crashed ? 1 : 0);
      await _native?.captureSession();
    }
    
    return event;
  }
} 