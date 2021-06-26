import 'dart:async';
import 'dart:html' as html show window, Window;

import '../event_processor.dart';
import '../sentry_options.dart';
import '../protocol.dart';

EventProcessor enricherEventProcessor(SentryOptions options) {
  return WebEnricherEventProcessor(
    html.window,
  );
}

class WebEnricherEventProcessor extends EventProcessor {
  WebEnricherEventProcessor(
    this._window,
  );

  final html.Window _window;

  @override
  FutureOr<SentryEvent> apply(SentryEvent event, {dynamic hint}) async {
    // Web has no native integration, so no need to check for it

    final contexts = event.contexts.copyWith(
      device: await _getDevice(event.contexts.device),
    );

    return event.copyWith(
      contexts: contexts,
      request: _getRequest(event.request),
    );
  }

  // As seen in
  // https://github.com/getsentry/sentry-javascript/blob/a6f8dc26a4c7ae2146ae64995a2018c8578896a6/packages/browser/src/integrations/useragent.ts
  SentryRequest _getRequest(SentryRequest? request) {
    final reqestHeader = request?.headers;
    final header = reqestHeader == null
        ? <String, String>{}
        : Map<String, String>.from(reqestHeader);

    header.putIfAbsent('User-Agent', () => _window.navigator.userAgent);

    return (request ?? SentryRequest()).copyWith(
      url: request?.url ?? _window.location.toString(),
      headers: header,
    );
  }

  Future<SentryDevice> _getDevice(SentryDevice? device) async {
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
}
