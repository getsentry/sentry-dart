import 'dart:async';

import '../protocol.dart';
import '_io_enricher.dart' if (dart.library.html) '_web_enricher.dart';

abstract class Enricher {
  factory Enricher() {
    return instance;
  }

  // Applies additional information to events.
  FutureOr<SentryEvent> apply(SentryEvent event, bool hasNativeIntegration);
}

/// An [Enricher] which just returns the given [SentryEvent]. No information
/// are applied.
class NoopEnricher implements Enricher {
  @override
  FutureOr<SentryEvent> apply(SentryEvent event, bool hasNativeIntegration) {
    return event;
  }
}
