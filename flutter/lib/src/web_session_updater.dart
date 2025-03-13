import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';

class WebSessionUpdater implements BeforeSendEventObserver {
  final SentryFlutterOptions _options;
  final SentryNativeBinding _nativeBinding;

  WebSessionUpdater(this._nativeBinding, this._options);

  @override
  void onBeforeSendEvent(SentryEvent event, Hint hint) {
    _updateSessionFromEvent(event);
  }

  void _updateSessionFromEvent(SentryEvent event) async {
    if (_options.enableAutoSessionTracking == false) {
      _options.logger(
        SentryLevel.info,
        'Auto session tracking is disabled.',
      );
      return;
    }

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
    final session = await _nativeBinding.getSession();
    if (session == null) {
      return;
    }

    final sessionNonTerminal = session['status'] == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && session['errors'] == 0) ||
            (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final status = crashed ? 'crashed' : session['status'].toString();
      await _nativeBinding.updateSession(
          status: status, errors: errored || crashed ? 1 : 0);
      await _nativeBinding.captureSession();
    }
  }
}
