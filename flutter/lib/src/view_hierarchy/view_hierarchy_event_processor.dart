import 'dart:async';

import '../../sentry_flutter.dart';
import '../binding_utils.dart';
import 'sentry_tree_walker.dart';

/// A [EventProcessor] that renders an ASCII represention of the entire view
/// hierarchy of the application when an error happens and includes it as an
/// attachment to the [Hint].
class SentryViewHierarchyEventProcessor implements EventProcessor {
  @override
  FutureOr<SentryEvent?> apply(SentryEvent event, {Hint? hint}) async {
    if (event.exceptions == null && event.throwable == null) {
      return event;
    }

    final instance = BindingUtils.getWidgetsBindingInstance();
    if (instance == null) {
      return event;
    }
    final sentryViewHierarchy = walkWidgetTree(instance);

    if (sentryViewHierarchy == null) {
      return event;
    }

    final viewHierarchy =
        SentryAttachment.fromViewHierarchy(sentryViewHierarchy);
    hint?.viewHierarchy = viewHierarchy;
    return event;
  }
}
