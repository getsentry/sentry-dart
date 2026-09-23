import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

/// Logger for the Sentry Flutter SDK.
@internal
const internalLogger = SentryInternalLogger('sentry_flutter');
