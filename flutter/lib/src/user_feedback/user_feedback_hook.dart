import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

import 'user_feedback_dialog.dart';

void tryShowUserFeedback(SentryId id) {
  NavigatorState? navigator;

  void navigationFinder(Element element) {
    final context = element;
    if (context is StatefulElement && context.state is NavigatorState) {
      navigator = context.state as NavigatorState;
    }
    element.visitChildElements(navigationFinder);
  }

  WidgetsBinding.instance.renderViewElement
      ?.visitChildElements(navigationFinder);

  navigator?.push(
    DialogRoute<void>(
      context: navigator!.context,
      builder: (context) {
        return UserFeedbackDialog(eventId: id);
      },
    ),
  );
}
