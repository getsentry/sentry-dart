import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';

/// Updates session based on errored events for Flutter Web.
// ignore: invalid_use_of_internal_member
class WebSessionUpdater implements BeforeSendEventObserver {
  final SentryFlutterOptions _options;
  final SentryNativeBinding _nativeBinding;

  WebSessionUpdater(this._nativeBinding, this._options);

  @override
  void onBeforeSendEvent(SentryEvent event, Hint hint) async {
    if (_options.enableAutoSessionTracking == false) {
      _options.logger(
        SentryLevel.info,
        'Auto session tracking for web disabled.',
        logger: '$WebSessionUpdater',
      );
      return;
    }
    final exceptions = event.exceptions;
    if (exceptions == null || exceptions.isEmpty) {
      _options.logger(
        SentryLevel.debug,
        'No exceptions found in the event, not updating session.',
        logger: '$WebSessionUpdater',
      );
      return;
    }

    bool crashed = event.level == SentryLevel.fatal;
    for (final exception in exceptions) {
      if (exception.mechanism?.handled == false) {
        crashed = true;
        break;
      }
    }

    // Implementation based on Sentry Javascript SDK:
    // https://github.com/getsentry/sentry-javascript/blob/2b5526565c9008c9f350f02e2b9458d266099199/packages/core/src/client.ts#L803C1-L835C1
    // A session is updated and that session update is sent in only one of the two following scenarios:
    // 1. Session with non terminal status and 0 errors + an error occurred -> Will set error count to 1 and send update
    // 2. Session with non terminal status and n errors + a crash occurred -> Will set status crashed and send update
    final session = await _nativeBinding.getSession();
    if (session == null) {
      return;
    }

    final status = session['status'].toString();
    final errors = int.tryParse(session['errors'].toString()) ?? 0;
    final sessionNonTerminal = status == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && errors == 0) || (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final changedStatus = crashed ? 'crashed' : status;
      await _nativeBinding.updateSession(
          status: changedStatus, errors: errors + 1);
      await _nativeBinding.captureSession();
    }
  }
}
