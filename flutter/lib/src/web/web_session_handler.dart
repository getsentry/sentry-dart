import '../../sentry_flutter.dart';
import '../native/sentry_native_binding.dart';

class WebSessionHandler {
  final SentryNativeBinding _native;

  WebSessionHandler(this._native);

  Future<void> startSession({String? from, String? to}) async {
    // Only start new session if:
    // 1. We have a valid route change, or
    // 2. It's the initial navigation to root route
    final shouldStartSession = (from != null && to != null && from != to) ||
        (from == null && to == '/');

    // Comment from Sentry Javascript SDK:
    // The session duration for browser sessions does not track a meaningful
    // concept that can be used as a metric.
    // Automatically captured sessions are akin to page views, and thus we
    // discard their duration.
    if (shouldStartSession) {
      await _native.startSession(ignoreDuration: true);
      await _native.captureSession();
    }
  }

  Future<void> updateSessionFromEvent(SentryEvent event) async {
    final exceptions = event.exceptions;
    if (exceptions == null || exceptions.isEmpty) {
      return;
    }

    bool crashed = event.level == SentryLevel.fatal;
    for (final exception in exceptions) {
      if (exception.mechanism?.handled == false) {
        crashed = true;
        break;
      }
    }

    final session = await _native.getSession();
    if (session == null) {
      return;
    }

    // Implementation based on Sentry Javascript SDK:
    // https://github.com/getsentry/sentry-javascript/blob/2b5526565c9008c9f350f02e2b9458d266099199/packages/core/src/client.ts#L803C1-L835C1
    // A session is updated and that session update is sent in only one of the two following scenarios:
    // 1. Session with non terminal status and 0 errors + an error occurred -> Will set error count to 1 and send update
    // 2. Session with non terminal status and n errors + a crash occurred -> Will set status crashed and send update
    final status = session['status'].toString();
    final errors = int.tryParse(session['errors'].toString()) ?? 0;
    final sessionNonTerminal = status == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && errors == 0) || (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final newStatus = crashed ? 'crashed' : status;
      await _native.updateSession(
          status: newStatus, errors: errors == 0 ? 1 : errors);
      await _native.captureSession();
    }
  }
}
