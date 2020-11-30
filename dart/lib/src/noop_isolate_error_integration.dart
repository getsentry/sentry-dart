import 'hub.dart';
import 'sentry_options.dart';

void addIsolateErrorIntegration(SentryOptions options) {}

// noop web integration : isolate doesnt' work in browser
void isolateErrorIntegration(Hub hub, SentryOptions options) {}

Integration initIsolateErrorIntegration(
  void Function(Function) receivePortWatcher,
) =>
    null;
