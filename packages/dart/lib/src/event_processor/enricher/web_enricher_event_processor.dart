import 'package:web/web.dart' as web show window, Window;

import '../../../sentry.dart';
import '../../platform/platform_context_provider.dart';
import 'enricher_event_processor.dart';

EnricherEventProcessor enricherEventProcessor(
  SentryOptions options,
  PlatformContextProvider provider,
) {
  return WebEnricherEventProcessor(web.window, options, provider);
}

class WebEnricherEventProcessor implements EnricherEventProcessor {
  WebEnricherEventProcessor(this._window, this._options, this._provider);

  final web.Window _window;
  final SentryOptions _options;
  final PlatformContextProvider _provider;

  @override
  Future<SentryEvent?> apply(SentryEvent event, Hint hint) async {
    final platform = await _provider.buildContexts();

    event.contexts
      ..device = _mergeDevice(event.contexts.device, platform.device)
      ..culture = _mergeCulture(event.contexts.culture, platform.culture)
      ..runtimes = _mergeRuntimes(event.contexts.runtimes, platform.runtimes);

    event.contexts['dart_context'] = _getDartContext();

    return event
      ..request = _getRequest(event.request)
      ..transaction = event.transaction ?? _window.location.pathname;
  }

  SentryDevice _mergeDevice(SentryDevice? existing, SentryDevice? detected) {
    existing ??= SentryDevice();
    return existing
      ..online = existing.online ?? detected?.online
      ..memorySize = existing.memorySize ?? detected?.memorySize
      ..orientation = existing.orientation ?? detected?.orientation
      ..screenHeightPixels =
          existing.screenHeightPixels ?? detected?.screenHeightPixels
      ..screenWidthPixels =
          existing.screenWidthPixels ?? detected?.screenWidthPixels
      ..screenDensity = existing.screenDensity ?? detected?.screenDensity;
  }

  SentryCulture _mergeCulture(
      SentryCulture? existing, SentryCulture? detected) {
    existing ??= SentryCulture();
    return existing..timezone = existing.timezone ?? detected?.timezone;
  }

  List<SentryRuntime> _mergeRuntimes(
      List<SentryRuntime> existing, List<SentryRuntime> detected) {
    return [...existing, ...detected];
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
}
