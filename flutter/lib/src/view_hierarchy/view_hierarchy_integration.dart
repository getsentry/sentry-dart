import 'dart:async';

import '../../sentry_flutter.dart';
import 'view_hierarchy_event_processor.dart';

class SentryViewHierarchyIntegration extends Integration<SentryFlutterOptions> {
  SentryViewHierarchyEventProcessor? _eventProcessor;
  SentryFlutterOptions? _options;

  @override
  FutureOr<void> call(Hub hub, SentryFlutterOptions options) {
    if (!options.attachViewHierarchy) {
      return Future.value();
    }
    _options = options;
    final eventProcessor = SentryViewHierarchyEventProcessor();
    options.addEventProcessor(eventProcessor);
    _eventProcessor = eventProcessor;
    options.sdk.addIntegration('viewHierarchyIntegration');
  }

  @override
  FutureOr<void> close() {
    final eventProcessor = _eventProcessor;
    if (eventProcessor != null) {
      _options?.removeEventProcessor(eventProcessor);
      _eventProcessor = null;
    }
  }
}
