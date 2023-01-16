import 'dart:async';

import 'hub.dart';
import 'integration.dart';
import 'sentry_options.dart';

/// NoOp web integration : isolate doesnt' work in browser
class IsolateErrorIntegration extends Integration {
  @override
  FutureOr<void> call(Hub hub, SentryOptions options) async {}

  Future<void> handleIsolateError(
    Hub hub,
    SentryOptions options,
    dynamic error,
  ) async {}
}
