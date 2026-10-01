import 'dart:async';

import 'package:meta/meta.dart';

import '../../sentry.dart';
import '../exception/unhandled_error_span_status.dart';
import '../utils/internal_logger.dart';

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
    // Must remain synchronous. `runZonedGuarded` expects a
    // `void Function(Object, StackTrace)` and never awaits the returned
    // future. Declaring this `async` made the user-supplied [onError] run
    // inside an unawaited future of this same zone, which meant a rethrow
    // (a common pattern to preserve normal crash behaviour) became an
    // async uncaught error in the same zone and recursively re-entered
    // `sentryOnError`. Dart breaks that loop by silently dropping the
    // error, so the unhandled exception ended up swallowed entirely.
    // See https://github.com/getsentry/sentry-dart/issues/3541.
    final sentryOnError = (Object exception, StackTrace stackTrace) {
      final options = hub.options;
      // Fire-and-forget so the synchronous contract is preserved. The
      // event is buffered/queued internally by the hub regardless.
      unawaited(_captureError(hub, options, exception, stackTrace));

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
          unawaited(
            hub.addBreadcrumb(
              Breadcrumb.console(message: line, level: SentryLevel.debug),
            ),
          );
          parent.print(zone, line);
        } finally {
          _isPrinting = false;
        }
      },
    );
    return runZonedGuarded(
      () => runZoned(() {
        try {
          return body();
        } catch (_) {
          _markActiveSpanAsErrored(hub, Zone.current);
          rethrow;
        }
      }, zoneSpecification: _originZoneSpanStatusSpecification(hub)),
      sentryOnError,
      zoneValues: zoneValues,
      zoneSpecification: sentryZoneSpecification,
    );
  }

  /// `runZonedGuarded` invokes `onError` in its parent zone, where spans
  /// started inside `body` are not visible, and it replaces any
  /// `handleUncaughtError` passed alongside it. A zone nested inside it still
  /// receives the zone an async error originated in, so the span is marked
  /// from there before the error continues to `onError`.
  static ZoneSpecification _originZoneSpanStatusSpecification(Hub hub) {
    return ZoneSpecification(
      handleUncaughtError: (self, parent, zone, error, stackTrace) {
        _markActiveSpanAsErrored(hub, zone);
        parent.handleUncaughtError(zone, error, stackTrace);
      },
    );
  }

  static void _markActiveSpanAsErrored(Hub hub, Zone zone) {
    try {
      zone.run(hub.markActiveSpanAsErrored);
    } catch (e, st) {
      internalLogger.error(
        'Failed to mark the active span as errored',
        error: e,
        stackTrace: st,
      );
    }
  }

  static Future<void> _captureError(
    Hub hub,
    SentryOptions options,
    Object exception,
    StackTrace stackTrace,
  ) async {
    internalLogger.error(
      'Uncaught zone error',
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

    await hub.captureEvent(event, stackTrace: stackTrace);
  }
}
