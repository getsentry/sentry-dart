import 'package:flutter/rendering.dart';
import 'package:sentry/sentry.dart';

class FlutterExceptionEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, Hint hint) {
    if (event is SentryTransaction) {
      return event;
    }

    final exception = event.throwable;
    if (exception is NetworkImageLoadException) {
      return _applyNetworkImageLoadException(event, exception);
    }
    return event;
  }

  /// https://api.flutter.dev/flutter/painting/NetworkImageLoadException-class.html
  SentryEvent _applyNetworkImageLoadException(
    SentryEvent event,
    NetworkImageLoadException exception,
  ) {
    return event.copyWith(
      request: event.request ?? SentryRequest.fromUri(uri: exception.uri),
      contexts: event.contexts.copyWith(
        response: event.contexts.response ??
            SentryResponse(statusCode: exception.statusCode),
      ),
    );
  }
}
