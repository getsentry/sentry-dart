import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// Integration that runs runner function within `runZonedGuarded` and capture
/// errors on the `runZonedGuarded` error handler.
/// See https://api.dart.dev/stable/dart-async/runZonedGuarded.html
///
/// This integration also records calls to `print()` as Breadcrumbs.
/// This can be configured with [SentryOptions.enablePrintBreadcrumbs]
class RunZonedGuardedIntegration extends Integration {
  RunZonedGuardedIntegration(this._runner);

  final Future<void> Function() _runner;

  /// Needed to check if we somehow caused a `print()` recursion
  bool _isPrinting = false;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
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
        options.logger(
          SentryLevel.error,
          'Uncaught zone error',
          logger: 'sentry.runZonedGuarded',
          exception: exception,
          stackTrace: stackTrace,
        );

        // runZonedGuarded doesn't crash the App.
        final mechanism = Mechanism(type: 'runZonedGuarded', handled: true);
        final throwableMechanism = ThrowableMechanism(mechanism, exception);

        final event = SentryEvent(
          throwable: throwableMechanism,
          level: SentryLevel.fatal,
          timestamp: hub.options.clock(),
        );

        // mark the span if any to `internal_error` status in case there's an
        // unhandled error
        hub.configureScope((scope) => {
              scope.span?.status = const SpanStatus.internalError(),
            });

        await hub.captureEvent(event, stackTrace: stackTrace);
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
