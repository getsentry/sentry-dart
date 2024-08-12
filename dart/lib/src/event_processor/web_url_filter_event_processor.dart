// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web show window, Window;

import '../../sentry.dart';
import '../utils/regex_utils.dart';

class WebUrlFilterEventProcessor implements EventProcessor {
  WebUrlFilterEventProcessor(
    this._options,
  );

  final web.Window _window = web.window;

  final SentryOptions _options;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    if (!_options.platformChecker.isWeb) {
      return event;
    }
    final url = event.request?.url ?? _window.location.toString();

    if (isMatchingRegexPattern(url, _options.allowUrls)) {
      if (_options.denyUrls.isNotEmpty &&
          isMatchingRegexPattern(url, _options.denyUrls)) {
        return null;
      } else {
        return event;
      }
    } else {
      return null;
    }
  }
}
