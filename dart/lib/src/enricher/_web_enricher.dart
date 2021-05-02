import 'dart:async';

import 'enricher.dart';
import '../protocol/sentry_event.dart';

final Enricher instance = WebEnricher();

class WebEnricher implements Enricher {
  @override
  FutureOr<SentryEvent> apply(SentryEvent event) {
    return event;
  }
}
