import 'dart:async';
import 'package:web/web.dart' as web show window, Window, Navigator;

import '../../../sentry.dart';
import 'enricher_event_processor.dart';
import 'flutter_runtime.dart';
import '../../utils/web_get_sentry_device.dart';

EnricherEventProcessor enricherEventProcessor(SentryOptions options) {
  return WebEnricherEventProcessor(
    web.window,
    options,
  );
}

class WebEnricherEventProcessor implements EnricherEventProcessor {
  WebEnricherEventProcessor(
    this._window,
    this._options,
  );

  final web.Window _window;

  final SentryOptions _options;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    // Web has no native integration, so no need to check for it
    event.contexts
      ..device = getSentryDevice(event.contexts.device, _options)
      ..culture = _getSentryCulture(event.contexts.culture)
      ..runtimes = _getRuntimes(event.contexts.runtimes);

    event.contexts['dart_context'] = _getDartContext();

    return event
      ..request = _getRequest(event.request)
      ..transaction = event.transaction ?? _window.location.pathname;
  }

  // As seen in
  // https://github.com/getsentry/sentry-javascript/blob/a6f8dc26a4c7ae2146ae64995a2018c8578896a6/packages/browser/src/integrations/useragent.ts
  SentryRequest _getRequest(SentryRequest? request) {
    final requestHeader = request?.headers;
    final header = requestHeader == null
        ? <String, String>{}
        : Map<String, String>.from(requestHeader);

    header.putIfAbsent('User-Agent', () => _window.navigator.userAgent);

    final url = request?.url ?? _window.location.toString();
    request ??= SentryRequest(url: url);
    return request
      ..headers = header
      ..sanitize();
  }

  Map<String, dynamic> _getDartContext() {
    return <String, dynamic>{
      'compile_mode': _options.runtimeChecker.compileMode,
    };
  }

  SentryCulture _getSentryCulture(SentryCulture? culture) {
    culture ??= SentryCulture();
    return culture..timezone = culture.timezone ?? DateTime.now().timeZoneName;
  }

  List<SentryRuntime> _getRuntimes(List<SentryRuntime>? runtimes) {
    final flRuntime = flutterRuntime;
    final dartFlRuntime = dartFlutterRuntime;

    if (runtimes == null) {
      return [
        if (flRuntime != null) flRuntime,
        if (dartFlRuntime != null) dartFlRuntime,
      ];
    }
    return [
      ...runtimes,
      if (flRuntime != null) flRuntime,
      if (dartFlRuntime != null) dartFlRuntime,
    ];
  }
}

extension on web.Navigator {
  // ignore: unused_element
  external double? get deviceMemory;
}
