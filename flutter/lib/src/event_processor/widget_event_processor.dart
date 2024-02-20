import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../sentry_flutter.dart';

class WidgetEventProcessor implements EventProcessor {
  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {Hint? hint}) {
    if (event is SentryTransaction) {
      return event;
    }
    if (event.exceptions == null && event.throwable == null) {
      return event;
    }
    final context = sentryWidgetGlobalKey.currentContext;
    if (context == null) {
      return event;
    }
    final textScaleFactor =
        MediaQuery.maybeTextScalerOf(context)?.textScaleFactor;
    if (textScaleFactor == null) {
      return event;
    }
    final textScale =
        textScaleFactor == 1.0 ? 'no scaling' : 'linear (${textScaleFactor}x)';
    return event.copyWith(
      contexts: event.contexts.copyWith(
        app: event.contexts.app?.copyWith(
          textScale: textScale,
        ),
      ),
    );
  }
}
