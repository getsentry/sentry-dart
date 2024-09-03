// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web show window, Window;

import '../../../sentry_flutter.dart';
import 'url_filter_event_processor.dart';
// ignore: implementation_imports
import 'package:sentry/src/utils/regex_utils.dart';

// ignore_for_file: invalid_use_of_internal_member

UrlFilterEventProcessor urlFilterEventProcessor(SentryFlutterOptions options) =>
    WebUrlFilterEventProcessor(options);

class WebUrlFilterEventProcessor implements UrlFilterEventProcessor {
  WebUrlFilterEventProcessor(
    this._options,
  );

  final SentryFlutterOptions _options;

  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    final frames = _getStacktraceFrames(event);
    final lastPath = frames?.first?.absPath;

    if (lastPath == null) {
      return event;
    }

    if (_options.allowUrls.isNotEmpty &&
        !isMatchingRegexPattern(lastPath, _options.allowUrls)) {
      return null;
    }

    if (_options.denyUrls.isNotEmpty &&
        isMatchingRegexPattern(lastPath, _options.denyUrls)) {
      return null;
    }

    return event;
  }

  Iterable<SentryStackFrame?>? _getStacktraceFrames(SentryEvent event) {
    if (event.exceptions?.isNotEmpty == true) {
      return event.exceptions?.first.stackTrace?.frames;
    }
    if (event.threads?.isNotEmpty == true) {
      final stacktraces = event.threads?.map((e) => e.stacktrace);
      return stacktraces
          ?.where((element) => element != null)
          .expand((element) => element!.frames);
    }
    return null;
  }
}
