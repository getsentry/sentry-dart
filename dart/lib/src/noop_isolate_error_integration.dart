import 'hub.dart';
import 'sentry_options.dart';

// noop web integration : isolate doesnt' work in browser
void isolateErrorIntegration(Hub hub, SentryOptions options) {}
