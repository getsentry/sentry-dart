import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

import '../binding_utils.dart';
import '../sentry_flutter_options.dart';

typedef WithNavigatorContext = void Function(BuildContext context);

/// Only works if there's a [Navigator] in the widget tree
void tryShowUserFeedback(SentryId id, UserFeedbackBuilder builder) {
  runWithNavigatorContext((context) {
    showDialog(
      // TODO: Ignore in SentryNavigatorObserver?
      routeSettings: RouteSettings(name: 'SentryUserFeedbackDialog'),
      context: context,
      builder: (context) {
        return builder(context, id);
      },
    );
  });
}

/// Calls [withNavigatorContext] if [WidgetsBinding.renderViewElement] has
/// a [Navigator] as a child.
///
/// This method enables the testability of [tryShowUserFeedback].
@visibleForTesting
void runWithNavigatorContext(WithNavigatorContext withNavigatorContext) {
  NavigatorState? navigator;

  void navigationFinder(Element element) {
    if (navigator != null) {
      return;
    }
    final context = element;
    if (context is StatefulElement && context.state is NavigatorState) {
      navigator = context.state as NavigatorState;
      return;
    }
    element.visitChildElements(navigationFinder);
  }

  BindingUtils.getWidgetsBindingInstance()
      ?.renderViewElement
      ?.visitChildElements(navigationFinder);

  if (navigator != null) {
    withNavigatorContext(navigator!.context);
  }
}
