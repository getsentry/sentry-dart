import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:sentry/sentry.dart';

class FlutterExceptionEventProcessor implements EventProcessor {
  @override
  SentryEvent? apply(SentryEvent event, {dynamic hint}) {
    final exception = event.throwable;
    if (exception is NetworkImageLoadException) {
      return _applyNetworkImageLoadException(event, exception);
    }
    if (exception is PictureRasterizationException) {
      return _applyPictureRasterizationException(event, exception);
    }
    return event;
  }

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

  SentryEvent _applyPictureRasterizationException(
    SentryEvent event,
    PictureRasterizationException exception,
  ) {
    return event;
  }
}
