import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Internal logger for sentry_drift package.
@internal
const internalLogger = SentryInternalLogger('sentry_drift');
