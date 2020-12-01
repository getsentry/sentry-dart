import 'hub.dart';
import 'sentry_options.dart';

// noop web integration : isolate doesnt' work in browser
void isolateErrorIntegration(
  Hub hub,
  SentryOptions options, [
  AddIntegrationDisposer addDisposer,
]) {}

Future<void> handleIsolateError(
  Hub hub,
  SentryOptions options,
  dynamic error,
) async {}
