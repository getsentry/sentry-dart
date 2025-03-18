import 'dart:async';

import '../sentry_flutter.dart';
import 'native/sentry_native_binding.dart';

/// Updates session based on errored events for Flutter Web.
// ignore: invalid_use_of_internal_member
class WebSessionUpdater implements BeforeSendEventObserver {
  final SentryNativeBinding _nativeBinding;
  final bool _isSessionUpdatesEnabled;

  WebSessionUpdater(this._nativeBinding, SentryFlutterOptions options)
      : _isSessionUpdatesEnabled = _shouldEnableSessionUpdates(options);

  @override
  FutureOr<void> onBeforeSendEvent(SentryEvent event, Hint hint) async {
    if (!_isSessionUpdatesEnabled) {
      return;
    }

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

    final session = await _nativeBinding.getSession();
    if (session == null) {
      return;
    }

    await _updateSession(session, crashed);
  }

  /// Implementation based on Sentry Javascript SDK:
  /// https://github.com/getsentry/sentry-javascript/blob/2b5526565c9008c9f350f02e2b9458d266099199/packages/core/src/client.ts#L803C1-L835C1
  /// A session is updated and that session update is sent in only one of the two following scenarios:
  /// 1. Session with non terminal status and 0 errors + an error occurred -> Will set error count to 1 and send update
  /// 2. Session with non terminal status and n errors + a crash occurred -> Will set status crashed and send update
  Future<void> _updateSession(
      Map<dynamic, dynamic> session, bool crashed) async {
    final status = session['status'].toString();
    final errors = int.tryParse(session['errors'].toString()) ?? 0;
    final sessionNonTerminal = status == 'ok';
    final shouldUpdateAndSend =
        (sessionNonTerminal && errors == 0) || (sessionNonTerminal && crashed);

    if (shouldUpdateAndSend) {
      final newStatus = crashed ? 'crashed' : status;
      await _nativeBinding.updateSession(
          status: newStatus, errors: errors == 0 ? 1 : errors);
      await _nativeBinding.captureSession();
    }
  }

  static bool _shouldEnableSessionUpdates(SentryFlutterOptions options) {
    if (!options.navigatorObserverRegistered) {
      _log(options, SentryLevel.info,
          'SentryNavigatorObserver not registered: Web session updater disabled');
      return false;
    }

    if (!options.enableAutoSessionTracking) {
      _log(options, SentryLevel.info,
          'Auto session tracking disabled: Web session updater disabled');
      return false;
    }

    if (!options.platform.isWeb) {
      _log(options, SentryLevel.info,
          'Not a web platform: Web session updater disabled');
      return false;
    }

    return true;
  }

  static void _log(
      SentryFlutterOptions options, SentryLevel level, String message) {
    options.logger(level, message, logger: '$WebSessionUpdater');
  }
}
