// We would lose compatibility with old dart versions by adding web to pubspec.
// ignore: depend_on_referenced_packages
import 'package:web/web.dart' as web show window, Window, Navigator;

import '../../../sentry.dart';
import 'enricher_event_processor.dart';

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
  SentryEvent? apply(SentryEvent event, Hint hint) {
    // Web has no native integration, so no need to check for it

    final contexts = event.contexts.copyWith(
      device: _getDevice(event.contexts.device),
      culture: _getSentryCulture(event.contexts.culture),
    );

    contexts['dart_context'] = _getDartContext();

    return event.copyWith(
      contexts: contexts,
      request: _getRequest(event.request),
      transaction: event.transaction ?? _window.location.pathname,
    );
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
    return (request ?? SentryRequest(url: url))
        .copyWith(headers: header)
        .sanitized();
  }

  SentryDevice _getDevice(SentryDevice? device) {
    return (device ?? SentryDevice()).copyWith(
      online: device?.online ?? _window.navigator.onLine,
      memorySize: device?.memorySize ?? _getMemorySize(),
      orientation: device?.orientation ?? _getScreenOrientation(),
      screenHeightPixels:
          device?.screenHeightPixels ?? _window.screen.availHeight,
      screenWidthPixels: device?.screenWidthPixels ?? _window.screen.availWidth,
      screenDensity:
          device?.screenDensity ?? _window.devicePixelRatio.toDouble(),
    );
  }

  int? _getMemorySize() {
    // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory
    // ignore: invalid_null_aware_operator
    final size = _window.navigator.deviceMemory?.toDouble();
    final memoryByteSize = size != null ? size * 1024 * 1024 * 1024 : null;
    return memoryByteSize?.toInt();
  }

  SentryOrientation? _getScreenOrientation() {
    // https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation
    final screenOrientation = _window.screen.orientation;
    if (screenOrientation.type.startsWith('portrait')) {
      return SentryOrientation.portrait;
    }
    if (screenOrientation.type.startsWith('landscape')) {
      return SentryOrientation.landscape;
    }
    return null;
  }

  Map<String, dynamic> _getDartContext() {
    return <String, dynamic>{
      'compile_mode': _options.platformChecker.compileMode,
    };
  }

  SentryCulture _getSentryCulture(SentryCulture? culture) {
    return (culture ?? SentryCulture()).copyWith(
      timezone: culture?.timezone ?? DateTime.now().timeZoneName,
    );
  }
}

extension on web.Navigator {
  // ignore: unused_element
  external double? get deviceMemory;
}
