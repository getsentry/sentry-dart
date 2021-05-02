import 'dart:async';

import '../protocol.dart';
import '_io_enricher.dart' if (dart.library.html) '_web_enricher.dart';

abstract class Enricher {
  static final Enricher defaultEnricher = instance;

  FutureOr<void> apply(SentryEvent event);
}
