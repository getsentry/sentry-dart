import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// integration that capture errors on the runZonedGuarded error handler
class RunZonedGuardedIntegration extends Integration {
  final AppRunner _appRunner;

  RunZonedGuardedIntegration(this._appRunner);

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    runZonedGuarded(() async {
      await _appRunner();
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
