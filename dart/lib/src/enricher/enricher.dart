import 'dart:async';

import '../sentry_options.dart';
import '../protocol.dart';
import '_io_enricher.dart' if (dart.library.html) '_web_enricher.dart';

EventProcessor enricherEventProcessor(SentryOptions options) {
  return (SentryEvent event, {dynamic hint}) async {
    return await options.enricher.apply(
      event,
      options.platformChecker.hasNativeIntegration,
      options.sendDefaultPii,
    );
  };
}

abstract class Enricher {
  factory Enricher() {
    return instance;
  }

  // Applies additional information to events.
  FutureOr<SentryEvent> apply(
    SentryEvent event,

    /// See [SentryOptions.platformChecker.hasNativeIntegration]
    bool hasNativeIntegration,

    /// See [SentryOptions.sendDefaultPii]
    bool includePii,
  );
}

/// An [Enricher] which just returns the given [SentryEvent]. No information
/// are applied.
class NoopEnricher implements Enricher {
  @override
  FutureOr<SentryEvent> apply(
    SentryEvent event,
    bool hasNativeIntegration,
    bool includePii,
  ) {
    return event;
  }
}
