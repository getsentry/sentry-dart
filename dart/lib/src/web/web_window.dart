import '../sentry_options.dart';
import 'noop_window.dart';
import 'window.dart';

// Get window from options or noop
Window createWindow(SentryOptions options) {
  return options.window() ?? NoopWindow();
}
