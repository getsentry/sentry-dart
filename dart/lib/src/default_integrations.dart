import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// integration that runs runner function within runZonedGuarded and capture
/// errors on the runZonedGuarded error handler
class RunZonedGuardedIntegration extends Integration {
  RunZonedGuardedIntegration(this._runner);

  final Future<void> Function() _runner;

  /// Needed to check if we somehow caused a `print()` recursion
  bool _isPrinting = false;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    runZonedGuarded(
      () async {
        await _runner();
      },
      (exception, stackTrace) async {
        // runZonedGuarded doesn't crash the App.
        final mechanism = Mechanism(type: 'runZonedGuarded', handled: true);
        final throwableMechanism = ThrowableMechanism(mechanism, exception);

        final event = SentryEvent(
          throwable: throwableMechanism,
          level: SentryLevel.fatal,
        );

        await hub.captureEvent(event, stackTrace: stackTrace);
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (!hub.isEnabled || !options.enablePrintBreadcrumbs) {
            // early bail out, in order to better guard against the recursion
            // as described below.
            parent.print(zone, line);
            return;
          }

          if (_isPrinting) {
            // We somehow landed in a recursion.
            // This happens for example if:
            // hub.addBreadcrumb() called print() itself.
            // This happens for example if hub.isEnabled == false and
            // options.logger == dartLogger
            //
            // Anyway, in order to not cause a stack overflow due to recursion
            // we drop any print() call while adding a breadcrumb.
            return;
          }
          _isPrinting = true;
          try {
            hub.addBreadcrumb(Breadcrumb(
              message: line,
            ));
            parent.print(zone, line);
          } finally {
            _isPrinting = false;
          }
        },
      ),
    );

    options.sdk.addIntegration('runZonedGuardedIntegration');
  }
}
