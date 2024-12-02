import 'dart:async';

import '../sentry.dart';

/// Called inside of `runZonedGuarded`
typedef RunZonedGuardedRunner = Future<void> Function();

/// Caught exception and stacktrace in `runZonedGuarded`
typedef RunZonedGuardedOnError = FutureOr<void> Function(Object, StackTrace);

/// Integration that runs runner function within `runZonedGuarded` and capture
/// errors on the `runZonedGuarded` error handler.
/// See https://api.dart.dev/stable/dart-async/runZonedGuarded.html
///
/// This integration also records calls to `print()` as Breadcrumbs.
/// This can be configured with [SentryOptions.enablePrintBreadcrumbs]
class RunZonedGuardedIntegration extends Integration<SentryOptions> {
  RunZonedGuardedIntegration(this._runner, this._onError);

  final RunZonedGuardedRunner _runner;
  final RunZonedGuardedOnError? _onError;

  @override
  Future<void> call(Hub hub, SentryOptions options) {
    final completer = Completer<void>();

    SentryRunZonedGuarded.sentryRunZonedGuarded(hub, () async {
      try {
        await _runner();
      } finally {
        completer.complete();
      }
    }, _onError);

    options.sdk.addIntegration('runZonedGuardedIntegration');

    return completer.future;
  }
}
