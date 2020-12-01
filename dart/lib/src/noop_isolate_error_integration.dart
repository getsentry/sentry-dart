import 'dart:async';

import 'default_integrations.dart';
import 'hub.dart';
import 'sentry_options.dart';

// noop web integration : isolate doesnt' work in browser
class IsolateErrorIntegration extends Integration {
  @override
  FutureOr<void> run(Hub hub, SentryOptions options) async {}
}

Future<void> handleIsolateError(
  Hub hub,
  SentryOptions options,
  dynamic error,
) async {}
