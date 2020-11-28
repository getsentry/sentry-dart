import 'package:flutter/material.dart';
import 'package:sentry/sentry.dart';

/// This key must be used so that the web interface displays the events nicely
/// See https://develop.sentry.dev/sdk/event-payloads/breadcrumbs/
const _navigationKey = 'navigation';

/// This class makes it easier to record breadcrumbs for navigation events by
/// accepting Flutters [RouteSettings](https://api.flutter.dev/flutter/widgets/RouteSettings-class.html).
///
/// See also:
///   - https://flutter.dev/docs/cookbook/navigation/navigate-with-arguments
class NavigationBreadcrumb extends Breadcrumb {
  factory NavigationBreadcrumb({
    /// This should correspond to Flutters navigation events.
    /// See https://api.flutter.dev/flutter/widgets/RouteObserver-class.html
    @required String navigationType,
    RouteSettings from,
    RouteSettings to,
    SentryLevel level = SentryLevel.info,
  }) {
    final dynamic fromArgs = _formatArgs(from?.arguments);
    final dynamic toArgs = _formatArgs(to?.arguments);
    return NavigationBreadcrumb._(
      from: from?.name,
      fromArgs: fromArgs,
      to: to?.name,
      toArgs: toArgs,
      navigationType: navigationType,
      level: level,
    );
  }

  NavigationBreadcrumb._({
    @required String navigationType,
    String from,
    dynamic fromArgs,
    String to,
    dynamic toArgs,
    SentryLevel level = SentryLevel.info,
  })  : assert(navigationType != null),
        super(
            category: _navigationKey,
            type: _navigationKey,
            level: level,
            data: <String, dynamic>{
              if (navigationType != null) 'state': navigationType,
              if (from != null) 'from': from,
              if (fromArgs != null) 'from_arguments': fromArgs,
              if (to != null) 'to': to,
              if (toArgs != null) 'to_arguments': toArgs,
            });

  static dynamic _formatArgs(Object args) {
    if (args == null) {
      return null;
    }
    if (args is Map<String, dynamic>) {
      return args.map<String, dynamic>((key, dynamic value) =>
          MapEntry<String, String>(key, value.toString()));
    }
    return args.toString();
  }
}
