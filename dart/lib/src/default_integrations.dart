import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// Integration that runs runner function within runZonedGuarded
class RunZonedGuardedIntegration extends Integration {
  RunZonedGuardedIntegration();

  FutureOr<void> Function() runner;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    runZonedGuarded(() async {
      if (runner != null) {
        await runner();
      }
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

// integration calling _appRunner. Should always be the last integration run
class AppRunnerIntegration extends Integration {
  AppRunnerIntegration(this._appRunner);

  final AppRunner _appRunner;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    _appRunner();
    options.sdk.addIntegration('appRunnerIntegration');
  }
}
