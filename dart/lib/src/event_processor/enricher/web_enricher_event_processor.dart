import 'dart:async';
import 'dart:html' as html show window, Window;

import '../../protocol.dart';
import '../../sentry_options.dart';
import 'enricher_event_processor.dart';

EnricherEventProcessor enricherEventProcessor(SentryOptions options) {
  return WebEnricherEventProcessor(
    html.window,
    options,
  );
}

class WebEnricherEventProcessor implements EnricherEventProcessor {
  WebEnricherEventProcessor(
    this._window,
    this._options,
  );

  final html.Window _window;

  final SentryOptions _options;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event, {dynamic hint}) {
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

    return (request ?? SentryRequest()).copyWith(
      url: request?.url ?? _window.location.toString(),
      headers: header,
    );
  }

  SentryDevice _getDevice(SentryDevice? device) {
    return (device ?? SentryDevice()).copyWith(
      online: device?.online ?? _window.navigator.onLine,
      memorySize: device?.memorySize ?? _getMemorySize(),
      orientation: device?.orientation ?? _getScreenOrientation(),
      screenHeightPixels: device?.screenHeightPixels ??
          _window.screen?.available.height.toInt(),
      screenWidthPixels:
          device?.screenWidthPixels ?? _window.screen?.available.width.toInt(),
      screenDensity:
          device?.screenDensity ?? _window.devicePixelRatio.toDouble(),
      // ignore: deprecated_member_use_from_same_package
      timezone: device?.timezone ?? DateTime.now().timeZoneName,
    );
  }

  int? _getMemorySize() {
    // https://developer.mozilla.org/en-US/docs/Web/API/Navigator/deviceMemory
    final size = _window.navigator.deviceMemory?.toDouble();
    final memoryByteSize = size != null ? size * 1024 * 1024 * 1024 : null;
    return memoryByteSize?.toInt();
  }

  SentryOrientation? _getScreenOrientation() {
    // https://developer.mozilla.org/en-US/docs/Web/API/ScreenOrientation
    final screenOrientation = _window.screen?.orientation;
    if (screenOrientation != null) {
      if (screenOrientation.type?.startsWith('portrait') ?? false) {
        return SentryOrientation.portrait;
      }
      if (screenOrientation.type?.startsWith('landscape') ?? false) {
        return SentryOrientation.landscape;
      }
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
