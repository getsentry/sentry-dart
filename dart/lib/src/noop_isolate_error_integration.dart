import 'hub.dart';
import 'integration.dart';
import 'sentry_options.dart';

/// NoOp web integration : isolate doesnt' work in browser
class IsolateErrorIntegration extends Integration<SentryOptions> {
  @override
  void call(Hub hub, SentryOptions options) {}

  void handleIsolateError(
    Hub hub,
    SentryOptions options,
    dynamic error,
  ) {}
}
