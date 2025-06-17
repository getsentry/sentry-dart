import 'dart:async';

import '../contexts_enricher.dart';
import '../protocol/contexts.dart';
import '../utils/os_utils.dart';

class OsContextsEnricher implements ContextsEnricher {
  @override
  FutureOr<void> enrich(Contexts contexts) {
    final os = getSentryOperatingSystem();
    contexts.operatingSystem?.name = os.name ?? contexts.operatingSystem?.name;
    contexts.operatingSystem?.version =
        os.version ?? contexts.operatingSystem?.version;
  }
}
