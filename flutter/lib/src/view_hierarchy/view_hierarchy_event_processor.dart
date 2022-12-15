import 'dart:async';

import '../../sentry_flutter.dart';
import '../binding_utils.dart';
import 'sentry_tree_walker.dart';

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
        SentryAttachment.fromViewHierrchy(sentryViewHierarchy);
    hint?.viewHierarchy = viewHierarchy;
    return event;
  }
}
