import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Logger for the Sentry Drift integration.
@internal
const internalLogger = SentryInternalLogger('sentry_drift');
