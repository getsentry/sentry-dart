import 'dart:async';

import 'hub.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// integration that capture errors on the runZonedGuarded error handler
Integration runZonedGuardedIntegration(
  AppRunner appRunner,
) {
  void integration(
    Hub hub,
    SentryOptions options, [
    AddIntegrationDisposer getPortDisposer,
  ]) {
    runZonedGuarded(() async {
      await appRunner();
    }, (exception, stackTrace) async {
      // runZonedGuarded doesn't crash the App.
      const mechanism = Mechanism(type: 'runZonedGuarded', handled: true);
      final throwableMechanism = ThrowableMechanism(mechanism, exception);

      final event = SentryEvent(
        throwable: throwableMechanism,
        level: SentryLevel.fatal,
      );

      await hub.captureEvent(event, stackTrace: stackTrace);
    });

    options.sdk.addIntegration('runZonedGuardedIntegration');
  }

  return integration;
}
