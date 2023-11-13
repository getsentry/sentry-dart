import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

GlobalKey<NavigatorState> sentryNavigatorKey = GlobalKey<NavigatorState>();

@internal
Locale? retrieveWidgetLocale() {
  final BuildContext? context = sentryNavigatorKey.currentContext;
  if (context != null) {
    return Localizations.localeOf(context);
  }
  return null;
}
