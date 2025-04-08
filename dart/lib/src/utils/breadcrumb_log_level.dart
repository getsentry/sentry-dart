import 'package:meta/meta.dart';

import '../../sentry.dart';

/// Determine a breadcrumb's log level (only `warning` or `error`) based on an HTTP status code.
@internal
SentryLevel? getBreadcrumbLogLevelFromHttpStatusCode(int statusCode) {
  // NOTE: null defaults to 'info' in Sentry
  if (statusCode >= 400 && statusCode < 500) {
    return SentryLevel.warning;
  } else if (statusCode >= 500) {
    return SentryLevel.error;
  } else {
    return null;
  }
}