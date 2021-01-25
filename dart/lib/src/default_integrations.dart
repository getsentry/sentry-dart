import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'protocol.dart';
import 'sentry.dart';
import 'sentry_options.dart';
import 'throwable_mechanism.dart';

/// integration that runs other integrations within runZonedGuarded to catch any
/// errors in Dart code running ‘outside’ the Flutter framework
class RunZonedGuardedIntegration extends Integration {
  RunZonedGuardedIntegration(this._integrations);

  final List <Integration>_integrations;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    await runZonedGuarded(() {
      for (final integration in _integrations) {
         integration(hub, options);
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

/// integration that runs other integrations
class NoZonedGuardedIntegration extends Integration {
  NoZonedGuardedIntegration(this._integrations);

  final List <Integration>_integrations;

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {
    for (final integration in _integrations) {
      await integration(hub, options);
    }
    options.sdk.addIntegration('noZonedGuardedIntegration');
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
