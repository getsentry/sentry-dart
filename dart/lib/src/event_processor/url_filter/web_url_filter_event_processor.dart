// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web show window, Window;

import '../../../sentry.dart';
import '../../utils/regex_utils.dart';
import 'url_filter_event_processor.dart';

UrlFilterEventProcessor urlFilterEventProcessor(SentryOptions options) =>
    WebUrlFilterEventProcessor(options);

class WebUrlFilterEventProcessor implements UrlFilterEventProcessor {
  WebUrlFilterEventProcessor(
    this._options,
  );

  final web.Window _window = web.window;

  final SentryOptions _options;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final url = event.request?.url ?? _window.location.toString();

    if (_options.allowUrls.isNotEmpty &&
        !isMatchingRegexPattern(url, _options.allowUrls)) {
      return null;
    }

    if (_options.denyUrls.isNotEmpty &&
        isMatchingRegexPattern(url, _options.denyUrls)) {
      return null;
    }

    return event;
  }
}
