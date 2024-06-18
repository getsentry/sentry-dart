import 'package:sentry/sentry.dart';

import 'noop_window.dart'
  if (dart.library.js_interop) 'web_window.dart';

class SentryWeb {
  static Window createWindow() {
    return createWebWindow();
  }
}
