import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../sentry_flutter.dart';

class WidgetEventProcessor implements EventProcessor {
  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, Hint hint) {
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

    // ignore: deprecated_member_use
    final textScale = MediaQuery.textScaleFactorOf(context);
    return event.copyWith(
      contexts: event.contexts.copyWith(
        app: event.contexts.app?.copyWith(
          textScale: textScale,
        ),
      ),
    );
  }
}
