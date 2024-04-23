import 'dart:async';

import 'package:meta/meta.dart';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

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

  /// Needed to check if we somehow caused a `print()` recursion
  bool _isPrinting = false;

  @visibleForTesting
  Future<void> captureError(
    Hub hub,
    SentryOptions options,
    Object exception,
    StackTrace stackTrace,
  ) async {
    options.logger(
      SentryLevel.error,
      'Uncaught zone error',
      logger: 'sentry.runZonedGuarded',
      exception: exception,
      stackTrace: stackTrace,
    );

    // runZonedGuarded doesn't crash the app, but is not handled by the user.
    final mechanism = Mechanism(type: 'runZonedGuarded', handled: false);
    final throwableMechanism = ThrowableMechanism(mechanism, exception);

    final event = SentryEvent(
      throwable: throwableMechanism,
      level: options.markAutomaticallyCollectedErrorsAsFatal
          ? SentryLevel.fatal
          : SentryLevel.error,
      timestamp: hub.options.clock(),
    );

    // marks the span status if none to `internal_error` in case there's an
    // unhandled error
    hub.configureScope(
      (scope) => scope.span?.status ??= const SpanStatus.internalError(),
    );

    await hub.captureEvent(event, stackTrace: stackTrace);
  }

  @override
  Future<void> call(Hub hub, SentryOptions options) {
    final completer = Completer<void>();

    runZonedGuarded(
      () async {
        try {
          await _runner();
        } finally {
          completer.complete();
        }
      },
      (exception, stackTrace) async {
        await captureError(hub, options, exception, stackTrace);
        final onError = _onError;
        if (onError != null) {
          await onError(exception, stackTrace);
        }
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (!options.enablePrintBreadcrumbs || !hub.isEnabled) {
            // early bail out, in order to better guard against the recursion
            // as described below.
            parent.print(zone, line);
            return;
          }

          if (_isPrinting) {
            // We somehow landed in a recursion.
            // This happens for example if:
            // - hub.addBreadcrumb() called print() itself
            // - This happens for example if hub.isEnabled == false and
            //   options.logger == dartLogger
            //
            // Anyway, in order to not cause a stack overflow due to recursion
            // we drop any further print() call while adding a breadcrumb.
            parent.print(
              zone,
              'Recursion during print() call. '
              'Abort adding print() call as Breadcrumb.',
            );
            return;
          }

          _isPrinting = true;

          try {
            hub.addBreadcrumb(
              Breadcrumb.console(
                message: line,
                level: SentryLevel.debug,
              ),
            );

            parent.print(zone, line);
          } finally {
            _isPrinting = false;
          }
        },
      ),
    );

    options.sdk.addIntegration('runZonedGuardedIntegration');

    return completer.future;
  }
}
