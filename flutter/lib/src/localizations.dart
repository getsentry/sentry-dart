import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';

@internal
Locale? retrieveWidgetLocale(GlobalKey<NavigatorState>? navigatorKey) {
  final BuildContext? context = navigatorKey?.currentContext;
  if (context != null) {
    return Localizations.maybeLocaleOf(context);
  }
  return null;
}
