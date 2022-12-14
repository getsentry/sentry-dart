import 'dart:async';

import '../../sentry_flutter.dart';
import 'view_hierarchy_event_processor.dart';

class SentryViewHierarchyIntegration extends Integration<SentryFlutterOptions> {
  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (!options.attachViewHierarchy) {
      return Future.value();
    }
    options.addEventProcessor(SentryViewHierarchyEventProcessor());
    options.sdk.addIntegration('viewHierarchyIntegration');
  }
}
