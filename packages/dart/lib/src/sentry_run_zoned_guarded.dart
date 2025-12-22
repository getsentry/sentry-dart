import 'dart:async';

import 'package:meta/meta.dart';

import '../sentry.dart';
import 'debug_logger.dart';

@internal
class SentryRunZonedGuarded {
  /// Needed to check if we somehow caused a `print()` recursion
  static var _isPrinting = false;

  static R? sentryRunZonedGuarded<R>(
    Hub hub,
    R Function() body,
    void Function(Object error, StackTrace stack)? onError, {
    Map<Object?, Object?>? zoneValues,
    ZoneSpecification? zoneSpecification,
  }) {
    final sentryOnError = (exception, stackTrace) async {
      final options = hub.options;
      await _captureError(hub, options, exception, stackTrace);

      if (onError != null) {
        onError(exception, stackTrace);
      }
    };

    final userPrint = zoneSpecification?.print;

    final sentryZoneSpecification = ZoneSpecification.from(
      zoneSpecification ?? ZoneSpecification(),
      print: (self, parent, zone, line) {
        final options = hub.options;

        if (userPrint != null) {
          userPrint(self, parent, zone, line);
        }

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
          //   options.logger == _debugLogger
          //
          // Anyway, in order to not cause a stack overflow due to recursion
          // we drop any further print() call while adding a breadcrumb.
          parent.print(
            zone,
            'Recursion during print() call.'
            'Abort adding print() call as Breadcrumb.',
          );
          return;
        }

        try {
          _isPrinting = true;
          unawaited(hub.addBreadcrumb(
            Breadcrumb.console(
              message: line,
              level: SentryLevel.debug,
            ),
          ));
          parent.print(zone, line);
        } finally {
          _isPrinting = false;
        }
      },
    );
    return runZonedGuarded(
      body,
      sentryOnError,
      zoneValues: zoneValues,
      zoneSpecification: sentryZoneSpecification,
    );
  }

  static Future<void> _captureError(
    Hub hub,
    SentryOptions options,
    Object exception,
    StackTrace stackTrace,
  ) async {
    debugLogger.error(
      'Uncaught zone error',
      category: 'run_zoned_guarded',
      error: exception,
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
}
