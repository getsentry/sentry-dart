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

  final FutureOr<void> Function() _runner;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    runZonedGuarded(() async {
      await _runner();
    }, (exception, stackTrace) async {
      // runZonedGuarded doesn't crash the App.
      final mechanism = Mechanism(type: 'runZonedGuarded', handled: true);
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      final event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
      );

      await hub.captureEvent(event, stackTrace: stackTrace);
    });

    options.sdk.addIntegration('runZonedGuardedIntegration');
  }
}
