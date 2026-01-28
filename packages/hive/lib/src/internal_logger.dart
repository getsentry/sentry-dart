import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Internal logger for sentry_hive package.
@internal
const internalLogger = SentryInternalLogger('sentry_hive');
