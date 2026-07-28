// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../sentry_flutter.dart';

/// Display name for the initial route, used when the app has not navigated
/// anywhere the observer can name yet.
@internal
const rootRouteName = 'root /';

/// Normalizes an observed route name into a display name, falling back to
/// [rootRouteName] when the route is unknown or the framework root.
@internal
String resolveRouteDisplayName(String? routeName) =>
    routeName == null || routeName.isEmpty || routeName == '/'
        ? rootRouteName
        : routeName;

/// Context for the initial `ui.load` root transaction (static lifecycle).
@internal
SentryTransactionContext initialDisplayTransactionContext() =>
    SentryTransactionContext(
      rootRouteName,
      SentrySpanOperations.uiLoad,
      transactionNameSource: SentryTransactionNameSource.component,
      origin: SentryTraceOrigins.autoUiTimeToDisplay,
    );
