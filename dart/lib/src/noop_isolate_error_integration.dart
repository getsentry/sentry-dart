import 'hub.dart';
import 'sentry_options.dart';

// noop web integration : isolate doesnt' work in browser
Integration isolateErrorIntegration(
  void Function(Function) receivePortWatcher,
) =>
    (Hub hub, SentryOptions options) {};

Future<void> handleIsolateError(
  Hub hub,
  SentryOptions options,
  dynamic error,
) async {}
