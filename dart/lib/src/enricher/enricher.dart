import 'dart:async';

import '../protocol.dart';
import '_io_enricher.dart' if (dart.library.html) '_web_enricher.dart';

abstract class Enricher {
  factory Enricher() {
    return instance;
  }

  FutureOr<SentryEvent> apply(SentryEvent event, bool hasNativeIntegration);
}
